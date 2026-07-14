import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/home_remote_data_source.dart';

class HomeRepository {
  HomeRepository(this._remote);

  final HomeRemoteDataSource _remote;

  /// Loads the home dashboard for the requested period. Pass [month] /
  /// [year] from `selectedPeriodProvider` so the server doesn't have to
  /// re-resolve which month to render — see the spec rule "pass the
  /// same month/year everywhere".
  Future<HomeShellData> loadHome({int? month, int? year}) =>
      _remote.fetchHomeShell(month: month, year: year);
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(homeRemoteDataSourceProvider));
});
