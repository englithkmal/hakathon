import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/error_interceptor.dart';
import '../../../period/data/models/selected_period.dart';
import '../models/budget_model.dart';
import '../models/saving_goal_model.dart';

/// Result of `GET /budgets/current`.
///
/// `budget` is `null` when the API responds with `data: null`
/// (the documented "no budget for this period" shape).
///
/// `serverPeriod` carries `meta.period` from the response — required
/// by the spec so the UI can render a "showing latest budget month"
/// banner whenever `serverPeriod.source == latest_budget`.
class CurrentBudgetResult {
  const CurrentBudgetResult({required this.budget, required this.serverPeriod});

  final BudgetModel? budget;
  final SelectedPeriod serverPeriod;
}

/// One page of `GET /budgets` results.
///
/// Laravel ships a standard paginator: `{ data: [...], meta: {
/// current_page, last_page, total, per_page } }`. The data source
/// normalises that into [items] + bookkeeping fields so the
/// presentation layer can drive an infinite-scroll list without
/// reasoning about the envelope shape.
class BudgetsPage {
  const BudgetsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<BudgetModel> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

/// Combined payload for the budget tab. The screen renders both the
/// budget summary and the active goals next to each other, so we ship
/// them in one bundle to avoid two separate `AsyncValue.when` blocks
/// fighting for the loader.
class BudgetTabData {
  const BudgetTabData({
    required this.budget,
    required this.goals,
    required this.serverPeriod,
  });

  /// `null` when the user has no active budget for the current period.
  final BudgetModel? budget;
  final List<SavingGoalModel> goals;

  /// `meta.period` echoed back by `/budgets/current`. Used to render
  /// the "showing latest budget month" banner when the server fell
  /// back to a different period than the one the user requested.
  final SelectedPeriod serverPeriod;
}

/// Single allocation row sent inside `categories[]` when creating or
/// updating a budget. Mirrors the Laravel validation contract:
///   `{ category_id, allocated_amount, alert_threshold? }`
class BudgetCategoryAllocation {
  const BudgetCategoryAllocation({
    required this.categoryId,
    required this.allocatedAmount,
    this.alertThreshold = 80,
  });

  final int categoryId;
  final double allocatedAmount;
  final int alertThreshold;

  Map<String, dynamic> toJson() => {
        'category_id': categoryId,
        'allocated_amount': allocatedAmount,
        'alert_threshold': alertThreshold,
      };
}

abstract class BudgetRemoteDataSource {
  /// `GET /budgets/current` — returns a [CurrentBudgetResult] carrying
  /// both the budget (or `null` when `data: null`) and the resolved
  /// `meta.period` so the UI can react to `source == latest_budget`.
  ///
  /// When [month] / [year] are provided, the request becomes
  /// `?month={m}&year={y}` so callers can fetch a budget that lives
  /// outside the current calendar month (e.g. right after creating a
  /// budget for next month). Without them the server falls back to
  /// "today on the server".
  Future<CurrentBudgetResult> fetchCurrentBudget({int? month, int? year});

  /// `GET /budgets` — paginated list of every budget the user owns
  /// (active + historical). [status] filters by `active`/`closed`/etc.
  /// when provided. [year] (when supported by the deployed API) keeps
  /// the page focused on a single calendar year.
  Future<BudgetsPage> fetchAll({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  });

  /// `GET /saving-goals?status=active`. Empty list when the user has no
  /// active goals yet.
  Future<List<SavingGoalModel>> fetchActiveSavingGoals();

  /// Convenience: load the budget and goals in parallel.
  ///
  /// [month] / [year] are forwarded to `GET /budgets/current` so the
  /// caller can target a specific period (e.g. right after creating
  /// a budget for next month — without them the server defaults to
  /// "today" and would return `data: null`).
  Future<BudgetTabData> fetchBudgetTab({int? month, int? year});

  /// `POST /budgets` — create a new budget for the given period.
  /// Returns the freshly persisted budget.
  ///
  /// You can either pass [month] / [year] explicitly, or hand the
  /// server a [periodStart] (any `YYYY-MM-DD` inside the target
  /// month). When [periodStart] is set, the API derives `month`/
  /// `year` from it and ignores any conflicting values you sent.
  Future<BudgetModel> createBudget({
    required double totalAmount,
    required String currency,
    required List<BudgetCategoryAllocation> categories,
    int? month,
    int? year,
    String? periodStart,
    double? totalIncome,
    String status = 'active',
  });

