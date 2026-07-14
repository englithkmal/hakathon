import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../period/data/models/selected_period.dart';
import '../models/dashboard_model.dart';

class HomeShellData {
  const HomeShellData({
    required this.dashboard,
    required this.serverPeriod,
    this.balanceChangePercent,
  });
  final DashboardModel dashboard;
  final SelectedPeriod serverPeriod;
  final double? balanceChangePercent;
}

abstract class HomeRemoteDataSource {
  Future<HomeShellData> fetchHomeShell({int? month, int? year});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  HomeRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<HomeShellData> fetchHomeShell({int? month, int? year}) async {
    try {
      final now = DateTime.now();
      final m = month ?? now.month;
      final y = year ?? now.year;
      final first = DateTime(y, m, 1);
      final last = DateTime(y, m + 1, 0);
      final periodStart = _ymd(first);
      final periodEnd = _ymd(last);

      // معاملات الشهر الحالي
      final txs = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', _userId)
          .gte('transaction_date', periodStart)
          .lte('transaction_date', periodEnd)
          .order('transaction_date', ascending: false) as List;

      double income = 0, expenses = 0, savings = 0;
      final byCategory = <int, Map<String, dynamic>>{};
      for (final raw in txs) {
        final t = Map<String, dynamic>.from(raw);
        final amount = _toDouble(t['amount']).abs();
        final type = (t['type'] ?? 'expense').toString();
        if (type == 'income') {
          income += amount;
        } else if (type == 'saving') {
          savings += amount;
        } else {
          expenses += amount;
          final cat = t['categories'] is Map ? Map<String, dynamic>.from(t['categories'] as Map) : <String, dynamic>{};
          final catId = _toInt(cat['id']);
          if (catId > 0) {
            final entry = byCategory.putIfAbsent(catId, () => {
                  'category': cat,
                  'total': 0.0,
                  'count': 0,
                });
            entry['total'] = (entry['total'] as double) + amount;
            entry['count'] = (entry['count'] as int) + 1;
          }
        }
      }

      // الملف الشخصي للمستخدم (الراتب + العملة)
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', _userId)
          .maybeSingle();

      final currency = (profile?['currency'] ?? 'SAR').toString();
      final monthlyIncome = _toDouble(profile?['monthly_income']);
      final totalIncome = monthlyIncome + income;
      final balance = totalIncome - expenses - savings;

      // الميزانية النشطة لهذا الشهر
      final budgetRow = await _supabase
          .from('budgets')
          .select('*, budget_categories(*, categories(*))')
          .eq('user_id', _userId)
          .eq('month', m)
          .eq('year', y)
          .maybeSingle();

      Map<String, dynamic> budgetJson = const {};
      bool hasActiveBudget = false;
      if (budgetRow != null) {
        hasActiveBudget = (budgetRow['status'] ?? '') == 'active';
        final rawCats = (budgetRow['budget_categories'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        double totalSpent = 0;
        final mappedCats = rawCats.map((c) {
          final catId = _toInt(c['category_id']);
          final allocated = _toDouble(c['allocated_amount']);
          final spent = (byCategory[catId]?['total'] as double?) ?? 0;
          totalSpent += spent;
          final usage = allocated > 0 ? (spent / allocated * 100) : 0.0;
          return {
            'id': c['id'],
            'category': c['categories'] is Map ? c['categories'] : {},
            'allocated_amount': allocated,
            'spent_amount': spent,
            'remaining': (allocated - spent).clamp(0.0, double.infinity),
            'usage_percentage': usage,
            'alert_threshold': c['alert_threshold'],
          };
        }).toList();

        final totalAmount = _toDouble(budgetRow['total_amount']);
        budgetJson = {
          ...budgetRow,
          'categories': mappedCats,
          'total_spent': totalSpent,
          'remaining': (totalAmount - totalSpent).clamp(0.0, double.infinity),
          'progress_percentage': totalAmount > 0 ? (totalSpent / totalAmount * 100) : 0.0,
          'exists': true,
        };
      }

      // أهداف الادخار النشطة
      final goalsRows = await _supabase
          .from('saving_goals')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false) as List;

      final activeGoals = goalsRows.map((g) {
        final row = Map<String, dynamic>.from(g);
        final target = _toDouble(row['target_amount']);
        final current = _toDouble(row['current_amount']);
        return {
          ...row,
          'remaining': (target - current).clamp(0.0, double.infinity),
          'progress_percentage': target > 0 ? (current / target * 100).clamp(0, 100) : 0.0,
        };
      }).toList();

      final savingsOverview = {
        'count': activeGoals.length,
        'total_target': activeGoals.fold<double>(0, (a, g) => a + _toDouble(g['target_amount'])),
        'total_current': activeGoals.fold<double>(0, (a, g) => a + _toDouble(g['current_amount'])),
        'progress_percentage': () {
          final t = activeGoals.fold<double>(0, (a, g) => a + _toDouble(g['target_amount']));
          final c = activeGoals.fold<double>(0, (a, g) => a + _toDouble(g['current_amount']));
          return t > 0 ? (c / t * 100).clamp(0, 100) : 0.0;
        }(),
      };

      // أفضل 5 فئات إنفاق (quick insights)
      final quickInsightsList = byCategory.values.toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
      final quickInsights = quickInsightsList.take(5).map((e) {
        final total = e['total'] as double;
        return {
          'category': e['category'],
          'total': total,
          'count': e['count'],
          'percentage': expenses > 0 ? (total / expenses * 100) : 0.0,
        };
      }).toList();

      // أحدث 5 معاملات
      final recentTransactions = txs.take(5).map((raw) {
        final t = Map<String, dynamic>.from(raw);
        if (t.containsKey('categories')) t['category'] = t.remove('categories');
        return t;
      }).toList();

      // إشعارات غير مقروءة
      int unreadAlertsCount = 0;
      List<Map<String, dynamic>> recentAlerts = const [];
      try {
        final unread = await _supabase
            .from('notifications')
            .select('id')
            .eq('user_id', _userId)
            .eq('is_read', false)
            .count(CountOption.exact);
        unreadAlertsCount = unread.count;

        final alertsRows = await _supabase
            .from('notifications')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: false)
            .limit(5) as List;
        recentAlerts = alertsRows.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        // جدول notifications قد لا يكون موجوداً بعد — تجاهل بأمان
      }

      // حساب نسبة التغيّر عن الشهر السابق (MoM)
      double? mom;
      try {
        final prevFirst = DateTime(y, m - 1, 1);
        final prevLast = DateTime(y, m, 0);
        final prevTxs = await _supabase
            .from('transactions')
            .select('amount, type')
            .eq('user_id', _userId)
            .gte('transaction_date', _ymd(prevFirst))
            .lte('transaction_date', _ymd(prevLast)) as List;

        double pIncome = 0, pExpenses = 0, pSavings = 0;
        for (final raw in prevTxs) {
          final t = Map<String, dynamic>.from(raw);
          final amount = _toDouble(t['amount']).abs();
          final type = (t['type'] ?? 'expense').toString();
          if (type == 'income') {
            pIncome += amount;
          } else if (type == 'saving') {
            pSavings += amount;
          } else {
            pExpenses += amount;
          }
        }
        final prevBalance = (monthlyIncome + pIncome) - pExpenses - pSavings;
        if (prevBalance.abs() >= 0.01) {
          mom = ((balance - prevBalance) / prevBalance) * 100;
        }
      } catch (_) {
        mom = null;
      }

      final dashboardJson = {
        'message': '',
        'currency': currency,
        'period': {
          'month': m,
          'year': y,
          'period_start': periodStart,
          'period_end': periodEnd,
        },
        'has_active_budget': hasActiveBudget,
        'summary': {
          'income': income,
          'expenses': expenses,
          'savings': savings,
          'balance': balance,
          'monthly_income': monthlyIncome,
          'total_income': totalIncome,
        },
        'budget': budgetJson,
        'last_active_budget': const {},
        'quick_insights': quickInsights,
        'savings_overview': savingsOverview,
        'month_transactions_count': txs.length,
        'recent_transactions': recentTransactions,
        'active_goals': activeGoals,
        'unread_alerts_count': unreadAlertsCount,
        'recent_alerts': recentAlerts,
        'tip_of_the_day': const {},
        'monthly_summary': const {},
      };

      final dashboard = DashboardModel.fromJson(dashboardJson);

      return HomeShellData(
        dashboard: dashboard,
        serverPeriod: SelectedPeriod(
          month: m,
          year: y,
          periodStart: periodStart,
          periodEnd: periodEnd,
          source: (month != null && year != null)
              ? PeriodSource.explicit
              : PeriodSource.serverNow,
          budgetId: budgetRow != null ? _toInt(budgetRow['id']) : null,
        ),
        balanceChangePercent: mom,
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }
}

String _ymd(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final mo = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$mo-$day';
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

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
