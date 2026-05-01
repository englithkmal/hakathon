import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../models/category_model.dart';

abstract class CategoriesRemoteDataSource {
  Future<List<CategoryModel>> fetchAll();
}

class CategoriesRemoteDataSourceImpl implements CategoriesRemoteDataSource {
  CategoriesRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<CategoryModel>> fetchAll() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.categories,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
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
          message: 'Unexpected /categories response shape.',
        );
      }
      final raw = body['data'] ?? body['items'] ?? body;
      final list = raw is List ? raw : const [];
      return list
          .whereType<Map>()
          .map((e) => CategoryModel.fromJson(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is AppException) throw inner;
      throw mapDioException(e);
    }
  }
}

final categoriesRemoteDataSourceProvider =
    Provider<CategoriesRemoteDataSource>((ref) {
  return CategoriesRemoteDataSourceImpl(ref.watch(dioProvider));
});
