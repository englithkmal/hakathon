import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/expense_analysis_model.dart';

abstract class InsightsRemoteDataSource {
  /// `GET /insights/expense-analysis`. Targets a calendar period via
  /// either [year] / [month] (preferred — matches the rest of the app)
  /// or [periodStart] (`YYYY-MM-DD` somewhere inside the target month).
  /// With no parameters the server picks the active period — same
  /// behaviour as the dashboard.
  Future<ExpenseAnalysisModel> fetchExpenseAnalysis({
    int? month,
    int? year,
    String? periodStart,
  });
}

class InsightsRemoteDataSourceImpl implements InsightsRemoteDataSource {
  InsightsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ExpenseAnalysisModel> fetchExpenseAnalysis({
    int? month,
    int? year,
    String? periodStart,
  }) async {
    try {
      final qp = <String, dynamic>{
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (periodStart != null && periodStart.isNotEmpty) {
        qp['period_start'] = periodStart;
      }
      if (month != null) qp['month'] = month;
      if (year != null) qp['year'] = year;
      final res = await _dio.get(
        ApiEndpoints.expenseAnalysis,
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
          message: 'Unexpected /insights/expense-analysis response shape.',
        );
      }
      // The model is already lenient about `data` vs flat top-level
      // shape — pass the whole body through so it can pull `meta.period`
      // alongside `data.*` if both live at the root.
      return ExpenseAnalysisModel.fromJson(body);
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

final insightsRemoteDataSourceProvider =
    Provider<InsightsRemoteDataSource>((ref) {
  return InsightsRemoteDataSourceImpl(ref.watch(dioProvider));
});
