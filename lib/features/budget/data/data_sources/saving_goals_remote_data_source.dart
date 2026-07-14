import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../models/goal_monthly_progress.dart';
import '../models/saving_goal_model.dart';

class GoalDepositsPage {
  const GoalDepositsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
  final List<TransactionModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}

abstract class SavingGoalsRemoteDataSource {
  Future<SavingGoalModel> deposit({
    required int goalId,
    required double amount,
    String? note,
    String? transactionDate,
  });

  Future<GoalDepositsPage> fetchDeposits({
    required int goalId,
    int page = 1,
    int perPage = 20,
    int? year,
    int? month,
  });

  Future<GoalMonthlyProgress> fetchMonthlyProgress({required int goalId});

  Future<SavingGoalModel> update({
    required int goalId,
    String? title,
    String? description,
    double? targetAmount,
    String? deadline,
    String? startDate,
    String? icon,
    String? color,
    String? currency,
    String? status,
  });

  Future<void> delete({required int goalId});
}

/// كاتيجوري افتراضية للادخار — يستخدمها التطبيق عند إنشاء سجل
/// `transaction(type=saving)` بدون فئة مرتبطة بميزانية.
/// عدّلها لتطابق `id` فئة "ادخار" الموجودة في جدول categories لديك،
/// أو اتركها 0 إذا كانت `category_id` تقبل NULL.
const int kSavingCategoryId = 0;

