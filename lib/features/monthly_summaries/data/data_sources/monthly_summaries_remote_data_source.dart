import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/monthly_summary_model.dart';

/// Page of `MonthlySummaryResource` rows from `GET /monthly-summaries`.
class MonthlySummariesPage {
  const MonthlySummariesPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<MonthlySummaryModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

abstract class MonthlySummariesRemoteDataSource {
  /// `GET /monthly-summaries`. The optional [status] filters between
  /// `open` (rolling) and `closed` (finalised) months — `null` returns
  /// the server's default mix. [year] narrows to a single calendar year.
  Future<MonthlySummariesPage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  });

  /// `GET /monthly-summaries/{year}/{month}`.
  Future<MonthlySummaryModel> fetchByYearMonth({
    required int year,
    required int month,
  });

  /// `POST /monthly-summaries/{id}/allocate` — moves part of the
  /// month's `unallocated_remaining` into a single saving goal.
  ///
  /// The new server contract takes one allocation per request:
  /// `{ saving_goal_id, amount, note? }`. Callers that need to split
  /// the surplus across multiple goals should issue the requests
  /// serially (the allocate notifier does this for us).
  Future<MonthlySummaryAllocateResult> allocate({
    required int summaryId,
    required int savingGoalId,
    required double amount,
    String? note,
  });
}

class MonthlySummariesRemoteDataSourceImpl
    implements MonthlySummariesRemoteDataSource {
  MonthlySummariesRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<MonthlySummariesPage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (status != null && status.isNotEmpty) qp['status'] = status;
      if (year != null) qp['year'] = year;
      final res = await _dio.get(
        ApiEndpoints.monthlySummaries,
        queryParameters: qp,
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /monthly-summaries response shape.',
        );
      }
      final raw = body['data'];

      // Spec ships `data: { items: [...], meta: {...} }`. Older
      // deploys ship `data: [...]` with `meta` at the root, or a
      // Laravel paginator (`data: { data: [...], current_page, ... }`).
      // Handle all three transparently so deploys can flip without
      // breaking the client.
      List<Map<String, dynamic>> rows = const [];
      Map<String, dynamic>? meta;
      if (raw is List) {
        rows = _castList(raw);
        if (body['meta'] is Map<String, dynamic>) {
          meta = body['meta'] as Map<String, dynamic>;
        }
      } else if (raw is Map<String, dynamic>) {
        // 1) New canonical shape: `data.items`
        if (raw['items'] is List) {
          rows = _castList(raw['items'] as List);
          if (raw['meta'] is Map<String, dynamic>) {
            meta = raw['meta'] as Map<String, dynamic>;
          } else if (body['meta'] is Map<String, dynamic>) {
            meta = body['meta'] as Map<String, dynamic>;
          } else {
            meta = raw;
          }
        }
        // 2) Legacy paginator: `data.data`
        else if (raw['data'] is List) {
          rows = _castList(raw['data'] as List);
          meta = raw;
        }
      }

      final items = rows.map(MonthlySummaryModel.fromJson).toList();
      return MonthlySummariesPage(
        items: items,
        currentPage: _toInt(meta?['current_page'] ?? page, fallback: page),
        lastPage: _toInt(meta?['last_page'] ?? page, fallback: page),
        total: _toInt(meta?['total'] ?? items.length, fallback: items.length),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<MonthlySummaryModel> fetchByYearMonth({
    required int year,
    required int month,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.monthlySummaryByYearMonth(year, month),
        queryParameters: {
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _noCache(),
      );
      return MonthlySummaryModel.fromJson(_unwrap200(res.data, 'detail'));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<MonthlySummaryAllocateResult> allocate({
    required int summaryId,
    required int savingGoalId,
    required double amount,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'saving_goal_id': savingGoalId,
        'amount': amount,
      };
      if (note != null && note.trim().isNotEmpty) {
        body['note'] = note.trim();
      }
      final res = await _dio.post(
        ApiEndpoints.monthlySummaryAllocate(summaryId),
        data: body,
      );
      return MonthlySummaryAllocateResult.fromJson(
        _unwrap200(res.data, 'allocate'),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Pulls the resource map out of either `{ data: {...} }` or a flat
  /// top-level shape — Laravel resource wrappers are inconsistent
  /// across deploys.
  Map<String, dynamic> _unwrap200(Object? body, String label) {
    if (body is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Unexpected /monthly-summaries $label response shape.',
      );
    }
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  Options _noCache() => Options(
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
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
}

int _toInt(Object? v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

final monthlySummariesRemoteDataSourceProvider =
    Provider<MonthlySummariesRemoteDataSource>((ref) {
  return MonthlySummariesRemoteDataSourceImpl(ref.watch(dioProvider));
});
