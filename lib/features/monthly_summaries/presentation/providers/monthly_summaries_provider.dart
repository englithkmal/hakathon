import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../data/models/monthly_summary_model.dart';
import '../../data/repositories/monthly_summaries_repository.dart';

/// Composite key for [monthlySummaryProvider] — Riverpod families need
/// a value-type key so equality is by content rather than identity.
class MonthlySummaryKey {
  const MonthlySummaryKey({required this.year, required this.month});
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is MonthlySummaryKey &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Cached state for the paginated `GET /monthly-summaries` list.
class MonthlySummariesListState {
  const MonthlySummariesListState({
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
  });

  const MonthlySummariesListState.empty()
      : items = const [],
        isLoadingMore = false,
        hasMore = false;

  final List<MonthlySummaryModel> items;
  final bool isLoadingMore;
  final bool hasMore;

  MonthlySummariesListState copyWith({
    List<MonthlySummaryModel>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      MonthlySummariesListState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
      );
}

class MonthlySummariesListNotifier
    extends AutoDisposeAsyncNotifier<MonthlySummariesListState> {
  int _page = 1;

  @override
  Future<MonthlySummariesListState> build() async {
    // Refetch on locale change so any backend-localised fields reload.
    ref.watch(localeProvider);
    _page = 1;
    final first = await ref
        .read(monthlySummariesRepositoryProvider)
        .loadPage(page: 1);
    return MonthlySummariesListState(
      items: first.items,
      isLoadingMore: false,
      hasMore: first.hasMore,
    );
  }

  Future<void> refresh() async {
    final prev = state;
    state = const AsyncLoading<MonthlySummariesListState>()
        .copyWithPrevious(prev);
    state = await AsyncValue.guard(() async {
      _page = 1;
      final first = await ref
          .read(monthlySummariesRepositoryProvider)
          .loadPage(page: 1);
      return MonthlySummariesListState(
        items: first.items,
        isLoadingMore: false,
        hasMore: first.hasMore,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await ref
          .read(monthlySummariesRepositoryProvider)
          .loadPage(page: _page + 1);
      _page += 1;
      state = AsyncData(
        MonthlySummariesListState(
          items: [...current.items, ...next.items],
          isLoadingMore: false,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Swap a single row after `POST /allocate` returns. No-op when the
  /// row isn't in the cached page yet.
  void replace(MonthlySummaryModel updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    var found = false;
    final next = [
      for (final m in current.items)
        if (m.id == updated.id) ...[
          (() {
            found = true;
            return updated;
          })(),
        ] else
          m,
    ];
    if (!found) return;
    state = AsyncData(current.copyWith(items: next));
  }
}

final monthlySummariesListProvider = AsyncNotifierProvider.autoDispose<
    MonthlySummariesListNotifier, MonthlySummariesListState>(
  MonthlySummariesListNotifier.new,
);

/// `GET /monthly-summaries/{year}/{month}` — single record by period.
/// AutoDispose so navigating off the detail screen drops the cache.
final monthlySummaryProvider = AutoDisposeFutureProviderFamily<
    MonthlySummaryModel, MonthlySummaryKey>((ref, key) {
  return ref.read(monthlySummariesRepositoryProvider).loadByYearMonth(
        year: key.year,
        month: key.month,
      );
});
