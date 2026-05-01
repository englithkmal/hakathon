import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/monthly_summaries_remote_data_source.dart';
import '../models/monthly_summary_model.dart';

/// Thin pass-through over [MonthlySummariesRemoteDataSource]. Lives so
/// presentation can stay Dio-free and we can layer caching here later
/// without touching providers/screens.
class MonthlySummariesRepository {
  MonthlySummariesRepository(this._remote);

  final MonthlySummariesRemoteDataSource _remote;

  Future<MonthlySummariesPage> loadPage({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) =>
      _remote.fetchPage(
        page: page,
        perPage: perPage,
        status: status,
        year: year,
      );

  Future<MonthlySummaryModel> loadByYearMonth({
    required int year,
    required int month,
  }) =>
      _remote.fetchByYearMonth(year: year, month: month);

  /// Posts a single allocation. Multi-row sheets call this multiple
  /// times in sequence — see [AllocateMonthlySurplusNotifier.submit].
  Future<MonthlySummaryAllocateResult> allocate({
    required int summaryId,
    required int savingGoalId,
    required double amount,
    String? note,
  }) =>
      _remote.allocate(
        summaryId: summaryId,
        savingGoalId: savingGoalId,
        amount: amount,
        note: note,
      );
}

final monthlySummariesRepositoryProvider =
    Provider<MonthlySummariesRepository>((ref) {
  return MonthlySummariesRepository(
    ref.watch(monthlySummariesRemoteDataSourceProvider),
  );
});
