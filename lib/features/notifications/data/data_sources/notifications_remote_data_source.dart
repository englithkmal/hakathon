import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/notification_model.dart';

class MarkReadResult {
  const MarkReadResult({required this.id, required this.isRead, required this.readAt});
  final int id;
  final bool isRead;
  final DateTime? readAt;
}

class MarkAllReadResult {
  const MarkAllReadResult({required this.markedCount, required this.unreadCount});
  final int markedCount;
  final int unreadCount;
}

abstract class NotificationsRemoteDataSource {
  Future<NotificationsPage> fetchPage({
    int? cursor,
    int limit = 20,
    bool unreadOnly = false,
    NotificationType? type,
  });
  Future<int> fetchUnreadCount();
  Future<MarkReadResult> markRead(int id);
  Future<MarkAllReadResult> markAllRead();
  Future<void> delete(int id);
}

/// يتوقع جدول `notifications` بالأعمدة:
/// id, user_id, type, severity, title, title_ar, title_en,
/// message, message_ar, message_en, icon, is_read, read_at,
/// created_at, deeplink, payload (jsonb)
class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  NotificationsRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const UnauthorizedException(message: 'غير مسجل الدخول', statusCode: 401);
    }
    return id;
  }

  @override
  Future<NotificationsPage> fetchPage({
    int? cursor,
    int limit = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    try {
      dynamic query = _supabase
          .from('notifications')
          .select()
          .eq('user_id', _userId);

      if (unreadOnly) {
        query = query.eq('is_read', false) as dynamic;
      }
      if (type != null && type.apiValue.isNotEmpty) {
        query = query.eq('type', type.apiValue) as dynamic;
      }
      if (cursor != null) {
        query = query.lt('id', cursor) as dynamic;
      }

      final rows = await query
          .order('id', ascending: false)
          .limit(limit) as List;

      final unreadRes = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', _userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      final unreadCount = unreadRes.count;

      final items = rows.cast<Map<String, dynamic>>();
      final nextCursor = items.length == limit && items.isNotEmpty
          ? _toInt(items.last['id'])
          : null;

      return NotificationsPage.fromJson({
        'data': {
          'items': items,
          'next_cursor': nextCursor,
          'unread_count': unreadCount,
        },
      });
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<int> fetchUnreadCount() async {
    try {
      final res = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', _userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<MarkReadResult> markRead(int id) async {
    try {
      final now = DateTime.now().toIso8601String();
      final row = await _supabase
          .from('notifications')
          .update({'is_read': true, 'read_at': now})
          .eq('id', id)
          .select()
          .single();
      return MarkReadResult(
        id: _toInt(row['id'], fallback: id),
        isRead: row['is_read'] == true,
        readAt: DateTime.tryParse((row['read_at'] ?? '').toString()),
      );
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<MarkAllReadResult> markAllRead() async {
    try {
      final now = DateTime.now().toIso8601String();
      final rows = await _supabase
          .from('notifications')
          .update({'is_read': true, 'read_at': now})
          .eq('user_id', _userId)
          .eq('is_read', false)
          .select('id') as List;

      return MarkAllReadResult(markedCount: rows.length, unreadCount: 0);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }
}

int _toInt(Object? v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
