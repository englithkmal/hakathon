import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifications_repository.dart';

/// In-memory snapshot of the notifications screen.
class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
    required this.isLoadingMore,
  });

  final List<NotificationModel> items;
  final int? nextCursor;
  final int unreadCount;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  NotificationsState copyWith({
    List<NotificationModel>? items,
    int? nextCursor,
    int? unreadCount,
    bool? isLoadingMore,
    bool clearCursor = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      unreadCount: unreadCount ?? this.unreadCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Drives the notifications screen — first-page load on build, pull-to-
/// refresh, infinite scroll, and optimistic mark-as-read.
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  static const int _pageSize = 20;

  late NotificationsRepository _repo;

  @override
  Future<NotificationsState> build() async {
    _repo = ref.watch(notificationsRepositoryProvider);
    // Re-fetch when the language flips so localised fields refresh.
    ref.watch(localeProvider);
    final page = await _repo.fetchPage(limit: _pageSize);
    return NotificationsState(
      items: page.items,
      nextCursor: page.nextCursor,
      unreadCount: page.unreadCount,
      isLoadingMore: false,
    );
  }

  /// Pull-to-refresh. Keeps the previous list visible while loading.
  Future<void> refresh() async {
    final prev = state.valueOrNull;
    state = AsyncLoading<NotificationsState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final page = await _repo.fetchPage(limit: _pageSize);
      return NotificationsState(
        items: page.items,
        nextCursor: page.nextCursor,
        unreadCount: page.unreadCount,
        isLoadingMore: false,
      );
    });
    // Surface a synthetic recovery so the UI never gets stuck on an error
    // state if the user pulls again successfully.
    state.whenOrNull(
      error: (_, __) {
        if (prev != null) state = AsyncData(prev);
      },
    );
  }

  /// Append the next slice. No-ops when there's nothing left or another
  /// load is already in flight.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repo.fetchPage(
        cursor: current.nextCursor,
        limit: _pageSize,
      );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          unreadCount: page.unreadCount,
          isLoadingMore: false,
          clearCursor: page.nextCursor == null,
        ),
      );
    } catch (e) {
      // Don't blow away the existing list on a load-more failure.
      debugPrint('[Notifications] loadMore failed: $e');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Optimistically mark a single notification as read, rolling back on
  /// failure. Mirrors the server change to `unread_count` so the badge
  /// stays in sync without an extra round-trip.
  Future<void> markRead(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.items.indexWhere((n) => n.id == id);
    if (idx == -1 || current.items[idx].isRead) return;

    final original = current.items[idx];
    final optimistic = original.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    final newItems = [...current.items]..[idx] = optimistic;
    state = AsyncData(
      current.copyWith(
        items: newItems,
        unreadCount: (current.unreadCount - 1).clamp(0, 1 << 30),
      ),
    );

    try {
      await _repo.markRead(id);
    } catch (e) {
      debugPrint('[Notifications] markRead failed: $e');
      final latest = state.valueOrNull ?? current;
      final rollbackIdx = latest.items.indexWhere((n) => n.id == id);
      if (rollbackIdx == -1) return;
      final rolledBack = [...latest.items]..[rollbackIdx] = original;
      state = AsyncData(
        latest.copyWith(
          items: rolledBack,
          unreadCount: latest.unreadCount + 1,
        ),
      );
    }
  }

  /// Mark every notification as read. Optimistically updates the entire
  /// list; rolls back on failure.
  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || current.unreadCount == 0) return;
    final originalItems = current.items;
    final readNow = DateTime.now();
    final optimistic = current.items
        .map((n) => n.isRead ? n : n.copyWith(isRead: true, readAt: readNow))
        .toList();
    state = AsyncData(
      current.copyWith(items: optimistic, unreadCount: 0),
    );

    try {
      await _repo.markAllRead();
    } catch (e) {
      debugPrint('[Notifications] markAllRead failed: $e');
      state = AsyncData(
        current.copyWith(
          items: originalItems,
          unreadCount: current.unreadCount,
        ),
      );
    }
  }

  /// Removes a notification optimistically. The screen also calls this
  /// from a swipe-to-dismiss in the future.
  Future<void> delete(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.items.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final original = current.items[idx];
    final newItems = [...current.items]..removeAt(idx);
    final wasUnread = !original.isRead;
    state = AsyncData(
      current.copyWith(
        items: newItems,
        unreadCount: wasUnread
            ? (current.unreadCount - 1).clamp(0, 1 << 30)
            : current.unreadCount,
      ),
    );

    try {
      await _repo.delete(id);
    } catch (e) {
      debugPrint('[Notifications] delete failed: $e');
      final latest = state.valueOrNull ?? current;
      final restored = [...latest.items, original]..sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
      state = AsyncData(
        latest.copyWith(
          items: restored,
          unreadCount: wasUnread
              ? latest.unreadCount + 1
              : latest.unreadCount,
        ),
      );
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

/// Slim provider exposing just the unread count for the AppBar bell
/// badge. Reuses the inner [NotificationsNotifier] state so it doesn't
/// double up on network calls — but falls back to its own
/// `/unread-count` request when the screen hasn't been opened yet.
class UnreadCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    // Mirror the list state when it's already loaded.
    final list = ref.watch(notificationsProvider);
    final inline = list.valueOrNull;
    if (inline != null) return inline.unreadCount;

    // Otherwise hit the cheap dedicated endpoint.
    ref.watch(localeProvider);
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.fetchUnreadCount();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<int>();
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).fetchUnreadCount(),
    );
  }
}

final unreadCountProvider =
    AsyncNotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
