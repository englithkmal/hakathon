import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/categories_remote_data_source.dart';
import '../models/category_model.dart';

class CategoriesRepository {
  CategoriesRepository(this._remote);

  final CategoriesRemoteDataSource _remote;

  Future<List<CategoryModel>> loadAll() => _remote.fetchAll();
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(categoriesRemoteDataSourceProvider));
});
