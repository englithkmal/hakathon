import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../models/goal_monthly_progress.dart';
import '../models/saving_goal_model.dart';

/// Page of `transaction(type=saving)` rows for a single goal — returned
/// by `GET /saving-goals/{id}/deposits`.
class GoalDepositsPage {
  const GoalDepositsPage({
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

/// Speaks to the per-goal endpoints documented under
/// "المرحلة 8 — أهداف الادخار":
///
///  * `POST /saving-goals/{id}/deposit`
///  * `GET /saving-goals/{id}/deposits`
///  * `GET /saving-goals/{id}/monthly-progress`
///
/// The CRUD endpoints (`POST /saving-goals`, `PUT /saving-goals/{id}`,
/// `DELETE /saving-goals/{id}`, `GET /saving-goals?status=...`) live on
/// `BudgetRemoteDataSource` because they're already consumed by the
/// budget tab — this class only carries the goal-detail / deposit-flow
/// methods to keep both surfaces small.
abstract class SavingGoalsRemoteDataSource {
  /// `POST /saving-goals/{id}/deposit` — records a deposit and returns
  /// the freshly-updated goal (the server folds the deposit into a
  /// backing `transaction(type=saving, saving_goal_id=id)` row).
  ///
  /// [transactionDate] should be `YYYY-MM-DD`. Omit it to let the
  /// server use today.
  Future<SavingGoalModel> deposit({
    required int goalId,
    required double amount,
    String? note,
    String? transactionDate,
  });

  /// `GET /saving-goals/{id}/deposits` — paginated `type=saving`
  /// transactions for the goal. Optional [year] / [month] filters
  /// narrow the page to a single month.
  Future<GoalDepositsPage> fetchDeposits({
    required int goalId,
    int page = 1,
    int perPage = 20,
    int? year,
    int? month,
  });

  /// `GET /saving-goals/{id}/monthly-progress` — month-by-month
  /// expected-vs-deposited rollup. Used to render the
  /// "كم وفّرت كل شهر؟" bar chart inside the goal detail screen.
  Future<GoalMonthlyProgress> fetchMonthlyProgress({required int goalId});

  /// `PUT /saving-goals/{id}` — partial update. Only the supplied
  /// fields are sent (everything else is left untouched server-side).
  /// `status` accepts `active` | `paused` | `cancelled` | `achieved`.
  Future<SavingGoalModel> update({
    required int goalId,
    String? title,
    String? description,
    double? targetAmount,
    String? deadline,
    String? startDate,
    String? icon,
    String? color,
    String? currency,
    String? status,
  });

  /// `DELETE /saving-goals/{id}` — server cascades the underlying
  /// `transaction(type=saving, saving_goal_id=...)` rows.
  Future<void> delete({required int goalId});
}

class SavingGoalsRemoteDataSourceImpl implements SavingGoalsRemoteDataSource {
  SavingGoalsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<SavingGoalModel> deposit({
    required int goalId,
    required double amount,
    String? note,
    String? transactionDate,
  }) async {
    try {
      final body = <String, dynamic>{'amount': amount};
      if (note != null && note.trim().isNotEmpty) body['note'] = note.trim();
      if (transactionDate != null && transactionDate.isNotEmpty) {
        body['transaction_date'] = transactionDate;
      }
      final res = await _dio.post(
        ApiEndpoints.savingGoalDeposit(goalId),
        data: body,
      );
      return SavingGoalModel.fromJson(_unwrapGoal(res.data, 'deposit'));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<GoalDepositsPage> fetchDeposits({
    required int goalId,
    int page = 1,
    int perPage = 20,
    int? year,
    int? month,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (year != null) qp['year'] = year;
      if (month != null) qp['month'] = month;
      final res = await _dio.get(
        ApiEndpoints.savingGoalDeposits(goalId),
        queryParameters: qp,
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /saving-goals/{id}/deposits response shape.',
        );
      }
      // Three response shapes ship in the wild — handle all three so
      // deploys can flip without breaking the client:
      //
      //   1. **New canonical** (current spec):
      //      `data: { items: [...], meta: { current_page, last_page,
      //                                     total, sum } }`
      //      The `sum` field on meta is the goal's `current_amount`
      //      across all pages — used as a refresh hint for the goal
      //      header without an extra round trip.
      //
      //   2. **Laravel paginator** (older deploys):
      //      `data: { data: [...], current_page, last_page, total, ... }`
      //
      //   3. **Flat list** (very old deploys):
      //      `data: [...]` with `meta` at the root.
      final raw = body['data'];
      List<Map<String, dynamic>> rows = const [];
      Map<String, dynamic>? meta;
      if (raw is List) {
        rows = _castList(raw);
        if (body['meta'] is Map<String, dynamic>) {
          meta = body['meta'] as Map<String, dynamic>;
        }
      } else if (raw is Map<String, dynamic>) {
        if (raw['items'] is List) {
          rows = _castList(raw['items'] as List);
          if (raw['meta'] is Map<String, dynamic>) {
            meta = raw['meta'] as Map<String, dynamic>;
          } else if (body['meta'] is Map<String, dynamic>) {
            meta = body['meta'] as Map<String, dynamic>;
          } else {
            meta = raw;
          }
        } else if (raw['data'] is List) {
          rows = _castList(raw['data'] as List);
          meta = raw;
        }
      }
      final items = rows.map(TransactionModel.fromJson).toList();
      return GoalDepositsPage(
        items: items,
        currentPage: _toInt(meta?['current_page'] ?? page, fallback: page),
        lastPage: _toInt(meta?['last_page'] ?? page, fallback: page),
        total: _toInt(meta?['total'] ?? items.length, fallback: items.length),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<GoalMonthlyProgress> fetchMonthlyProgress({
    required int goalId,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.savingGoalMonthlyProgress(goalId),
        queryParameters: {
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /monthly-progress response shape.',
        );
      }
      final inner = body['data'];
      final map = inner is Map<String, dynamic> ? inner : body;
      return GoalMonthlyProgress.fromJson(map);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<SavingGoalModel> update({
    required int goalId,
    String? title,
    String? description,
    double? targetAmount,
    String? deadline,
    String? startDate,
    String? icon,
    String? color,
    String? currency,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null && title.isNotEmpty) body['title'] = title;
      if (description != null) body['description'] = description;
      if (targetAmount != null) body['target_amount'] = targetAmount;
      if (deadline != null && deadline.isNotEmpty) {
        body['deadline'] = deadline;
      }
      if (startDate != null && startDate.isNotEmpty) {
        body['start_date'] = startDate;
      }
      if (icon != null) body['icon'] = icon;
      if (color != null) body['color'] = color;
      if (currency != null && currency.isNotEmpty) {
        body['currency'] = currency;
      }
      if (status != null && status.isNotEmpty) body['status'] = status;
      final res = await _dio.put(
        ApiEndpoints.savingGoalById(goalId),
        data: body,
      );
      return SavingGoalModel.fromJson(_unwrapGoal(res.data, 'update'));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<void> delete({required int goalId}) async {
    try {
      await _dio.delete(ApiEndpoints.savingGoalById(goalId));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Pulls the goal map out of either `{ data: {...} }` or a flat top-
  /// level shape (some Laravel resource wrappers skip the envelope).
  Map<String, dynamic> _unwrapGoal(Object? body, String label) {
    if (body is! Map<String, dynamic>) {
      throw ServerException(
        message: 'Unexpected /saving-goals/{id}/$label response shape.',
      );
    }
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  Options _noCache() => Options(
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

  AppException _unwrap(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return mapDioException(e);
  }

  List<Map<String, dynamic>> _castList(List raw) {
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return e.cast<String, dynamic>();
          return const <String, dynamic>{};
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

int _toInt(Object? v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

final savingGoalsRemoteDataSourceProvider =
    Provider<SavingGoalsRemoteDataSource>((ref) {
  return SavingGoalsRemoteDataSourceImpl(ref.watch(dioProvider));
});
