import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../period/data/models/selected_period.dart';
import '../../../period/presentation/providers/selected_period_provider.dart';
import '../../data/data_sources/home_remote_data_source.dart';
import '../../data/repositories/home_repository.dart';

final dashboardProvider =
    AsyncNotifierProvider.autoDispose<DashboardNotifier, HomeShellData>(
  DashboardNotifier.new,
);

/// Drives `GET /dashboard`.
///
/// Aligns to the canonical period exposed by [selectedPeriodProvider]
/// so the dashboard, budget tab and insights all render the same month
/// — never compute the period locally (see spec "Active Period" rule).
class DashboardNotifier extends AutoDisposeAsyncNotifier<HomeShellData> {
  @override
  Future<HomeShellData> build() async {
    // Re-fetch when the user toggles language so the backend can
    // serve `name_ar` vs `name_en` for category labels via the
    // `Accept-Language` header.
    ref.watch(localeProvider);

    // Wait for the period resolver to pick a month. While the period
    // is loading we let dashboard show its own loader. If the period
    // ever errors, [SelectedPeriodNotifier] swallows it and returns
    // a local fallback, so this `await` always completes.
    final period = await ref.watch(selectedPeriodProvider.future);
    return ref.read(homeRepositoryProvider).loadHome(
          month: period.month,
          year: period.year,
        );
  }

  /// Pull-to-refresh: keep the previous data visible while a fresh
  /// fetch is in flight (uses `AsyncValue.loading().copyWithPrevious`).
  /// `ref.invalidateSelf()` would also work, but we want the spinner
  /// only inside `RefreshIndicator`, not a full-screen loader.
  Future<void> refresh() async {
    final prev = state;
    state = const AsyncLoading<HomeShellData>().copyWithPrevious(prev);
    state = await AsyncValue.guard(() async {
      final period = await ref.read(selectedPeriodProvider.future);
      return ref.read(homeRepositoryProvider).loadHome(
            month: period.month,
            year: period.year,
          );
    });
  }
}

/// Convenience: exposes just the `period` echoed back by `/dashboard`.
/// Lets banners / period switchers read the resolved source without
/// pulling the full [HomeShellData] payload.
final dashboardServerPeriodProvider =
    Provider.autoDispose<SelectedPeriod?>((ref) {
  return ref.watch(dashboardProvider).maybeWhen(
        data: (shell) => shell.serverPeriod,
        orElse: () => null,
      );
});
