import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/categories_repository.dart';

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  ref.watch(localeProvider);
  return ref.read(categoriesRepositoryProvider).loadAll();
});

final expenseCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return cats.where((c) => c.isExpense).toList();
});

final incomeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return cats.where((c) => !c.isExpense).toList();
});
