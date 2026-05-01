import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/selected_period.dart';

/// Speaks to `GET /period`.
///
/// The endpoint returns the canonical period the rest of the app should
/// align to (`Dashboard`, `Budgets/current`, `Insights`, `Monthly
/// Summaries`). The client should call this once on cold-start and reuse
/// the resolved `month`/`year` everywhere — never compute the period
/// locally.
abstract class PeriodRemoteDataSource {
  /// Fetches the active period.
  ///
  /// All three params are mutually exclusive — supplying [month]+[year]
  /// or [periodStart] makes the response carry `source: explicit` /
  /// `source: period_start_param`. Without any of them the server picks
  /// the user's latest active budget month, then falls back to the
  /// server's current month.
  Future<SelectedPeriod> fetchPeriod({
    int? month,
    int? year,
    String? periodStart,
  });
}

class PeriodRemoteDataSourceImpl implements PeriodRemoteDataSource {
  PeriodRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<SelectedPeriod> fetchPeriod({
    int? month,
    int? year,
    String? periodStart,
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (month != null) qp['month'] = month;
      if (year != null) qp['year'] = year;
      if (periodStart != null && periodStart.isNotEmpty) {
        qp['period_start'] = periodStart;
      }
      // Cache-bust so a freshly-created budget shows up right away on
      // the next /period call (the server's "latest_budget" picker
      // reads from the budgets table, not a snapshot).
      qp['_t'] = DateTime.now().millisecondsSinceEpoch;

      final res = await _dio.get(
        ApiEndpoints.period,
        queryParameters: qp,
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /period response shape.',
        );
      }
      // Spec: `{ success, data: { period: { ... } } }`.
      // Tolerate Laravel returning `data` as the period directly, or
      // bypassing the envelope entirely when the resource isn't
      // wrapped on the server side.
      final data = body['data'];
      Map<String, dynamic>? periodMap;
      if (data is Map<String, dynamic>) {
        final inner = data['period'];
        if (inner is Map<String, dynamic>) {
          periodMap = inner;
        } else {
          periodMap = data;
        }
      } else {
        final inner = body['period'];
        if (inner is Map<String, dynamic>) periodMap = inner;
      }
      if (periodMap == null) {
        throw const ServerException(
          message: 'Unexpected /period response: no period object.',
        );
      }
      return SelectedPeriod.fromJson(periodMap);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }
}

final periodRemoteDataSourceProvider = Provider<PeriodRemoteDataSource>((ref) {
  return PeriodRemoteDataSourceImpl(ref.watch(dioProvider));
});
