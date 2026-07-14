import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/budget_remote_data_source.dart';
import '../models/budget_model.dart';
import '../models/saving_goal_model.dart';

/// Thin wrapper around [BudgetRemoteDataSource]. Keeps the presentation
/// layer free of Dio types so we can swap data sources (cache, mock,
/// SQLite, …) later without touching providers.
class BudgetRepository {
  BudgetRepository(this._remote);

  final BudgetRemoteDataSource _remote;

  Future<BudgetTabData> loadBudgetTab({int? month, int? year}) =>
      _remote.fetchBudgetTab(month: month, year: year);

  /// `GET /budgets` — historical list (paginated). See
  /// [BudgetRemoteDataSource.fetchAll] for parameter semantics.
  Future<BudgetsPage> loadAll({
    int page = 1,
    int perPage = 20,
    String? status,
    int? year,
  }) =>
      _remote.fetchAll(
        page: page,
        perPage: perPage,
        status: status,
        year: year,
      );

  Future<BudgetModel> createBudget({
    required double totalAmount,
    required String currency,
    required List<BudgetCategoryAllocation> categories,
    int? month,
    int? year,
    String? periodStart,
    double? totalIncome,
  }) =>
      _remote.createBudget(
        totalAmount: totalAmount,
        currency: currency,
        categories: categories,
        month: month,
        year: year,
        periodStart: periodStart,
        totalIncome: totalIncome,
      );

  Future<BudgetModel> updateBudget({
    required int budgetId,
    required double totalAmount,
    required List<BudgetCategoryAllocation> categories,
    double? totalIncome,
    String? currency,
  }) =>
      _remote.updateBudget(
        budgetId: budgetId,
        totalAmount: totalAmount,
        categories: categories,
        totalIncome: totalIncome,
        currency: currency,
      );

  Future<SavingGoalModel> createSavingGoal({
    required String title,
    required double targetAmount,
    required String deadline,
    required String currency,
    String? description,
    String? icon,
    String? color,
    String? startDate,
  }) =>
      _remote.createSavingGoal(
        title: title,
        targetAmount: targetAmount,
        deadline: deadline,
        currency: currency,
        description: description,
        icon: icon,
        color: color,
        startDate: startDate,
      );
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(budgetRemoteDataSourceProvider));
});
