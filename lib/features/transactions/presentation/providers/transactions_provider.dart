import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transactions_repository.dart';

/// Loaded page of transactions plus a cached "is anything happening right
/// now?" flag for the create button.
class TransactionsState {
  const TransactionsState({
    required this.items,
    required this.isLoadingMore,
    required this.hasMore,
  });

  const TransactionsState.empty()
      : items = const [],
        isLoadingMore = false,
        hasMore = false;

  final List<TransactionModel> items;
  final bool isLoadingMore;
  final bool hasMore;

  TransactionsState copyWith({
    List<TransactionModel>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) =>
      TransactionsState(
        items: items ?? this.items,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
      );
}

class TransactionsNotifier
    extends AutoDisposeAsyncNotifier<TransactionsState> {
  int _page = 1;

  @override
  Future<TransactionsState> build() async {
    // Refetch on locale change so backend-localised fields update.
    ref.watch(localeProvider);
    _page = 1;
    final first = await ref.read(transactionsRepositoryProvider).loadPage(
          page: 1,
        );
    return TransactionsState(
      items: first.items,
      isLoadingMore: false,
      hasMore: first.hasMore,
    );
  }

  Future<void> refresh() async {
    final prev = state;
    state = const AsyncLoading<TransactionsState>().copyWithPrevious(prev);
    state = await AsyncValue.guard(() async {
      _page = 1;
      final first = await ref
          .read(transactionsRepositoryProvider)
          .loadPage(page: 1);
      return TransactionsState(
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
          .read(transactionsRepositoryProvider)
          .loadPage(page: _page + 1);
      _page += 1;
      state = AsyncData(
        TransactionsState(
          items: [...current.items, ...next.items],
          isLoadingMore: false,
          hasMore: next.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Optimistically prepend a freshly-created transaction.
  void prepend(TransactionModel tx) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(items: [tx, ...current.items]),
    );
  }

  /// Swap a single transaction in-place after `PUT /transactions/{id}`
  /// returns. No-op if the row isn't currently in the cached page (e.g.
  /// the user paged past it before editing).
  void replace(TransactionModel tx) {
    final current = state.valueOrNull;
    if (current == null) return;
    var found = false;
    final next = [
      for (final existing in current.items)
        if (existing.id == tx.id) ...[
          (() {
            found = true;
            return tx;
          })(),
        ] else
          existing,
    ];
    if (!found) return;
    state = AsyncData(current.copyWith(items: next));
  }

  /// Drop a transaction from the cached page after a successful
  /// `DELETE /transactions/{id}`. Caller is still responsible for
  /// invalidating dashboard / budget aggregates.
  void removeById(int id) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = current.items.where((t) => t.id != id).toList();
    if (next.length == current.items.length) return;
    state = AsyncData(current.copyWith(items: next));
  }
}

final transactionsProvider = AsyncNotifierProvider.autoDispose<
    TransactionsNotifier, TransactionsState>(TransactionsNotifier.new);