class SavingGoalsRemoteDataSourceImpl implements SavingGoalsRemoteDataSource {
  SavingGoalsRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<SavingGoalModel> deposit({
    required int goalId,
    required double amount,
    String? note,
    String? transactionDate,
  }) async {
    try {
      final date = (transactionDate != null && transactionDate.isNotEmpty)
          ? transactionDate
          : _ymd(DateTime.now());

      // 1) سجل عملية ادخار في transactions
      final txBody = <String, dynamic>{
        'user_id': _userId,
        'amount': amount,
        'currency': await _goalCurrency(goalId),
        'type': 'saving',
        'description': note ?? '',
        'merchant': '',
        'source': 'manual',
        'reference': '',
        'transaction_date': date,
        'saving_goal_id': goalId,
      };
      if (kSavingCategoryId > 0) txBody['category_id'] = kSavingCategoryId;

      await _supabase.from('transactions').insert(txBody);

      // 2) زيادة current_amount على الهدف
      final goalRow = await _supabase
          .from('saving_goals')
          .select()
          .eq('id', goalId)
          .single();

      final newCurrent = _toDouble(goalRow['current_amount']) + amount;
      final updated = await _supabase
          .from('saving_goals')
          .update({'current_amount': newCurrent})
          .eq('id', goalId)
          .select()
          .single();

      return _withPace(Map<String, dynamic>.from(updated));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<GoalDepositsPage> fetchDeposits({
    required int goalId,
    int page = 1,
    int perPage = 20,
    int? year,
    int? month,
  }) async {
    try {
      final from0 = (page - 1) * perPage;
      final to0 = from0 + perPage - 1;

      dynamic query = _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', _userId)
          .eq('type', 'saving')
          .eq('saving_goal_id', goalId);

      if (year != null && month != null) {
        final first = DateTime(year, month, 1);
        final last = DateTime(year, month + 1, 0);
        query = query
            .gte('transaction_date', _ymd(first))
            .lte('transaction_date', _ymd(last)) as dynamic;
      }

      query = query
          .order('transaction_date', ascending: false)
          .range(from0, to0) as dynamic;

      final res = await query.count(CountOption.exact);
      final rows = (res.data as List).cast<Map<String, dynamic>>();
      final total = res.count ?? rows.length;
      final lastPage = (total / perPage).ceil().clamp(1, 999999);

      final items = rows.map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m.containsKey('categories')) {
          m['category'] = m.remove('categories');
        }
        return TransactionModel.fromJson(m);
      }).toList();

      return GoalDepositsPage(
        items: items,
        currentPage: page,
        lastPage: lastPage,
        total: total,
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<GoalMonthlyProgress> fetchMonthlyProgress({required int goalId}) async {
    try {
      final goalRow = await _supabase
          .from('saving_goals')
          .select()
          .eq('id', goalId)
          .single();

      final target = _toDouble(goalRow['target_amount']);
      final currency = (goalRow['currency'] ?? 'SAR').toString();
      final startStr = (goalRow['start_date'] ?? '').toString();
      final deadlineStr = (goalRow['deadline'] ?? '').toString();

      final start = DateTime.tryParse(startStr) ?? DateTime.now();
      final deadline = DateTime.tryParse(deadlineStr) ?? start;
      final totalMonths = _monthsBetween(start, deadline).clamp(1, 1000);
      final monthlyTarget = target / totalMonths;

      // كل عمليات الادخار لهذا الهدف
      final txs = await _supabase
          .from('transactions')
          .select('amount, transaction_date')
          .eq('user_id', _userId)
          .eq('type', 'saving')
          .eq('saving_goal_id', goalId) as List;

      final byMonth = <String, double>{};
      final countByMonth = <String, int>{};
      for (final t in txs) {
        final d = DateTime.tryParse((t['transaction_date'] ?? '').toString());
        if (d == null) continue;
        final key = '${d.year}-${d.month}';
        byMonth[key] = (byMonth[key] ?? 0) + _toDouble(t['amount']);
        countByMonth[key] = (countByMonth[key] ?? 0) + 1;
      }

      final now = DateTime.now();
      final end = deadline.isBefore(now) ? deadline : now;

      final items = <Map<String, dynamic>>[];
      var cursor = DateTime(start.year, start.month, 1);
      while (!cursor.isAfter(DateTime(end.year, end.month, 1))) {
        final key = '${cursor.year}-${cursor.month}';
        final deposited = byMonth[key] ?? 0;
        final delta = deposited - monthlyTarget;
        items.add({
          'year': cursor.year,
          'month': cursor.month,
          'deposited': deposited,
          'transaction_count': countByMonth[key] ?? 0,
          'expected': monthlyTarget,
          'delta': delta,
          'on_track': delta >= -0.01,
        });
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
      }

      return GoalMonthlyProgress.fromJson({
        'items': items,
        'meta': {
          'monthly_target': monthlyTarget,
          'goal_id': goalId,
          'currency': currency,
        },
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<SavingGoalModel> update({
    required int goalId,
    String? title,
    String? description,
    double? targetAmount,
    String? deadline,
    String? startDate,
    String? icon,
    String? color,
    String? currency,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null && title.isNotEmpty) body['title'] = title;
      if (description != null) body['description'] = description;
      if (targetAmount != null) body['target_amount'] = targetAmount;
      if (deadline != null && deadline.isNotEmpty) body['deadline'] = deadline;
      if (startDate != null && startDate.isNotEmpty) body['start_date'] = startDate;
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;
      if (currency != null && currency.isNotEmpty) body['currency'] = currency;
      if (status != null && status.isNotEmpty) body['status'] = status;

      final row = await _supabase
          .from('saving_goals')
          .update(body)
          .eq('id', goalId)
          .select()
          .single();

      return _withPace(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> delete({required int goalId}) async {
    try {
      // حذف الـ transactions المرتبطة (cascade يدوي)
      await _supabase
          .from('transactions')
          .delete()
          .eq('saving_goal_id', goalId)
          .eq('type', 'saving');
      await _supabase.from('saving_goals').delete().eq('id', goalId);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  Future<String> _goalCurrency(int goalId) async {
    final row = await _supabase
        .from('saving_goals')
        .select('currency')
        .eq('id', goalId)
        .single();
    return (row['currency'] ?? 'SAR').toString();
  }

  Future<SavingGoalModel> _withPace(Map<String, dynamic> row) async {
    final status = (row['status'] ?? 'active').toString();
    final target = _toDouble(row['target_amount']);
    final current = _toDouble(row['current_amount']);
    final startStr = (row['start_date'] ?? '').toString();
    final deadlineStr = (row['deadline'] ?? '').toString();

    Map<String, dynamic> pace;
    if (status != 'active') {
      pace = {'status': 'inactive', 'monthly_target': 0, 'expected_at_today': 0, 'delta': 0};
    } else {
      final start = DateTime.tryParse(startStr);
      final deadline = DateTime.tryParse(deadlineStr);
      if (start == null || deadline == null || !deadline.isAfter(start)) {
        pace = {'status': 'unscheduled', 'monthly_target': 0, 'expected_at_today': 0, 'delta': 0};
      } else {
        final totalMonths = _monthsBetween(start, deadline).clamp(1, 1000);
        final monthlyTarget = target / totalMonths;
        final now = DateTime.now();
        final elapsedMonths = _monthsBetween(start, now).clamp(0, totalMonths);
        final expectedAtToday = monthlyTarget * elapsedMonths;
        final delta = current - expectedAtToday;
        String s;
        if (delta > 0.01) {
          s = 'ahead';
        } else if (delta < -0.01) {
          s = 'off_track';
        } else {
          s = 'on_track';
        }
        pace = {
          'status': s,
          'monthly_target': monthlyTarget,
          'expected_at_today': expectedAtToday,
          'delta': delta,
        };
      }
    }

    final remaining = (target - current).clamp(0.0, double.infinity);
    final progressPct = target > 0 ? (current / target * 100).clamp(0, 100) : 0.0;

    return SavingGoalModel.fromJson({
      ...row,
      'remaining': remaining,
      'progress_percentage': progressPct,
      'pace': pace,
    });
  }

  int _monthsBetween(DateTime a, DateTime b) => (b.year - a.year) * 12 + (b.month - a.month);
}

String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

final savingGoalsRemoteDataSourceProvider =
    Provider<SavingGoalsRemoteDataSource>((ref) {
  return SavingGoalsRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
