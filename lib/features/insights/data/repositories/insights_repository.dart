import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/insights_remote_data_source.dart';
import '../models/expense_analysis_model.dart';

/// Thin wrapper around [InsightsRemoteDataSource]. Lives so the
/// presentation layer never depends on Dio types directly and we can
/// later layer caching / offline support without touching providers.
class InsightsRepository {
  InsightsRepository(this._remote);

  final InsightsRemoteDataSource _remote;

  Future<ExpenseAnalysisModel> loadExpenseAnalysis({
    int? month,
    int? year,
    String? periodStart,
  }) =>
      _remote.fetchExpenseAnalysis(
        month: month,
        year: year,
        periodStart: periodStart,
      );
}

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.watch(insightsRemoteDataSourceProvider));
});
