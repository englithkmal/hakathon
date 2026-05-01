import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/selected_period.dart';
import '../../data/repositories/period_repository.dart';

/// Single source of truth for the active reporting period across
/// `Dashboard`, `Budgets/current`, `Insights` and `Monthly Summaries`.
///
/// Lifecycle:
///
///  * **Cold-start**: build watches [authProvider]. While the user is
///    unauthenticated (initialising or not logged in) we surface a local
///    fallback so screens that try to read this provider during the
///    splash don't lock up.
///  * **First authenticated read**: hits `GET /period` with no query so
///    the server picks (latest active budget → server's current month).
///  * **Explicit navigation**: callers use [setExplicit] to anchor to a
///    different month — this re-hits `GET /period?month=&year=` so the
///    server can re-resolve `budget_id` and `source` for the new view.
///
/// Errors are intentionally swallowed and replaced with a local fallback
/// so the rest of the app stays usable when the network is flaky — the
/// UI loses the "showing latest budget" banner but keeps rendering the
/// current calendar month, which is the safest default.
class SelectedPeriodNotifier extends AsyncNotifier<SelectedPeriod> {
  @override
  Future<SelectedPeriod> build() async {
    final auth = ref.watch(authProvider);
    if (auth is! AuthAuthenticated) {
      return SelectedPeriod.localFallback();
    }
    return _fetchSafely();
  }

  /// Re-hits `GET /period` with explicit `month`/`year`. Use from the
  /// UI when the user navigates to a different month (e.g. tapping a
  /// "next month" arrow on the budget tab). The new period propagates
  /// to every screen that watches this provider.
  Future<void> setExplicit({required int month, required int year}) async {
    state =
        const AsyncLoading<SelectedPeriod>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => _fetchSafely(month: month, year: year),
    );
  }

  /// Re-hits `GET /period` with `period_start` (any `YYYY-MM-DD` inside
  /// the target month). Convenience for callers that already have a
  /// concrete date in hand.
  Future<void> setByPeriodStart(String periodStart) async {
    state =
        const AsyncLoading<SelectedPeriod>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => _fetchSafely(periodStart: periodStart),
    );
  }

  /// Forces a refetch — useful after creating/editing a budget so the
  /// server's `latest_budget` resolution picks up the new month.
  Future<void> reload() async {
    ref.invalidateSelf();
  }

  Future<SelectedPeriod> _fetchSafely({
    int? month,
    int? year,
    String? periodStart,
  }) async {
    if (AppConstants.useMockBackend) {
      return SelectedPeriod.localFallback();
    }
    try {
      return await ref.read(periodRepositoryProvider).fetch(
            month: month,
            year: year,
            periodStart: periodStart,
          );
    } catch (e, st) {
      // Period is best-effort — never block the rest of the app on it.
      // The dashboard / budget will fall back to "let the server pick"
      // (or the device's calendar month) when this happens.
      debugPrint('[SelectedPeriod] fetch failed → local fallback: $e\n$st');
      return SelectedPeriod.localFallback();
    }
  }
}

final selectedPeriodProvider =
    AsyncNotifierProvider<SelectedPeriodNotifier, SelectedPeriod>(
  SelectedPeriodNotifier.new,
);
