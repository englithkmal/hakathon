import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../data/data_sources/budget_remote_data_source.dart';
import '../../data/repositories/budget_repository.dart';
import 'budget_tab_provider.dart';

/// In-flight state for the "add budget category" sheet.
///
/// One small, immutable value object so the UI can react to typed
/// input + validation + the in-flight network call without managing
/// 4 separate `AsyncValue`s.
class AddBudgetCategoryState {
  const AddBudgetCategoryState({
    this.selectedCategoryId,
    this.amountText = '',
    this.errorMessage,
    this.isSubmitting = false,
  });

  /// The global `Category.id` chosen from the grid. `null` when the
  /// user hasn't picked one yet.
  final int? selectedCategoryId;

  /// Raw text typed in the monthly-limit field. Kept as a string so we
  /// can preserve in-progress input like `"1,2"` without parsing it
  /// back into a double on every keystroke.
  final String amountText;
  final String? errorMessage;
  final bool isSubmitting;

  bool get hasCategory => selectedCategoryId != null;

  double? get parsedAmount {
    final raw = amountText.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return null;
    return n;
  }

  bool get canSubmit =>
      hasCategory && parsedAmount != null && !isSubmitting;

  AddBudgetCategoryState copyWith({
    Object? selectedCategoryId = _unset,
    String? amountText,
    Object? errorMessage = _unset,
    bool? isSubmitting,
  }) {
    return AddBudgetCategoryState(
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      amountText: amountText ?? this.amountText,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

const Object _unset = Object();

final addBudgetCategoryProvider =
    NotifierProvider.autoDispose<AddBudgetCategoryNotifier, AddBudgetCategoryState>(
  AddBudgetCategoryNotifier.new,
);

class AddBudgetCategoryNotifier
    extends AutoDisposeNotifier<AddBudgetCategoryState> {
  @override
  AddBudgetCategoryState build() => const AddBudgetCategoryState();

  void selectCategory(int id) {
    state = state.copyWith(
      selectedCategoryId: id,
      errorMessage: null,
    );
  }

  void setAmount(String text) {
    state = state.copyWith(amountText: text, errorMessage: null);
  }

  /// Submits the new allocation:
  ///   - if the period already has a budget → `PUT /budgets/{id}` with
  ///     the existing allocations + the new one,
  ///   - otherwise → `POST /budgets` with just the new allocation,
  ///     defaulting `month/year` to the current period.
  ///
  /// Returns `true` on success.
  Future<bool> submit({String? defaultCurrency}) async {
    final categoryId = state.selectedCategoryId;
    final amount = state.parsedAmount;
    if (categoryId == null || amount == null) {
      state = state.copyWith(isSubmitting: false);
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final tab = await ref.read(budgetTabProvider.future);
      final existing = tab.budget;
      final repo = ref.read(budgetRepositoryProvider);

      final newAllocation = BudgetCategoryAllocation(
        categoryId: categoryId,
        allocatedAmount: amount,
      );

      // Capture the budget's period so we can re-anchor the tab to
      // it on success — without this, `GET /budgets/current` would
      // default to "today on the server" and miss budgets we just
      // created for next month (or even this month, if the server
      // clock is in a different timezone than the user).
      int targetMonth;
      int targetYear;

      if (existing != null) {
        // Replace if the user is updating an existing allocation,
        // otherwise append. The API expects the *full* list because
        // it sync-replaces server-side.
        final updated = <BudgetCategoryAllocation>[];
        var replaced = false;
        for (final c in existing.categories) {
          if (c.category.id == categoryId) {
            updated.add(newAllocation);
            replaced = true;
          } else {
            updated.add(BudgetCategoryAllocation(
              categoryId: c.category.id,
              allocatedAmount: c.allocatedAmount,
              alertThreshold:
                  c.alertThreshold > 0 ? c.alertThreshold : 80,
            ));
          }
        }
        if (!replaced) updated.add(newAllocation);

        // Bump the budget cap so the new allocation actually fits even
        // if the user hadn't budgeted for it yet.
        final newTotal = updated.fold<double>(
          0,
          (a, c) => a + c.allocatedAmount,
        );
        final newTotalAmount =
            newTotal > existing.totalAmount ? newTotal : existing.totalAmount;

        await repo.updateBudget(
          budgetId: existing.id,
          totalAmount: newTotalAmount,
          categories: updated,
          totalIncome:
              existing.totalIncome > 0 ? existing.totalIncome : null,
          currency: existing.currency,
        );
        targetMonth = existing.month;
        targetYear = existing.year;
      } else {
        // First-of-month `period_start` so Laravel derives the right
        // month/year — keeps the contract a single source of truth
        // (the doc note: any date inside the month works, the day is
        // ignored on the server).
        final now = DateTime.now();
        final ps =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        final created = await repo.createBudget(
          totalAmount: amount,
          // Caller passes the resolved currency (existing budget or
          // user profile). `AppConstants.defaultCurrency` is just the
          // last-resort safety net.
          currency: defaultCurrency ?? AppConstants.defaultCurrency,
          categories: [newAllocation],
          periodStart: ps,
        );
        targetMonth = created.month != 0 ? created.month : now.month;
        targetYear = created.year != 0 ? created.year : now.year;
      }

      // Re-anchor the tab to the budget's actual period — `current`
      // without params would default to today and could miss the
      // budget we just persisted.
      await ref
          .read(budgetTabProvider.notifier)
          .refresh(month: targetMonth, year: targetYear);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message ?? 'Error',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}
