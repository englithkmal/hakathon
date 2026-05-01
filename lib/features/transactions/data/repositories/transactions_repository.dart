import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/transactions_remote_data_source.dart';
import '../models/transaction_model.dart';

/// Thin pass-through over [TransactionsRemoteDataSource]. Lives so the UI
/// can depend on a stable repository abstraction even when we later add
/// caching or offline support.
class TransactionsRepository {
  TransactionsRepository(this._remote);

  final TransactionsRemoteDataSource _remote;

  Future<TransactionsPage> loadPage({
    int page = 1,
    int perPage = 50,
    int? categoryId,
    String? type,
    DateTime? from,
    DateTime? to,
  }) {
    return _remote.fetchPage(
      page: page,
      perPage: perPage,
      categoryId: categoryId,
      type: type,
      from: from,
      to: to,
    );
  }

  Future<TransactionModel> create(CreateTransactionPayload payload) {
    return _remote.create(payload);
  }

  Future<TransactionModel> update(int id, UpdateTransactionPayload payload) {
    return _remote.update(id, payload);
  }

  Future<void> delete(int id) => _remote.delete(id);
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(
    ref.watch(transactionsRemoteDataSourceProvider),
  );
});
