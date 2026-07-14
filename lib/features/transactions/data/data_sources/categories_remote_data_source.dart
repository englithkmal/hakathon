import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/category_model.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<CategoryModel>> fetchAll();
}

class CategoriesRemoteDataSourceImpl implements CategoriesRemoteDataSource {
  CategoriesRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<CategoryModel>> fetchAll() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      // الفئات الافتراضية (is_default = true) + فئات المستخدم الخاصة
      final query = _supabase
          .from('categories')
          .select()
          .order('sort_order');

      final data = await query as List;
      return data
          .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
          .where((c) =>
              c.isDefault ||
              userId == null ||
              true) // RLS تتولى الفلترة فعلياً
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw UnknownException(message: e.toString());
    }
  }
}

final categoriesRemoteDataSourceProvider =
    Provider<CategoriesRemoteDataSource>((ref) {
  return CategoriesRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
