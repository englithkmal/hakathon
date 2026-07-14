import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../models/transaction_model.dart';

class TransactionsPage {
  const TransactionsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<TransactionModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

abstract class TransactionsRemoteDataSource {
  Future<TransactionsPage> fetchPage({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  });

  Future<TransactionModel> create(CreateTransactionPayload payload);
  Future<TransactionModel> update(int id, UpdateTransactionPayload payload);
  Future<void> delete(int id);
}

class TransactionsRemoteDataSourceImpl
    implements TransactionsRemoteDataSource {
  TransactionsRemoteDataSourceImpl(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<TransactionsPage> fetchPage({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthorizedException(message: 'غير مسجل', statusCode: 401);

      final from0 = (page - 1) * perPage;
      final to0 = from0 + perPage - 1;

      dynamic query = _supabase
          .from('transactions')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('transaction_date', ascending: false)
          .range(from0, to0);

      if (categoryId != null) {
        query = query.eq('category_id', categoryId) as dynamic;
      }
      if (type != null && type.isNotEmpty) {
        query = query.eq('type', type) as dynamic;
      }
      if (from != null) {
        query = query.gte('transaction_date', _ymd(from)) as dynamic;
      }
      if (to != null) {
        query = query.lte('transaction_date', _ymd(to)) as dynamic;
      }

      final data = await query as List;

      // عدد الكل (count) — استعلام منفصل بدون range
      dynamic countQuery = _supabase
          .from('transactions')
          .select('id')
          .eq('user_id', userId);

      if (categoryId != null) countQuery = countQuery.eq('category_id', categoryId) as dynamic;
      if (type != null && type.isNotEmpty) countQuery = countQuery.eq('type', type) as dynamic;
      if (from != null) countQuery = countQuery.gte('transaction_date', _ymd(from)) as dynamic;
      if (to != null) countQuery = countQuery.lte('transaction_date', _ymd(to)) as dynamic;

      final countRes = await countQuery.count(CountOption.exact);
      final total = countRes.count ?? data.length;
      final lastPage = (total / perPage).ceil().clamp(1, 999999);

      final items = data
          .map((e) => TransactionModel.fromJson(_flattenCategory(e)))
          .toList();

      return TransactionsPage(
        items: items,
        currentPage: page,
        lastPage: lastPage,
        total: total,
      );
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<TransactionModel> create(CreateTransactionPayload payload) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw const UnauthorizedException(message: 'غير مسجل', statusCode: 401);

      final body = {
        ...payload.toJson(),
        'user_id': userId,
      };

      final res = await _supabase
          .from('transactions')
          .insert(body)
          .select('*, categories(*)')
          .single();

      return TransactionModel.fromJson(_flattenCategory(res));
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<TransactionModel> update(
      int id, UpdateTransactionPayload payload) async {
    try {
      final res = await _supabase
          .from('transactions')
          .update(payload.toJson())
          .eq('id', id)
          .select('*, categories(*)')
          .single();

      return TransactionModel.fromJson(_flattenCategory(res));
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _supabase.from('transactions').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapPostgrest(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw UnknownException(message: e.toString());
    }
  }

  /// يحوّل `{ ..., categories: { id, name, ... } }` إلى
  /// `{ ..., category: { id, name, ... } }` بحيث يتوافق مع TransactionModel
  Map<String, dynamic> _flattenCategory(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    if (map.containsKey('categories')) {
      map['category'] = map.remove('categories');
    }
    return map;
  }

  AppException _mapPostgrest(PostgrestException e) {
    if (e.code == '401' || e.message.contains('JWT')) {
      return UnauthorizedException(message: e.message, statusCode: 401);
    }
    if (e.code == '404') return NotFoundException(message: e.message, statusCode: 404);
    return ServerException(message: e.message);
  }
}

String _ymd(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

final transactionsRemoteDataSourceProvider =
    Provider<TransactionsRemoteDataSource>((ref) {
  return TransactionsRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
});
