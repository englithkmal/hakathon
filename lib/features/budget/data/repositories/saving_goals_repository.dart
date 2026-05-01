import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_sources/saving_goals_remote_data_source.dart';
import '../models/goal_monthly_progress.dart';
import '../models/saving_goal_model.dart';

/// Thin wrapper around [SavingGoalsRemoteDataSource]. Keeps the
/// presentation layer free of Dio types so we can later swap data
/// sources (cache, mock, …) without touching providers/screens.
class SavingGoalsRepository {
  SavingGoalsRepository(this._remote);

  final SavingGoalsRemoteDataSource _remote;

  Future<SavingGoalModel> deposit({
    required int goalId,
    required double amount,
    String? note,
    String? transactionDate,
  }) =>
      _remote.deposit(
        goalId: goalId,
        amount: amount,
        note: note,
        transactionDate: transactionDate,
      );

  Future<GoalMonthlyProgress> monthlyProgress({required int goalId}) =>
      _remote.fetchMonthlyProgress(goalId: goalId);

  Future<GoalDepositsPage> deposits({
    required int goalId,
    int page = 1,
    int perPage = 20,
    int? year,
    int? month,
  }) =>
      _remote.fetchDeposits(
        goalId: goalId,
        page: page,
        perPage: perPage,
        year: year,
        month: month,
      );

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
  }) =>
      _remote.update(
        goalId: goalId,
        title: title,
        description: description,
        targetAmount: targetAmount,
        deadline: deadline,
        startDate: startDate,
        icon: icon,
        color: color,
        currency: currency,
        status: status,
      );

  Future<void> delete({required int goalId}) =>
      _remote.delete(goalId: goalId);
}

final savingGoalsRepositoryProvider = Provider<SavingGoalsRepository>((ref) {
  return SavingGoalsRepository(
    ref.watch(savingGoalsRemoteDataSourceProvider),
  );
});