  /// `PUT /budgets/{id}` — replaces the allocation list for an
  /// existing budget. The full `categories[]` array must be provided
  /// (Laravel uses a sync-style update).
  Future<BudgetModel> updateBudget({
    required int budgetId,
    required double totalAmount,
    required List<BudgetCategoryAllocation> categories,
    double? totalIncome,
    String? currency,
    String? status,
  });

  /// `POST /saving-goals` — creates a new active goal for the user.
  /// `startDate` defaults to today server-side when omitted; we still
  /// pass it explicitly so the "monthly forecast" calculation lines up.
  Future<SavingGoalModel> createSavingGoal({
    required String title,
    required double targetAmount,
    required String deadline,
    required String currency,
    String? description,
    String? icon,
    String? color,
    String? startDate,
  });
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  BudgetRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<CurrentBudgetResult> fetchCurrentBudget({
    int? month,
    int? year,
  }) async {
    try {
      final qp = <String, dynamic>{
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (month != null) qp['month'] = month;
      if (year != null) qp['year'] = year;
      final res = await _dio.get(
        ApiEndpoints.currentBudget,
        queryParameters: qp,
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /budgets/current response shape.',
        );
      }
      // `meta.period` is the spec-mandated source for the period source
      // (see "اقرأ meta.period.source"). Defensive about Laravel
      // returning a flatter shape on older deploys.
      final meta = body['meta'];
      Map<String, dynamic>? periodMap;
      if (meta is Map<String, dynamic>) {
        final p = meta['period'];
        if (p is Map<String, dynamic>) periodMap = p;
      }
      final serverPeriod = periodMap != null
          ? SelectedPeriod.fromJson(periodMap)
          : SelectedPeriod.localFallback();

      final inner = body['data'];
      if (inner == null) {
        return CurrentBudgetResult(budget: null, serverPeriod: serverPeriod);
      }
      if (inner is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /budgets/current data shape.',
        );
      }
      return CurrentBudgetResult(
        budget: BudgetModel.fromJson(inner),
        serverPeriod: serverPeriod,
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<BudgetsPage> fetchAll({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        '_t': DateTime.now().millisecondsSinceEpoch,
      };
      if (status != null && status.isNotEmpty) qp['status'] = status;
      if (year != null) qp['year'] = year;
      final res = await _dio.get(
        ApiEndpoints.budgets,
        queryParameters: qp,
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /budgets response shape.',
        );
      }
      // Laravel paginators sometimes ship `{ data: [...], meta: {...} }`
      // and sometimes `{ data: { data: [...], current_page, ... } }`
      // depending on whether the controller used a Resource collection
      // or returned the paginator directly. Handle both.
      final raw = body['data'];
      List<Map<String, dynamic>> rows = const [];
      Map<String, dynamic>? meta;
      if (raw is List) {
        rows = _extractList(raw);
        if (body['meta'] is Map<String, dynamic>) {
          meta = body['meta'] as Map<String, dynamic>;
        }
      } else if (raw is Map<String, dynamic>) {
        final nested = raw['data'];
        if (nested is List) {
          rows = _extractList(nested);
          meta = raw;
        } else {
          rows = _extractList(raw);
        }
      }
      final items = rows.map(BudgetModel.fromJson).toList();
      return BudgetsPage(
        items: items,
        currentPage: _toPageInt(meta?['current_page'], fallback: page),
        lastPage: _toPageInt(meta?['last_page'], fallback: page),
        total: _toPageInt(meta?['total'], fallback: items.length),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<List<SavingGoalModel>> fetchActiveSavingGoals() async {
    try {
      final res = await _dio.get(
        ApiEndpoints.savingGoals,
        queryParameters: {
          'status': 'active',
          '_t': DateTime.now().millisecondsSinceEpoch,
        },
        options: _noCache(),
      );
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Unexpected /saving-goals response shape.',
        );
      }
      final raw = body['data'];
      // Spec ships `data: []`. Be lenient about either an array or a
      // `{ data: [...] }`-wrapped paginator (Laravel returns both
      // shapes depending on whether pagination is enabled).
      final list = _extractList(raw);
      return list.map(SavingGoalModel.fromJson).toList();
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<BudgetModel> createBudget({
    required double totalAmount,
    required String currency,
    required List<BudgetCategoryAllocation> categories,
    int? month,
    int? year,
    String? periodStart,
    double? totalIncome,
    String status = 'active',
  }) async {
    try {
      final body = <String, dynamic>{
        'total_amount': totalAmount,
        'currency': currency,
        'status': status,
        'categories': categories.map((c) => c.toJson()).toList(),
      };
      // Prefer `period_start` when supplied (the API derives
      // month/year from it). We still send `month`/`year` if the
      // caller passed them — Laravel falls back to those when
      // `period_start` is absent.
      if (periodStart != null && periodStart.isNotEmpty) {
        body['period_start'] = periodStart;
      }
      if (month != null) body['month'] = month;
      if (year != null) body['year'] = year;
      if (totalIncome != null) body['total_income'] = totalIncome;
      final res = await _dio.post(ApiEndpoints.budgets, data: body);
      return BudgetModel.fromJson(_unwrapBudget(res.data, 'POST /budgets'));
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<BudgetModel> updateBudget({
    required int budgetId,
    required double totalAmount,
    required List<BudgetCategoryAllocation> categories,
    double? totalIncome,
    String? currency,
    String? status,
  }) async {
    try {
      final body = <String, dynamic>{
        'total_amount': totalAmount,
        'categories': categories.map((c) => c.toJson()).toList(),
      };
      if (totalIncome != null) body['total_income'] = totalIncome;
      if (currency != null && currency.isNotEmpty) body['currency'] = currency;
      if (status != null && status.isNotEmpty) body['status'] = status;
      final res = await _dio.put(
        ApiEndpoints.budgetById(budgetId),
        data: body,
      );
      return BudgetModel.fromJson(
        _unwrapBudget(res.data, 'PUT /budgets/$budgetId'),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Future<SavingGoalModel> createSavingGoal({
    required String title,
    required double targetAmount,
    required String deadline,
    required String currency,
    String? description,
    String? icon,
    String? color,
    String? startDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'target_amount': targetAmount,
        'currency': currency,
        'deadline': deadline,
      };
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      if (icon != null && icon.isNotEmpty) body['icon'] = icon;
      if (color != null && color.isNotEmpty) body['color'] = color;
      if (startDate != null && startDate.isNotEmpty) {
        body['start_date'] = startDate;
      }
      final res = await _dio.post(ApiEndpoints.savingGoals, data: body);
      return SavingGoalModel.fromJson(
        _unwrapBudget(res.data, 'POST /saving-goals'),
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  /// Pull the actual budget map from a Laravel envelope. Accepts both
  /// `{ data: {...} }` and a flat top-level object.
  Map<String, dynamic> _unwrapBudget(Object? body, String label) {
    if (body is! Map<String, dynamic>) {
      throw ServerException(message: 'Unexpected $label response shape.');
    }
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  @override
  Future<BudgetTabData> fetchBudgetTab({int? month, int? year}) async {
    // `Future.wait` runs the two requests in parallel — the second
    // doesn't depend on the first, so we don't pay the round-trip
    // cost twice.
    final results = await Future.wait<Object>([
      fetchCurrentBudget(month: month, year: year),
      fetchActiveSavingGoals(),
    ]);
    final budgetResult = results[0] as CurrentBudgetResult;
    return BudgetTabData(
      budget: budgetResult.budget,
      serverPeriod: budgetResult.serverPeriod,
      goals: results[1] as List<SavingGoalModel>,
    );
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

  /// Coerces a paginator field (`current_page`, `last_page`, `total`)
  /// into an `int`. Server can ship them as integers, numeric strings,
  /// or omit them entirely — fall back to the caller's value when so.
  int _toPageInt(Object? raw, {required int fallback}) {
    if (raw == null) return fallback;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? fallback;
  }

  List<Map<String, dynamic>> _extractList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    }
    if (raw is Map) {
      final inner = raw['data'];
      if (inner is List) {
        return inner
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
      }
    }
    return const [];
  }
}

final budgetRemoteDataSourceProvider = Provider<BudgetRemoteDataSource>((ref) {
  return BudgetRemoteDataSourceImpl(ref.watch(dioProvider));
});
