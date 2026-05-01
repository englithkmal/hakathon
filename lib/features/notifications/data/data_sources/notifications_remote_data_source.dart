import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/notification_model.dart';

/// Result of marking a single notification as read.
class MarkReadResult {
  const MarkReadResult({
    required this.id,
    required this.isRead,
    required this.readAt,
  });

  final int id;
  final bool isRead;
  final DateTime? readAt;
}

/// Result of bulk marking notifications as read.
class MarkAllReadResult {
  const MarkAllReadResult({
    required this.markedCount,
    required this.unreadCount,
  });

  final int markedCount;
  final int unreadCount;
}

abstract class NotificationsRemoteDataSource {
  /// `GET /notifications` — cursor-based listing. Pass `cursor` from a
  /// previous page's `nextCursor` to fetch the next slice.
  Future<NotificationsPage> fetchPage({
    int? cursor,
    int limit = 20,
    bool unreadOnly = false,
    NotificationType? type,
  });

  /// `GET /notifications/unread-count` — cheap call for the AppBar badge.
  Future<int> fetchUnreadCount();

  /// `POST /notifications/{id}/read` — single mark-as-read.
  Future<MarkReadResult> markRead(int id);

  /// `POST /notifications/read-all` — bulk mark-as-read.
  Future<MarkAllReadResult> markAllRead();

  /// `DELETE /notifications/{id}` — permanent delete (no soft-delete on
  /// the backend per spec).
  Future<void> delete(int id);
}

class NotificationsRemoteDataSourceImpl implements NotificationsRemoteDataSource {
  NotificationsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<NotificationsPage> fetchPage({
    int? cursor,
    int limit = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.notifications,
        queryParameters: <String, dynamic>{
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
          if (unreadOnly) 'unread_only': true,
          if (type != null && type.apiValue.isNotEmpty) 'type': type.apiValue,
          // Cache-bust so pulled-to-refresh always hits origin.
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );
      return NotificationsPage.fromJson(_unwrapBody(res.data));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<int> fetchUnreadCount() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.notificationsUnreadCount,
        queryParameters: <String, dynamic>{
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );
      final body = _unwrapBody(res.data);
      final data = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;
      return _toInt(data['unread_count']);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<MarkReadResult> markRead(int id) async {
    // Spec rev 2 introduces `PATCH /alerts/{id}/read` as the canonical
    // mark-read endpoint. We try it first and fall back to the legacy
    // `POST /notifications/{id}/read` only when the new endpoint
    // returns 404/405 — keeps older deploys working without a flag.
    Response<dynamic> res;
    try {
      res = await _dio.patch(ApiEndpoints.alertRead(id));
    } on DioException catch (e) {
      if (_isMethodMissing(e)) {
        try {
          res = await _dio.post(ApiEndpoints.notificationRead(id));
        } on DioException catch (e2) {
          throw _unwrap(e2);
        }
      } else {
        throw _unwrap(e);
      }
    }
    final body = _unwrapBody(res.data);
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;
    return MarkReadResult(
      id: _toInt(data['id'], fallback: id),
      isRead: data['is_read'] == true,
      readAt: _toDate(data['read_at']),
    );
  }

  @override
  Future<MarkAllReadResult> markAllRead() async {
    Response<dynamic> res;
    try {
      // The spec keeps `POST /alerts/read-all` for the bulk path —
      // PATCH is reserved for the per-row write. We still fall back
      // to `/notifications/read-all` if the new endpoint isn't
      // wired up yet on the deploy we're hitting.
      res = await _dio.post(ApiEndpoints.alertsReadAll);
    } on DioException catch (e) {
      if (_isMethodMissing(e)) {
        try {
          res = await _dio.post(ApiEndpoints.notificationsReadAll);
        } on DioException catch (e2) {
          throw _unwrap(e2);
        }
      } else {
        throw _unwrap(e);
      }
    }
    final body = _unwrapBody(res.data);
    final data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;
    return MarkAllReadResult(
      markedCount: _toInt(data['marked_count']),
      unreadCount: _toInt(data['unread_count']),
    );
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _dio.delete(ApiEndpoints.alertById(id));
    } on DioException catch (e) {
      if (_isMethodMissing(e)) {
        try {
          await _dio.delete(ApiEndpoints.notificationById(id));
        } on DioException catch (e2) {
          throw _unwrap(e2);
        }
      } else {
        throw _unwrap(e);
      }
    }
  }

  /// Returns `true` for the typical "endpoint not deployed yet"
  /// signals — 404 (route not found) and 405 (method not allowed).
  /// We use this to gate the legacy `/notifications` fallback so
  /// we don't accidentally swallow legitimate 4xx errors (validation,
  /// auth, ownership, …).
  bool _isMethodMissing(DioException e) {
    final code = e.response?.statusCode;
    return code == 404 || code == 405;
  }

  Map<String, dynamic> _unwrapBody(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const ServerException(
        message: 'Unexpected /notifications response shape.',
      );
    }
    return body;
  }

  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

DateTime? _toDate(Object? value) {
  if (value == null) return null;
  final raw = value.toString();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  return NotificationsRemoteDataSourceImpl(ref.watch(dioProvider));
});
