import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../period/data/models/selected_period.dart';
import '../models/budget_model.dart';
import '../models/saving_goal_model.dart';

class CurrentBudgetResult {
  const CurrentBudgetResult({required this.budget, required this.serverPeriod});
  final BudgetModel? budget;
  final SelectedPeriod serverPeriod;
}

class BudgetsPage {
  const BudgetsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
  final List<BudgetModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
  bool get hasMore => currentPage < lastPage;
}

class BudgetTabData {
  const BudgetTabData({
    required this.budget,
    required this.goals,
    required this.serverPeriod,
  });
  final BudgetModel? budget;
  final List<SavingGoalModel> goals;
  final SelectedPeriod serverPeriod;
}

class BudgetCategoryAllocation {
  const BudgetCategoryAllocation({
    required this.categoryId,
    required this.allocatedAmount,
    this.alertThreshold = 80,
  });
  final int categoryId;
  final double allocatedAmount;
  final int alertThreshold;

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'allocated_amount': allocatedAmount,
        'alert_threshold': alertThreshold,
      };
}

abstract class BudgetRemoteDataSource {
  Future<CurrentBudgetResult> fetchCurrentBudget({int? month, int? year});

  Future<BudgetsPage> fetchAll({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  });

  Future<List<SavingGoalModel>> fetchActiveSavingGoals();

  Future<BudgetTabData> fetchBudgetTab({int? month, int? year});

  Future<BudgetModel> createBudget({
    required double totalAmount,
    required String currency,
    required List<BudgetCategoryAllocation> categories,
    int? month,
    int? year,
    String? periodStart,
    double? totalIncome,
    String status = 'active',
  });

  Future<BudgetModel> updateBudget({
    required int budgetId,
    required double totalAmount,
    required List<BudgetCategoryAllocation> categories,
    double? totalIncome,
    String? currency,
    String? status,
  });

