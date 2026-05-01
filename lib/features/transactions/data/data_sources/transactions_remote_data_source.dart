import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/transaction_model.dart';

class TransactionsPage {
  const TransactionsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<TransactionModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

abstract class TransactionsRemoteDataSource {
  /// Generic pagination call. The optional named filters map directly
  /// to Laravel query params:
  ///   - `categoryId`  → `category_id`
  ///   - `type`        → `type` (`expense` | `income` | `saving`)
  ///   - `from` / `to` → `from` / `to` (`YYYY-MM-DD`)
  Future<TransactionsPage> fetchPage({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  });

  Future<TransactionModel> create(CreateTransactionPayload payload);

  /// `PUT /transactions/{id}` — updates an existing transaction. Only
  /// the fields set on [payload] are sent (Laravel treats unset keys
  /// as `sometimes|`-skipped, so the rest stay as-is).
  ///
  /// Returns the freshly-persisted row so the caller can swap it into
  /// any cached lists.
  Future<TransactionModel> update(int id, UpdateTransactionPayload payload);

  /// `DELETE /transactions/{id}` — removes the transaction. The server
  /// reverses the matching budget rollups + (for `type=saving` rows)
  /// decrements the linked goal's `current_amount`. The caller should
  /// invalidate any cached aggregates after this returns.
  Future<void> delete(int id);
}

class TransactionsRemoteDataSourceImpl implements TransactionsRemoteDataSource {
  TransactionsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<TransactionsPage> fetchPage({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (categoryId != null) params['category_id'] = categoryId;
      if (type != null && type.isNotEmpty) params['type'] = type;
      if (from != null) params['from'] = _ymd(from);
      if (to != null) params['to'] = _ymd(to);

      final res = await _dio.get(
        ApiEndpoints.transactions,
        queryParameters: params,
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );
      final inner = _unwrapData(res.data);
      final list = _extractItems(inner)
          .map(TransactionModel.fromJson)
          .toList();
      final meta = _extractMeta(inner);
      return TransactionsPage(
        items: list,
        currentPage: _toInt(meta['current_page'] ?? page, fallback: page),
        lastPage: _toInt(meta['last_page'] ?? page, fallback: page),
        total: _toInt(meta['total'] ?? list.length, fallback: list.length),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<TransactionModel> create(CreateTransactionPayload payload) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.transactions,
        data: payload.toJson(),
      );
      final inner = _unwrapData(res.data);
      // Some Laravel resources nest the created row under `data`, others
      // return it at the top level — accept both.
      final flat = inner['data'];
      final map = flat is Map<String, dynamic> ? flat : inner;
      return TransactionModel.fromJson(map);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<TransactionModel> update(
    int id,
    UpdateTransactionPayload payload,
  ) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.transactionById(id),
        data: payload.toJson(),
      );
      final inner = _unwrapData(res.data);
      final flat = inner['data'];
      final map = flat is Map<String, dynamic> ? flat : inner;
      return TransactionModel.fromJson(map);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _dio.delete(ApiEndpoints.transactionById(id));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Pulls `items` from the most common Laravel pagination shapes:
  /// `{ data: [...] }`, `{ items: [...] }`, or a bare top-level list.
  List<Map<String, dynamic>> _extractItems(Map<String, dynamic> body) {
    final data = body['data'] ?? body['items'] ?? body;
    if (data is List) return _castList(data);
    if (data is Map<String, dynamic>) {
      final nested = data['data'] ?? data['items'];
      if (nested is List) return _castList(nested);
    }
    return const [];
  }

  Map<String, dynamic> _extractMeta(Map<String, dynamic> body) {
    final meta = body['meta'];
    if (meta is Map<String, dynamic>) return meta;
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  List<Map<String, dynamic>> _castList(List raw) {
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return e.cast<String, dynamic>();
          return const <String, dynamic>{};
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _unwrapData(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const ServerException(
        message: 'Unexpected /transactions response shape.',
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

/// `YYYY-MM-DD` formatter for Laravel-style date filters. We avoid
/// `intl` here so the data source has no UI dependency.
String _ymd(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

final transactionsRemoteDataSourceProvider =
    Provider<TransactionsRemoteDataSource>((ref) {
  return TransactionsRemoteDataSourceImpl(ref.watch(dioProvider));
});
