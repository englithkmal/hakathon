import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/models/saving_goal_model.dart';
import '../../data/repositories/saving_goals_repository.dart';
import 'budget_tab_provider.dart';
import 'saving_goal_detail_provider.dart';

/// Form state for the "Edit goal" bottom sheet, plus the delete flow.
///
/// Hydrates from the cached [SavingGoalModel] passed in by the screen
/// and only ships the diff to `PUT /saving-goals/{id}` so we don't
/// trample fields the user didn't touch.
class EditSavingGoalState {
  const EditSavingGoalState({
    required this.original,
    required this.title,
    required this.amountText,
    required this.deadline,
    required this.status,
    required this.isSubmitting,
    required this.isDeleting,
    required this.errorMessage,
  });

  factory EditSavingGoalState.from(SavingGoalModel goal) {
    DateTime? deadline;
    if (goal.deadline.isNotEmpty) {
      deadline = DateTime.tryParse(goal.deadline);
    }
    return EditSavingGoalState(
      original: goal,
      title: goal.title,
      amountText: goal.targetAmount % 1 == 0
          ? goal.targetAmount.toInt().toString()
          : goal.targetAmount.toString(),
      deadline: deadline,
      status: goal.status.isNotEmpty ? goal.status : 'active',
      isSubmitting: false,
      isDeleting: false,
      errorMessage: null,
    );
  }

  final SavingGoalModel original;
  final String title;
  final String amountText;
  final DateTime? deadline;

  /// `active` | `paused` | `cancelled` | `achieved`.
  final String status;

  final bool isSubmitting;
  final bool isDeleting;
  final String? errorMessage;

  /// Server contract: `target_amount` must be ≥ 1. Mirror that here so
  /// the CTA stays disabled until the user types a sensible figure.
  double? get parsedAmount {
    final raw = amountText.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n < 1) return null;
    return n;
  }

  bool get canSubmit =>
      !isSubmitting &&
      !isDeleting &&
      title.trim().isNotEmpty &&
      parsedAmount != null;

  /// True when at least one field differs from the original goal so
  /// we don't fire a no-op `PUT`.
  bool get isDirty {
    final originalDeadline = original.deadline.isNotEmpty
        ? DateTime.tryParse(original.deadline)
        : null;
    final sameDeadline = (originalDeadline == null && deadline == null) ||
        (originalDeadline != null &&
            deadline != null &&
            originalDeadline.year == deadline!.year &&
            originalDeadline.month == deadline!.month &&
            originalDeadline.day == deadline!.day);
    return title.trim() != original.title.trim() ||
        (parsedAmount != null && parsedAmount != original.targetAmount) ||
        !sameDeadline ||
        status != (original.status.isNotEmpty ? original.status : 'active');
  }

  EditSavingGoalState copyWith({
    String? title,
    String? amountText,
    Object? deadline = _unset,
    String? status,
    bool? isSubmitting,
    bool? isDeleting,
    Object? errorMessage = _unset,
  }) {
    return EditSavingGoalState(
      original: original,
      title: title ?? this.title,
      amountText: amountText ?? this.amountText,
      deadline: identical(deadline, _unset)
          ? this.deadline
          : deadline as DateTime?,
      status: status ?? this.status,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

/// Available status values per the API spec. Kept here so the UI and
/// the notifier agree on the canonical strings.
const List<String> kSavingGoalStatuses = [
  'active',
  'paused',
  'cancelled',
  'achieved',
];

class EditSavingGoalNotifier
    extends AutoDisposeFamilyNotifier<EditSavingGoalState, SavingGoalModel> {
  @override
  EditSavingGoalState build(SavingGoalModel arg) =>
      EditSavingGoalState.from(arg);

  void setTitle(String value) {
    state = state.copyWith(title: value, errorMessage: null);
  }

  void setAmount(String value) {
    state = state.copyWith(amountText: value, errorMessage: null);
  }

  void setDeadline(DateTime? value) {
    state = state.copyWith(deadline: value, errorMessage: null);
  }

  void setStatus(String value) {
    state = state.copyWith(status: value, errorMessage: null);
  }

  /// Submits the diff to `PUT /saving-goals/{id}` and refreshes the
  /// budget tab so the goal card reflects the new title/target/etc.
  ///
  /// Returns the updated goal on success, `null` on failure (the
  /// error message is in [state]).
  Future<SavingGoalModel?> submit() async {
    if (!state.canSubmit) return null;
    final original = state.original;
    final amount = state.parsedAmount!;
    final originalDeadline = original.deadline.isNotEmpty
        ? DateTime.tryParse(original.deadline)
        : null;

    String? deadlineParam;
    if (state.deadline != null) {
      final picked = state.deadline!;
      final sameAsOriginal = originalDeadline != null &&
          originalDeadline.year == picked.year &&
          originalDeadline.month == picked.month &&
          originalDeadline.day == picked.day;
      if (!sameAsOriginal) deadlineParam = _ymd(picked);
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final updated = await ref.read(savingGoalsRepositoryProvider).update(
            goalId: original.id,
            title: state.title.trim() != original.title.trim()
                ? state.title.trim()
                : null,
            targetAmount: amount != original.targetAmount ? amount : null,
            deadline: deadlineParam,
            status: state.status != original.status ? state.status : null,
          );
      ref.invalidate(goalMonthlyProgressProvider(original.id));
      ref.invalidate(goalRecentDepositsProvider(original.id));
      await ref.read(budgetTabProvider.notifier).refresh();
      state = state.copyWith(isSubmitting: false);
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

  /// `DELETE /saving-goals/{id}` — server cascades the related
  /// `transaction(type=saving)` rows. Returns `true` on success.
  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, errorMessage: null);
    try {
      await ref
          .read(savingGoalsRepositoryProvider)
          .delete(goalId: state.original.id);
      await ref.read(budgetTabProvider.notifier).refresh();
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: e.message ?? 'Error',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final editSavingGoalProvider = AutoDisposeNotifierProviderFamily<
    EditSavingGoalNotifier, EditSavingGoalState, SavingGoalModel>(
  EditSavingGoalNotifier.new,
);

String _ymd(DateTime d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
