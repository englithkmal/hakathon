import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../../../period/data/models/selected_period.dart';
import '../models/dashboard_model.dart';

/// Combined payload for the home shell.
///
/// `serverPeriod` is the period the server actually returned in the
/// dashboard payload — it may differ from the `month`/`year` we asked
/// for (e.g. the request was made without query params and the server
/// resolved `latest_budget`). The UI uses it to render the
/// "showing latest budget month" banner without making an extra round
/// trip to `GET /period`.
class HomeShellData {
  const HomeShellData({
    required this.dashboard,
    required this.serverPeriod,
    this.balanceChangePercent,
  });

  final DashboardModel dashboard;
  final SelectedPeriod serverPeriod;
  final double? balanceChangePercent;
}

abstract class HomeRemoteDataSource {
  /// Fetches the dashboard for the requested period. When [month] /
  /// [year] are `null` the server picks (latest active budget →
  /// server-now) and we surface its choice via `HomeShellData.serverPeriod`.
  Future<HomeShellData> fetchHomeShell({int? month, int? year});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  HomeRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<HomeShellData> fetchHomeShell({int? month, int? year}) async {
    try {
      // `_t` busts any HTTP-layer cache between us and Laravel; `no-cache`
      // headers cover proxies and dev overlays that would otherwise serve
      // a stale `/dashboard` body when the user pulls to refresh.
      final dashQp = <String, dynamic>{
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (month != null) dashQp['month'] = month;
      if (year != null) dashQp['year'] = year;

      final dashRes = await _dio.get(
        ApiEndpoints.dashboard,
        queryParameters: dashQp,
        options: Options(
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ),
      );
      final dashMap = _unwrapData(dashRes.data, endpoint: 'dashboard');
      final dashboard = DashboardModel.fromJson(dashMap);

      // Spec: the dashboard echoes the resolved period in `data.period`
      // (with `source`, `budget_id`). Fall back to the device clock when
      // an older payload omits it so the banner logic stays defensive.
      final periodMap = dashMap['period'];
      final serverPeriod = periodMap is Map<String, dynamic>
          ? SelectedPeriod.fromJson(periodMap)
          : SelectedPeriod.localFallback();

      double? mom;
      try {
        // Request 6 months so the chart has enough history for the
        // bar-chart insights (the spec example uses 6 months). We
        // still use the first two for the MoM headline.
        final reportRes = await _dio.get(
          ApiEndpoints.monthlyReport,
          queryParameters: {
            'months': 6,
            '_t': DateTime.now().millisecondsSinceEpoch,
          },
          options: Options(
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          ),
        );
        final reportData =
            _unwrapData(reportRes.data, endpoint: 'monthly-report');
        // The endpoint can either return `data: [...]` (the spec shape)
        // or the older `data: { months: [...] }` envelope — handle both.
        final months = (reportData['months'] is List)
            ? reportData['months'] as List
            : (reportRes.data is Map &&
                    (reportRes.data as Map)['data'] is List)
                ? (reportRes.data as Map)['data'] as List
                : const <dynamic>[];
        if (months.length >= 2) {
          final m0 = months[0] as Map<String, dynamic>;
          final m1 = months[1] as Map<String, dynamic>;
          final b0 = _toDouble(m0['balance']);
          final b1 = _toDouble(m1['balance']);
          if (b1.abs() >= 0.01) {
            mom = ((b0 - b1) / b1) * 100;
          }
        }
      } catch (_) {
        mom = null;
      }

      return HomeShellData(
        dashboard: dashboard,
        serverPeriod: serverPeriod,
        balanceChangePercent: mom,
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Map<String, dynamic> _unwrapData(
    Object? body, {
    required String endpoint,
  }) {
    if (body is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Unexpected $endpoint response shape.',
      );
    }
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((ref) {
  return HomeRemoteDataSourceImpl(ref.watch(dioProvider));
});
