import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/selected_period.dart';

/// يحدد الفترة (الشهر/السنة) النشطة للمستخدم.
///
/// بدل استدعاء API، نحسبها محلياً:
///  - إذا تم تمرير month/year أو periodStart → `source: explicit`.
///  - وإلا نبحث عن آخر ميزانية نشطة (`status = active`) للمستخدم
///    → `source: latest_budget`.
///  - وإلا → شهر السيرفر الحالي (`source: server_now`).
abstract class PeriodRemoteDataSource {
  Future<SelectedPeriod> fetchPeriod({
    int? month,
    int? year,
    String? periodStart,
  });
}

class PeriodRemoteDataSourceImpl implements PeriodRemoteDataSource {
  PeriodRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<SelectedPeriod> fetchPeriod({
    int? month,
    int? year,
    String? periodStart,
  }) async {
    try {
      // 1) صريح
      if (month != null && year != null) {
        return _periodFor(year, month, PeriodSource.explicit);
      }
      if (periodStart != null && periodStart.isNotEmpty) {
        final d = DateTime.tryParse(periodStart);
        if (d != null) {
          return _periodFor(d.year, d.month, PeriodSource.periodStartParam);
        }
      }

      // 2) آخر ميزانية نشطة
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final res = await _supabase
            .from('budgets')
            .select('id, month, year')
            .eq('user_id', userId)
            .eq('status', 'active')
            .order('year', ascending: false)
            .order('month', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          final m = _toInt(res['month']);
          final y = _toInt(res['year']);
          return _periodFor(
            y,
            m,
            PeriodSource.latestBudget,
            budgetId: _toInt(res['id']),
          );
        }
      }

      // 3) شهر السيرفر الحالي
      final now = DateTime.now();
      return _periodFor(now.year, now.month, PeriodSource.serverNow);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  SelectedPeriod _periodFor(
    int year,
    int month,
    PeriodSource source, {
    int? budgetId,
  }) {
    final firstOfMonth = DateTime(year, month, 1);
    final lastOfMonth = DateTime(year, month + 1, 0);
    return SelectedPeriod(
      month: month,
      year: year,
      periodStart: _ymd(firstOfMonth),
      periodEnd: _ymd(lastOfMonth),
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

int _toInt(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

final periodRemoteDataSourceProvider = Provider<PeriodRemoteDataSource>((ref) {
  return PeriodRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
