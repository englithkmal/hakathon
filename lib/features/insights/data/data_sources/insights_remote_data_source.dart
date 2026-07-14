import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/expense_analysis_model.dart';

abstract class InsightsRemoteDataSource {
  Future<ExpenseAnalysisModel> fetchExpenseAnalysis({
    int? month,
    int? year,
    String? periodStart,
  });
}

class InsightsRemoteDataSourceImpl implements InsightsRemoteDataSource {
  InsightsRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<ExpenseAnalysisModel> fetchExpenseAnalysis({
    int? month,
    int? year,
    String? periodStart,
  }) async {
    try {
      int m;
      int y;
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
      final pStart = _ymd(first);
      final pEnd = _ymd(last);

      final txs = await _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', _userId)
          .eq('type', 'expense')
          .gte('transaction_date', pStart)
          .lte('transaction_date', pEnd) as List;

      double totalSpent = 0;
      final byCategory = <int, Map<String, dynamic>>{};
      for (final raw in txs) {
        final t = Map<String, dynamic>.from(raw);
        final amount = _toDouble(t['amount']).abs();
        totalSpent += amount;
        final cat = t['categories'] is Map ? Map<String, dynamic>.from(t['categories'] as Map) : <String, dynamic>{};
        final catId = _toInt(cat['id']);
        final entry = byCategory.putIfAbsent(catId, () => {
              'category': cat,
              'total': 0.0,
              'count': 0,
            });
        entry['total'] = (entry['total'] as double) + amount;
        entry['count'] = (entry['count'] as int) + 1;
      }

      final categories = byCategory.values.map((e) {
        final total = e['total'] as double;
        final cat = e['category'] as Map<String, dynamic>;
        return {
          'category_id': cat['id'],
          'category': cat,
          'total': total,
          'percentage': totalSpent > 0 ? (total / totalSpent * 100) : 0.0,
          'transaction_count': e['count'],
        };
      }).toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      // الشهر السابق للمقارنة
      double? momTotal;
      try {
        final prevFirst = DateTime(y, m - 1, 1);
        final prevLast = DateTime(y, m, 0);
        final prevTxs = await _supabase
            .from('transactions')
            .select('amount')
            .eq('user_id', _userId)
            .eq('type', 'expense')
            .gte('transaction_date', _ymd(prevFirst))
            .lte('transaction_date', _ymd(prevLast)) as List;
        double prevTotal = 0;
        for (final raw in prevTxs) {
          prevTotal += _toDouble((raw as Map)['amount']).abs();
        }
        if (prevTotal.abs() >= 0.01) {
          momTotal = ((totalSpent - prevTotal) / prevTotal) * 100;
        }
      } catch (_) {
        momTotal = null;
      }

      final daysInPeriod = last.difference(first).inDays + 1;
      final dailyAverage = daysInPeriod > 0 ? totalSpent / daysInPeriod : 0.0;

      final profile = await _supabase
          .from('profiles')
          .select('currency')
          .eq('id', _userId)
          .maybeSingle();
      final currency = (profile?['currency'] ?? 'SAR').toString();

      final payload = {
        'currency': currency,
        'categories': categories,
        'period': {
          'month': m,
          'year': y,
          'period_start': pStart,
          'period_end': pEnd,
        },
        'summary': {
          'total_spent': totalSpent,
          'category_count': categories.length,
          'transaction_count': txs.length,
          'avg_per_transaction': txs.isNotEmpty ? totalSpent / txs.length : 0.0,
          'daily_average': dailyAverage,
          'mom_change_percent': momTotal,
          'top_category_name': categories.isNotEmpty
              ? ((categories.first['category'] as Map)['name'] ?? '').toString()
              : '',
        },
      };

      return ExpenseAnalysisModel.fromJson(payload);
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

final insightsRemoteDataSourceProvider = Provider<InsightsRemoteDataSource>((ref) {
  return InsightsRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
