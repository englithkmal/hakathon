import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../period/presentation/providers/selected_period_provider.dart';
import '../../data/data_sources/budget_remote_data_source.dart';
import '../../data/repositories/budget_repository.dart';

/// Single source of truth for the "Saver" tab. Loads `/budgets/current`
/// and `/saving-goals?status=active` in parallel and exposes them as
/// one [BudgetTabData] payload so the screen only needs one
/// `AsyncValue.when`.
///
/// Watching [localeProvider] is intentional: the budget category names
/// are returned in the user's active language by Laravel (driven by
/// the `Accept-Language` header), so re-fetching when the user toggles
/// the language is the easiest way to keep the UI in sync.
///
/// Period resolution follows the spec rule "pass the same month/year
/// everywhere":
///
///  * Default → align to [selectedPeriodProvider] (the canonical
///    `GET /period` resolution).
///  * After explicit navigation (e.g. month switcher) → use the
///    [pinPeriod]-overridden values until [resetPeriod] is called.
final budgetTabProvider =
    AsyncNotifierProvider.autoDispose<BudgetTabNotifier, BudgetTabData>(
  BudgetTabNotifier.new,
);

class BudgetTabNotifier extends AutoDisposeAsyncNotifier<BudgetTabData> {
  /// User-pinned period override. `null` means "follow
  /// [selectedPeriodProvider]".
  int? _pinnedMonth;
  int? _pinnedYear;

  /// Exposes the tracked period so screens can show a month switcher.
  /// Returns the pinned values when set, otherwise the period the
  /// server resolved on the last fetch.
  int? get displayedMonth => _pinnedMonth ?? state.value?.serverPeriod.month;
  int? get displayedYear => _pinnedYear ?? state.value?.serverPeriod.year;

  @override
  Future<BudgetTabData> build() async {
    ref.watch(localeProvider);

    int? month = _pinnedMonth;
    int? year = _pinnedYear;
    if (month == null || year == null) {
      // Wait for the canonical period before issuing /budgets/current
      // so dashboard + budget tab agree on the same month.
      final period = await ref.watch(selectedPeriodProvider.future);
      month = period.month;
      year = period.year;
    }
    return ref
        .read(budgetRepositoryProvider)
        .loadBudgetTab(month: month, year: year);
  }

  /// Pull-to-refresh handler. Keeps the previous data visible while a
  /// fresh fetch is in flight (`copyWithPrevious`) so the screen
  /// doesn't flash a spinner on top of the existing layout.
  ///
  /// Pass [month] / [year] to switch the displayed period at the same
  /// time (e.g. right after `POST /budgets` for next month). Both
  /// stick around for subsequent refreshes until the caller resets
  /// them with [resetPeriod].
  Future<void> refresh({int? month, int? year}) async {
    if (month != null) _pinnedMonth = month;
    if (year != null) _pinnedYear = year;
    final prev = state;
    state = const AsyncLoading<BudgetTabData>().copyWithPrevious(prev);
    state = await AsyncValue.guard(_runFetch);
  }

  /// Pin the tab to a specific period without firing a refresh — the
  /// next `build()` (e.g. after `ref.invalidate`) will pick it up.
  void pinPeriod({required int month, required int year}) {
    _pinnedMonth = month;
    _pinnedYear = year;
  }

  /// Forget the pinned period and re-fetch with [selectedPeriodProvider]
  /// as the source of truth again. Useful for a "back to current month"
  /// CTA.
  Future<void> resetPeriod() async {
    _pinnedMonth = null;
    _pinnedYear = null;
    await refresh();
  }

  Future<BudgetTabData> _runFetch() async {
    int? month = _pinnedMonth;
    int? year = _pinnedYear;
    if (month == null || year == null) {
      final period = await ref.read(selectedPeriodProvider.future);
      month = period.month;
      year = period.year;
    }
    return ref
        .read(budgetRepositoryProvider)
        .loadBudgetTab(month: month, year: year);
  }
}
