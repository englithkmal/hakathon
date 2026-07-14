import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../data/data_sources/budget_remote_data_source.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';

/// Cached state for the paginated `GET /budgets` list. Mirrors the
/// pattern used by `monthlySummariesListProvider` so the screen looks
/// and behaves consistently across "history" surfaces.
class BudgetsListState {
  const BudgetsListState({
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
  });

  const BudgetsListState.empty()
      : items = const [],
        isLoadingMore = false,
        hasMore = false;

  final List<BudgetModel> items;

  /// True only while a `loadMore` request is mid-flight. The list
  /// keeps rendering existing rows underneath the spinner so the user
  /// never sees a blank screen.
  final bool isLoadingMore;
  final bool hasMore;

  BudgetsListState copyWith({
    List<BudgetModel>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      BudgetsListState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
      );
}

/// Backs the "All budgets" history screen. Auto-disposed because the
/// list is only relevant while the screen is mounted — when the user
/// pops back to the budget tab we'd rather refetch than show stale
/// rows that may have just been edited via the tab actions.
class BudgetsListNotifier extends AutoDisposeAsyncNotifier<BudgetsListState> {
  int _page = 1;

  @override
  Future<BudgetsListState> build() async {
    // Refetch on locale change in case any backend-localised label
    // changes (e.g. status names ever start being server-localised).
    ref.watch(localeProvider);
    _page = 1;
    final first = await ref.read(budgetRepositoryProvider).loadAll(page: 1);
    return BudgetsListState(
      items: first.items,
      isLoadingMore: false,
      hasMore: first.hasMore,
    );
  }

  /// Pull-to-refresh. Resets pagination back to page 1 so the user
  /// always sees the freshest "head" rows after creating/editing a
  /// budget elsewhere in the app.
  Future<void> refresh() async {
    final prev = state;
    state = const AsyncLoading<BudgetsListState>().copyWithPrevious(prev);
    state = await AsyncValue.guard(() async {
      _page = 1;
      final first = await ref.read(budgetRepositoryProvider).loadAll(page: 1);
      return BudgetsListState(
        items: first.items,
        isLoadingMore: false,
        hasMore: first.hasMore,
      );
    });
  }

  /// Infinite-scroll loader. No-op when nothing more is available or
  /// when a previous `loadMore` is still in-flight (debounce).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(budgetRepositoryProvider)
          .loadAll(page: _page + 1);
      _page += 1;
      state = AsyncData(
        BudgetsListState(
          items: [...current.items, ...next.items],
          isLoadingMore: false,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {
      // Surface the failure as "tried & failed" so the spinner clears
      // but the existing rows stay visible — the user can retry by
      // scrolling again or pulling to refresh.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final budgetsListProvider = AsyncNotifierProvider.autoDispose<
    BudgetsListNotifier, BudgetsListState>(
  BudgetsListNotifier.new,
);

/// Convenience for screens that only want a single budget by id —
/// hits `GET /budgets/{id}` via [BudgetRepository] (uses the existing
/// detail endpoint indirectly through `loadAll` filters when needed).
///
/// Currently unused by the list screen itself but kept here as the
/// natural extension point for a future per-budget read-only detail
/// view (e.g. tapping a closed/historical budget).
final budgetsPageProvider = AutoDisposeFutureProviderFamily<BudgetsPage, int>(
  (ref, page) => ref.read(budgetRepositoryProvider).loadAll(page: page),
);
