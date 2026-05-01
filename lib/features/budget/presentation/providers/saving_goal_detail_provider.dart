import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/data_sources/saving_goals_remote_data_source.dart';
import '../../data/models/goal_monthly_progress.dart';
import '../../data/models/saving_goal_model.dart';
import '../../data/repositories/saving_goals_repository.dart';
import 'budget_tab_provider.dart';

/// `GET /saving-goals/{id}/monthly-progress`. AutoDispose so navigating
/// off the goal detail screen drops the cached chart.
final goalMonthlyProgressProvider = AutoDisposeFutureProviderFamily<
    GoalMonthlyProgress, int>((ref, goalId) {
  return ref.read(savingGoalsRepositoryProvider).monthlyProgress(
        goalId: goalId,
      );
});

/// `GET /saving-goals/{id}/deposits` — first page only. The detail
/// screen renders the latest deposits and links to the full history;
/// the spec lets us page further with `page` / `per_page`, but
/// we keep this provider focused on "show the recent ones".
final goalRecentDepositsProvider = AutoDisposeFutureProviderFamily<
    GoalDepositsPage, int>((ref, goalId) {
  return ref.read(savingGoalsRepositoryProvider).deposits(
        goalId: goalId,
        page: 1,
        perPage: 10,
      );
});

/// State for the deposit form rendered on the goal detail screen.
class GoalDepositState {
  const GoalDepositState({
    this.amountText = '',
    this.note = '',
    this.transactionDate,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String amountText;
  final String note;

  /// `null` → server uses today.
  final DateTime? transactionDate;

  final bool isSubmitting;
  final String? errorMessage;

  /// Spec / Laravel rule: `amount > 0`. Mirror it client-side so the
  /// submit button stays disabled until the user types a sensible
  /// number.
  double? get parsedAmount {
    final raw = amountText.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return null;
    return n;
  }

  bool get canSubmit => parsedAmount != null && !isSubmitting;

  GoalDepositState copyWith({
    String? amountText,
    String? note,
    Object? transactionDate = _unset,
    bool? isSubmitting,
    Object? errorMessage = _unset,
  }) {
    return GoalDepositState(
      amountText: amountText ?? this.amountText,
      note: note ?? this.note,
      transactionDate: identical(transactionDate, _unset)
          ? this.transactionDate
          : transactionDate as DateTime?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

class GoalDepositNotifier
    extends AutoDisposeFamilyNotifier<GoalDepositState, int> {
  @override
  GoalDepositState build(int goalId) => const GoalDepositState();

  void setAmount(String value) {
    state = state.copyWith(amountText: value, errorMessage: null);
  }

  void setNote(String value) {
    state = state.copyWith(note: value, errorMessage: null);
  }

  void setDate(DateTime? value) {
    state = state.copyWith(transactionDate: value, errorMessage: null);
  }

  /// Posts the deposit and refreshes the budget tab + the goal-detail
  /// providers so the screen reflects the new totals.
  ///
  /// Returns the updated [SavingGoalModel] on success, `null` on
  /// failure (the error message is already in [state]).
  Future<SavingGoalModel?> submit() async {
    final amount = state.parsedAmount;
    if (amount == null) return null;

    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updated =
          await ref.read(savingGoalsRepositoryProvider).deposit(
                goalId: arg,
                amount: amount,
                note: state.note.trim().isNotEmpty ? state.note.trim() : null,
                transactionDate: state.transactionDate != null
                    ? _ymd(state.transactionDate!)
                    : null,
              );
      // Reset the form for the next deposit and tell the rest of the
      // app that goal totals + recent deposits + monthly chart are
      // all stale.
      state = const GoalDepositState();
      ref.invalidate(goalMonthlyProgressProvider(arg));
      ref.invalidate(goalRecentDepositsProvider(arg));
      // Refreshing the budget tab pulls /saving-goals again, which
      // updates the card on the budget screen with the new
      // current_amount + pace.
      await ref.read(budgetTabProvider.notifier).refresh();
      return updated;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message ?? 'Error',
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}

final goalDepositProvider = AutoDisposeNotifierProviderFamily<
    GoalDepositNotifier, GoalDepositState, int>(
  GoalDepositNotifier.new,
);

String _ymd(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
