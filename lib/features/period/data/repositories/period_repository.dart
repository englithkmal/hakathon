import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/period_remote_data_source.dart';
import '../models/selected_period.dart';

/// Thin wrapper around [PeriodRemoteDataSource] so the presentation layer
/// stays free of Dio types.
class PeriodRepository {
  PeriodRepository(this._remote);

  final PeriodRemoteDataSource _remote;

  /// Fetches the active period from the backend. See
  /// [PeriodRemoteDataSource.fetchPeriod] for query semantics.
  Future<SelectedPeriod> fetch({
    int? month,
    int? year,
    String? periodStart,
  }) =>
      _remote.fetchPeriod(
        month: month,
        year: year,
        periodStart: periodStart,
      );
}

final periodRepositoryProvider = Provider<PeriodRepository>((ref) {
  return PeriodRepository(ref.watch(periodRemoteDataSourceProvider));
});
