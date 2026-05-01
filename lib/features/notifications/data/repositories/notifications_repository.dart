import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/notifications_remote_data_source.dart';
import '../models/notification_model.dart';

/// Thin abstraction over [NotificationsRemoteDataSource]. Lets the
/// presentation layer talk to a stable interface so we can swap in a fake
/// implementation in tests without dragging in Dio.
class NotificationsRepository {
  NotificationsRepository(this._remote);

  final NotificationsRemoteDataSource _remote;

  Future<NotificationsPage> fetchPage({
    int? cursor,
    int limit = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) {
    return _remote.fetchPage(
      cursor: cursor,
      limit: limit,
      unreadOnly: unreadOnly,
      type: type,
    );
  }

  Future<int> fetchUnreadCount() => _remote.fetchUnreadCount();

  Future<MarkReadResult> markRead(int id) => _remote.markRead(id);

  Future<MarkAllReadResult> markAllRead() => _remote.markAllRead();

  Future<void> delete(int id) => _remote.delete(id);
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    ref.watch(notificationsRemoteDataSourceProvider),
  );
});
