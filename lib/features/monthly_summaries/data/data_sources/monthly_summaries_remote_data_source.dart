import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/monthly_summary_model.dart';

class MonthlySummariesPage {
  const MonthlySummariesPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
  final List<MonthlySummaryModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}

abstract class MonthlySummariesRemoteDataSource {
  Future<MonthlySummariesPage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  });

  Future<MonthlySummaryModel> fetchByYearMonth({
    required int year,
    required int month,
  });

  Future<MonthlySummaryAllocateResult> allocate({
    required int summaryId,
    required int savingGoalId,
    required double amount,
    String? note,
  });
}

/// يتوقع جدول `monthly_summaries` بالأعمدة:
/// id, user_id, year, month, period_start, period_end, currency,
/// allocation_status, allocated_amount, unallocated_remaining,
/// closed_at, closed_by, notes
///
/// السطور تُنشأ عبر عملية "إقفال الشهر" (يدوياً أو بمهمة مجدولة).
/// هذا الـ data source يحسب cash_flow + top_categories من
/// transactions في وقت القراءة.
class MonthlySummariesRemoteDataSourceImpl implements MonthlySummariesRemoteDataSource {
  MonthlySummariesRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<MonthlySummariesPage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) async {
    try {
      final from0 = (page - 1) * perPage;
      final to0 = from0 + perPage - 1;

      dynamic query = _supabase
          .from('monthly_summaries')
          .select('*')
          .eq('user_id', _userId);

      if (year != null) query = query.eq('year', year) as dynamic;
      if (status == 'closed') {
        query = query.not('closed_at', 'is', null) as dynamic;
      } else if (status == 'open') {
        query = query.filter('closed_at', 'is', null) as dynamic;
      }

      query = query
          .order('year', ascending: false)
          .order('month', ascending: false)
          .range(from0, to0) as dynamic;

      final res = await query.count(CountOption.exact);
      final rows = (res.data as List).cast<Map<String, dynamic>>();
      final total = res.count ?? rows.length;
      final lastPage = (total / perPage).ceil().clamp(1, 999999);

      final items = <MonthlySummaryModel>[];
      for (final r in rows) {
        items.add(await _withCashFlow(r));
      }

      return MonthlySummariesPage(
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
  Future<MonthlySummaryModel> fetchByYearMonth({
    required int year,
    required int month,
  }) async {
    try {
      final row = await _supabase
          .from('monthly_summaries')
          .select()
          .eq('user_id', _userId)
          .eq('year', year)
          .eq('month', month)
          .maybeSingle();

      if (row == null) {
        // لا يوجد سجل إقفال — نبني واحداً افتراضياً (مفتوح) من المعاملات
        final first = DateTime(year, month, 1);
        final last = DateTime(year, month + 1, 0);
        return _withCashFlow({
          'id': 0,
          'year': year,
          'month': month,
          'period_start': _ymd(first),
          'period_end': _ymd(last),
          'allocation_status': 'unallocated',
          'allocated_amount': 0,
          'unallocated_remaining': 0,
          'closed_at': null,
          'closed_by': null,
          'notes': '',
        });
      }

      return _withCashFlow(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<MonthlySummaryAllocateResult> allocate({
    required int summaryId,
    required int savingGoalId,
    required double amount,
    String? note,
  }) async {
    try {
      final summaryRow = await _supabase
          .from('monthly_summaries')
          .select()
          .eq('id', summaryId)
          .single();

      final currentRemaining = _toDouble(summaryRow['unallocated_remaining']);
      if (amount > currentRemaining + 0.01) {
        throw ValidationException(
          message: 'المبلغ أكبر من المتبقي غير المخصّص.',
          statusCode: 422,
        );
      }

      // 1) إنشاء transaction من نوع saving
      final txRow = await _supabase
          .from('transactions')
          .insert({
            'user_id': _userId,
            'amount': amount,
            'currency': (summaryRow['currency'] ?? 'SAR').toString(),
            'type': 'saving',
            'description': note ?? '',
            'merchant': '',
            'source': 'allocation',
            'reference': '',
            'transaction_date': _ymd(DateTime.now()),
            'saving_goal_id': savingGoalId,
          })
          .select()
          .single();

      // 2) تحديث الهدف
      final goalRow = await _supabase
          .from('saving_goals')
          .select()
          .eq('id', savingGoalId)
          .single();
      final newCurrent = _toDouble(goalRow['current_amount']) + amount;
      final target = _toDouble(goalRow['target_amount']);
      final updatedGoal = await _supabase
          .from('saving_goals')
          .update({'current_amount': newCurrent})
          .eq('id', savingGoalId)
          .select()
          .single();

      // 3) تحديث ملخص الشهر
      final newAllocated = _toDouble(summaryRow['allocated_amount']) + amount;
      final newRemaining = (currentRemaining - amount).clamp(0.0, double.infinity);
      final newStatus = newRemaining <= 0.01 ? 'fully_allocated' : 'partially_allocated';

      final updatedSummary = await _supabase
          .from('monthly_summaries')
          .update({
            'allocated_amount': newAllocated,
            'unallocated_remaining': newRemaining,
            'allocation_status': newStatus,
          })
          .eq('id', summaryId)
          .select()
          .single();

      return MonthlySummaryAllocateResult.fromJson({
        'transaction': txRow,
        'monthly_summary': updatedSummary,
        'saving_goal': {
          ...updatedGoal,
          'progress_percentage': target > 0 ? (newCurrent / target * 100).clamp(0, 100) : 0,
        },
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  /// يحسب income/expenses/goal_deposits/top_categories من جدول
  /// transactions للفترة period_start..period_end.
  Future<MonthlySummaryModel> _withCashFlow(Map<String, dynamic> row) async {
    final periodStart = (row['period_start'] ?? '').toString();
    final periodEnd = (row['period_end'] ?? '').toString();

    double income = 0, expenses = 0, goalDeposits = 0;
    int txCount = 0;
    final byCategory = <int, Map<String, dynamic>>{};

    if (periodStart.isNotEmpty && periodEnd.isNotEmpty) {
      final txs = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', _userId)
          .gte('transaction_date', periodStart)
          .lte('transaction_date', periodEnd) as List;

      txCount = txs.length;
      for (final raw in txs) {
        final t = Map<String, dynamic>.from(raw);
        final amount = _toDouble(t['amount']).abs();
        final type = (t['type'] ?? 'expense').toString();
        if (type == 'income') {
          income += amount;
        } else if (type == 'saving') {
          goalDeposits += amount;
        } else {
          expenses += amount;
          final cat = t['categories'] is Map ? Map<String, dynamic>.from(t['categories'] as Map) : <String, dynamic>{};
          final catId = _toInt(cat['id']);
          if (catId > 0) {
            final entry = byCategory.putIfAbsent(catId, () => {
                  'category_id': catId,
                  'name_ar': cat['name_ar'],
                  'name_en': cat['name_en'],
                  'total': 0.0,
                  'count': 0,
                });
            entry['total'] = (entry['total'] as double) + amount;
            entry['count'] = (entry['count'] as int) + 1;
          }
        }
      }
    }

    final topCategories = byCategory.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    final topCatsJson = topCategories.take(5).map((e) {
      final total = e['total'] as double;
      return {
        ...e,
        'percentage': expenses > 0 ? (total / expenses * 100) : 0.0,
      };
    }).toList();

    return MonthlySummaryModel.fromJson({
      ...row,
      'cash_flow': {
        'total_income': income,
        'total_expenses': expenses,
        'total_goal_deposits': goalDeposits,
        'unallocated_savings': income - expenses - goalDeposits,
      },
      'transaction_count': txCount,
      'top_categories': topCatsJson,
    });
  }
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

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

final monthlySummariesRemoteDataSourceProvider =
    Provider<MonthlySummariesRemoteDataSource>((ref) {
  return MonthlySummariesRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