  Future<SavingGoalModel> createSavingGoal({
    required String title,
    required double targetAmount,
    required String deadline,
    required String currency,
    String? description,
    String? icon,
    String? color,
    String? startDate,
  });
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  BudgetRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<CurrentBudgetResult> fetchCurrentBudget({int? month, int? year}) async {
    try {
      Map<String, dynamic>? row;

      if (month != null && year != null) {
        row = await _supabase
            .from('budgets')
            .select('*, budget_categories(*, categories(*))')
            .eq('user_id', _userId)
            .eq('month', month)
            .eq('year', year)
            .maybeSingle();

        if (row != null) {
          final budget = await _withSpending(row);
          return CurrentBudgetResult(
            budget: budget,
            serverPeriod: _periodFromBudget(row, PeriodSource.explicit),
          );
        }
        return CurrentBudgetResult(
          budget: null,
          serverPeriod: _periodFor(year, month, PeriodSource.explicit),
        );
      }

      // بدون month/year: نبحث عن آخر ميزانية نشطة، ثم نتراجع لشهر السيرفر
      row = await _supabase
          .from('budgets')
          .select('*, budget_categories(*, categories(*))')
          .eq('user_id', _userId)
          .eq('status', 'active')
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        final budget = await _withSpending(row);
        return CurrentBudgetResult(
          budget: budget,
          serverPeriod: _periodFromBudget(row, PeriodSource.latestBudget),
        );
      }

      final now = DateTime.now();
      return CurrentBudgetResult(
        budget: null,
        serverPeriod: _periodFor(now.year, now.month, PeriodSource.serverNow),
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<BudgetsPage> fetchAll({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) async {
    try {
      final from0 = (page - 1) * perPage;
      final to0 = from0 + perPage - 1;

      dynamic query = _supabase
          .from('budgets')
          .select('*, budget_categories(*, categories(*))')
          .eq('user_id', _userId);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status) as dynamic;
      }
      if (year != null) {
        query = query.eq('year', year) as dynamic;
      }

      query = query
          .order('year', ascending: false)
          .order('month', ascending: false)
          .range(from0, to0) as dynamic;

      final res = await query.count(CountOption.exact);
      final rows = (res.data as List).cast<Map<String, dynamic>>();
      final total = res.count ?? rows.length;
      final lastPage = (total / perPage).ceil().clamp(1, 999999);

      final items = <BudgetModel>[];
      for (final r in rows) {
        items.add(await _withSpending(r));
      }

      return BudgetsPage(
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
  Future<List<SavingGoalModel>> fetchActiveSavingGoals() async {
    try {
      final rows = await _supabase
          .from('saving_goals')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false) as List;

      final result = <SavingGoalModel>[];
      for (final r in rows) {
        result.add(await _withPace(Map<String, dynamic>.from(r)));
      }
      return result;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<BudgetTabData> fetchBudgetTab({int? month, int? year}) async {
    final results = await Future.wait<Object>([
      fetchCurrentBudget(month: month, year: year),
      fetchActiveSavingGoals(),
    ]);
    final budgetResult = results[0] as CurrentBudgetResult;
    return BudgetTabData(
      budget: budgetResult.budget,
      serverPeriod: budgetResult.serverPeriod,
      goals: results[1] as List<SavingGoalModel>,
    );
  }

  @override
  Future<BudgetModel> createBudget({
    required double totalAmount,
    required String currency,
    required List<BudgetCategoryAllocation> categories,
    int? month,
    int? year,
    String? periodStart,
    double? totalIncome,
    String status = 'active',
  }) async {
    try {
      int m;
      int y;
      String pStart;
      String pEnd;
      if (periodStart != null && periodStart.isNotEmpty) {
        final d = DateTime.parse(periodStart);
        m = d.month;
        y = d.year;
      } else {
        final now = DateTime.now();
        m = month ?? now.month;
        y = year ?? now.year;
      }
      final first = DateTime(y, m, 1);
      final last = DateTime(y, m + 1, 0);
      pStart = _ymd(first);
      pEnd = _ymd(last);

      final budgetRow = await _supabase
          .from('budgets')
          .insert({
            'user_id': _userId,
            'month': m,
            'year': y,
            'period_start': pStart,
            'period_end': pEnd,
            'total_amount': totalAmount,
            'total_income': totalIncome ?? 0,
            'currency': currency,
            'status': status,
          })
          .select()
          .single();

      final budgetId = budgetRow['id'] as int;

      if (categories.isNotEmpty) {
        await _supabase.from('budget_categories').insert(
              categories
                  .map((c) => {
                        'budget_id': budgetId,
                        'category_id': c.categoryId,
                        'allocated_amount': c.allocatedAmount,
                        'alert_threshold': c.alertThreshold,
                      })
                  .toList(),
            );
      }

      final fullRow = await _supabase
          .from('budgets')
          .select('*, budget_categories(*, categories(*))')
          .eq('id', budgetId)
          .single();

      return _withSpending(fullRow);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<BudgetModel> updateBudget({
    required int budgetId,
    required double totalAmount,
    required List<BudgetCategoryAllocation> categories,
    double? totalIncome,
    String? currency,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{
        'total_amount': totalAmount,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (totalIncome != null) updates['total_income'] = totalIncome;
      if (currency != null && currency.isNotEmpty) updates['currency'] = currency;
      if (status != null && status.isNotEmpty) updates['status'] = status;

      await _supabase.from('budgets').update(updates).eq('id', budgetId);

      // استبدال كامل لقائمة التخصيصات (سلوك "sync")
      await _supabase.from('budget_categories').delete().eq('budget_id', budgetId);
      if (categories.isNotEmpty) {
        await _supabase.from('budget_categories').insert(
              categories
                  .map((c) => {
                        'budget_id': budgetId,
                        'category_id': c.categoryId,
                        'allocated_amount': c.allocatedAmount,
                        'alert_threshold': c.alertThreshold,
                      })
                  .toList(),
            );
      }

      final fullRow = await _supabase
          .from('budgets')
          .select('*, budget_categories(*, categories(*))')
          .eq('id', budgetId)
          .single();

      return _withSpending(fullRow);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<SavingGoalModel> createSavingGoal({
    required String title,
    required double targetAmount,
    required String deadline,
    required String currency,
    String? description,
    String? icon,
    String? color,
    String? startDate,
  }) async {
    try {
      final row = await _supabase
          .from('saving_goals')
          .insert({
            'user_id': _userId,
            'title': title,
            'target_amount': targetAmount,
            'current_amount': 0,
            'currency': currency,
            'deadline': deadline,
            'status': 'active',
            'description': description ?? '',
            'icon': icon ?? '',
            'color': color ?? '',
            'start_date': startDate ?? _ymd(DateTime.now()),
          })
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

  // ─────────────────────────────────────────────────────────────────
  // Helpers — حساب المصروف الفعلي لكل فئة من جدول transactions، لأن
  // Supabase لا يحسب total_spent / usage_percentage تلقائياً كما كان
  // يفعل سيرفر Laravel.
  // ─────────────────────────────────────────────────────────────────

  Future<BudgetModel> _withSpending(Map<String, dynamic> budgetRow) async {
    final row = Map<String, dynamic>.from(budgetRow);
    final rawCats = (row['budget_categories'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final periodStart = (row['period_start'] ?? '').toString();
    final periodEnd = (row['period_end'] ?? '').toString();

    // مجموع كل فئة من المصروفات الفعلية لهذا الشهر
    final spendByCategory = <int, double>{};
    double totalSpent = 0;

    if (periodStart.isNotEmpty && periodEnd.isNotEmpty) {
      final txs = await _supabase
          .from('transactions')
          .select('category_id, amount, type')
          .eq('user_id', _userId)
          .eq('type', 'expense')
          .gte('transaction_date', periodStart)
          .lte('transaction_date', periodEnd) as List;

      for (final t in txs) {
        final catId = _toInt(t['category_id']);
        final amount = _toDouble(t['amount']).abs();
        spendByCategory[catId] = (spendByCategory[catId] ?? 0) + amount;
        totalSpent += amount;
      }
    }

    final mappedCats = rawCats.map((c) {
      final catId = _toInt(c['category_id']);
      final allocated = _toDouble(c['allocated_amount']);
      final spent = spendByCategory[catId] ?? 0;
      final usage = allocated > 0 ? (spent / allocated * 100) : 0.0;
      final remaining = (allocated - spent).clamp(0.0, double.infinity);

      final categoryMap = c['categories'] is Map
          ? Map<String, dynamic>.from(c['categories'] as Map)
          : <String, dynamic>{};

      return {
        'id': c['id'],
        'category': categoryMap,
        'allocated_amount': allocated,
        'spent_amount': spent,
        'remaining': remaining,
        'usage_percentage': usage,
        'alert_threshold': c['alert_threshold'],
      };
    }).toList();

    final totalAmount = _toDouble(row['total_amount']);
    final progressPct = totalAmount > 0 ? (totalSpent / totalAmount * 100) : 0.0;
    final remaining = (totalAmount - totalSpent).clamp(0.0, double.infinity);

    return BudgetModel.fromJson({
      ...row,
      'categories': mappedCats,
      'total_spent': totalSpent,
      'remaining': remaining,
      'progress_percentage': progressPct,
    });
  }

  /// يحسب `pace` للهدف الادخاري بناءً على start_date / deadline /
  /// target_amount / current_amount — نفس منطق السيرفر القديم.
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

        String paceStatus;
        if (delta > 0.01) {
          paceStatus = 'ahead';
        } else if (delta < -0.01) {
          paceStatus = 'off_track';
        } else {
          paceStatus = 'on_track';
        }

        pace = {
          'status': paceStatus,
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

  int _monthsBetween(DateTime a, DateTime b) {
    return (b.year - a.year) * 12 + (b.month - a.month);
  }

  SelectedPeriod _periodFromBudget(Map<String, dynamic> row, PeriodSource source) {
    final m = _toInt(row['month']);
    final y = _toInt(row['year']);
    return _periodFor(y, m, source, budgetId: _toInt(row['id']));
  }

  SelectedPeriod _periodFor(int year, int month, PeriodSource source, {int? budgetId}) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    return SelectedPeriod(
      month: month,
      year: year,
      periodStart: _ymd(first),
      periodEnd: _ymd(last),
      source: source,
      budgetId: budgetId,
    );
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

final budgetRemoteDataSourceProvider = Provider<BudgetRemoteDataSource>((ref) {
  return BudgetRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
