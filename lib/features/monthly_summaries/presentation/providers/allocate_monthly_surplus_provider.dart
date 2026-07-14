import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../budget/presentation/providers/budget_tab_provider.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../data/models/monthly_summary_model.dart';
import '../../data/repositories/monthly_summaries_repository.dart';
import 'monthly_summaries_provider.dart';

/// One row in the allocate sheet — the user picks an active goal and
/// types an amount. The new server contract takes one allocation per
/// HTTP request, so multi-row sheets fire requests serially (see
/// [AllocateMonthlySurplusNotifier.submit]) and accumulate the
/// per-row results onto the parent summary as they come back.
class AllocateRowDraft {
  const AllocateRowDraft({
    this.savingGoalId,
    this.amountText = '',
  });

  final int? savingGoalId;
  final String amountText;

  double? get parsedAmount {
    final raw = amountText.replaceAll(',', '.').trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return null;
    return n;
  }

  bool get isReady => savingGoalId != null && parsedAmount != null;

  AllocateRowDraft copyWith({
    Object? savingGoalId = _unset,
    String? amountText,
  }) {
    return AllocateRowDraft(
      savingGoalId: identical(savingGoalId, _unset)
          ? this.savingGoalId
          : savingGoalId as int?,
      amountText: amountText ?? this.amountText,
    );
  }
}

const Object _unset = Object();

class AllocateMonthlySurplusState {
  const AllocateMonthlySurplusState({
    required this.summary,
    required this.rows,
    required this.isSubmitting,
    required this.submittedRows,
    required this.totalRowsToSubmit,
    required this.errorMessage,
  });

  factory AllocateMonthlySurplusState.from(MonthlySummaryModel summary) {
    return AllocateMonthlySurplusState(
      summary: summary,
      // Start with a single empty row — the user can add more if they
      // want to split the surplus across several goals in one shot.
      rows: const [AllocateRowDraft()],
      isSubmitting: false,
      submittedRows: 0,
      totalRowsToSubmit: 0,
      errorMessage: null,
    );
  }

  /// Snapshot of the summary the sheet opened on, rolled forward as
  /// per-row allocations come back from the server. The notifier uses
  /// `summary.id` for the POST + `summary.unallocatedRemaining` for
  /// the "max" guard.
  final MonthlySummaryModel summary;
  final List<AllocateRowDraft> rows;
  final bool isSubmitting;

  /// How many rows have been confirmed by the server in the current
  /// submit pass. Renders the "1/3 ↻" progress hint in the sheet
  /// while [isSubmitting] is true.
  final int submittedRows;
  final int totalRowsToSubmit;

  final String? errorMessage;

  /// Sum of every fully-typed row. Used to show "Remaining" in the
  /// sheet and to disable submit when the user has overshot the
  /// available unallocated remaining.
  double get plannedTotal {
    var total = 0.0;
    for (final row in rows) {
      total += row.parsedAmount ?? 0;
    }
    return total;
  }

  double get remaining =>
      (summary.unallocatedRemaining - plannedTotal).clamp(
        -double.infinity,
        double.infinity,
      );

  bool get hasOverflow =>
      plannedTotal > summary.unallocatedRemaining + 0.01;

  bool get canSubmit {
    if (isSubmitting) return false;
    if (hasOverflow) return false;
    if (plannedTotal <= 0) return false;
    return rows.any((r) => r.isReady);
  }

  AllocateMonthlySurplusState copyWith({
    MonthlySummaryModel? summary,
    List<AllocateRowDraft>? rows,
    bool? isSubmitting,
    int? submittedRows,
    int? totalRowsToSubmit,
    Object? errorMessage = _unset,
  }) {
    return AllocateMonthlySurplusState(
      summary: summary ?? this.summary,
      rows: rows ?? this.rows,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submittedRows: submittedRows ?? this.submittedRows,
      totalRowsToSubmit: totalRowsToSubmit ?? this.totalRowsToSubmit,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AllocateMonthlySurplusNotifier extends AutoDisposeFamilyNotifier<
    AllocateMonthlySurplusState, MonthlySummaryModel> {
  @override
  AllocateMonthlySurplusState build(MonthlySummaryModel arg) {
    return AllocateMonthlySurplusState.from(arg);
  }

  void addRow() {
    state = state.copyWith(
      rows: [...state.rows, const AllocateRowDraft()],
      errorMessage: null,
    );
  }

  void removeRow(int index) {
    if (state.rows.length <= 1) return;
    final next = [...state.rows]..removeAt(index);
    state = state.copyWith(rows: next, errorMessage: null);
  }

  void setRowGoal(int index, int? goalId) {
    if (index < 0 || index >= state.rows.length) return;
    final next = [...state.rows];
    next[index] = next[index].copyWith(savingGoalId: goalId);
    state = state.copyWith(rows: next, errorMessage: null);
  }

  void setRowAmount(int index, String value) {
    if (index < 0 || index >= state.rows.length) return;
    final next = [...state.rows];
    next[index] = next[index].copyWith(amountText: value);
    state = state.copyWith(rows: next, errorMessage: null);
  }

  /// Submits each fully-typed row to `POST /monthly-summaries/{id}/allocate`
  /// in sequence (the new server contract takes one allocation per
  /// request). After every successful row, the local [summary] is
  /// rolled forward using the server's mini-payload so the sheet's
  /// "remaining" hint stays accurate even mid-flight.
  ///
  /// On the first failure we stop, surface the error, and keep the
  /// rows that already succeeded — the user can fix the offending
  /// row and tap submit again to retry just the leftovers.
  ///
  /// Returns the (rolled-forward) summary on full success, `null`
  /// when at least one row failed.
  Future<MonthlySummaryModel?> submit() async {
    if (!state.canSubmit) return null;
    final pending = state.rows.where((r) => r.isReady).toList();
    if (pending.isEmpty) return null;

    state = state.copyWith(
      isSubmitting: true,
      submittedRows: 0,
      totalRowsToSubmit: pending.length,
      errorMessage: null,
    );

    var working = state.summary;
    final repo = ref.read(monthlySummariesRepositoryProvider);
    final consumedRowIndices = <int>{};

    for (var i = 0; i < pending.length; i++) {
      final row = pending[i];
      try {
        final result = await repo.allocate(
          summaryId: working.id,
          savingGoalId: row.savingGoalId!,
          amount: row.parsedAmount!,
        );
        // Roll the parent summary forward locally so subsequent rows
        // can see the freshly-reduced unallocated_remaining.
        working = working.applyAllocationUpdate(
          status: result.monthlySummary.allocationStatus,
          allocatedAmount: result.monthlySummary.allocatedAmount,
          unallocatedRemaining: result.monthlySummary.unallocatedRemaining,
        );
        // Track which draft row consumed this allocation so we can
        // strip them once we either finish or hit a failure.
        final draftIndex = state.rows.indexOf(row);
        if (draftIndex >= 0) consumedRowIndices.add(draftIndex);
        state = state.copyWith(
          summary: working,
          submittedRows: i + 1,
        );
      } on AppException catch (e) {
        // Drop the rows that already shipped so the user can retry
        // just the leftover ones.
        final remainingRows = [
          for (var j = 0; j < state.rows.length; j++)
            if (!consumedRowIndices.contains(j)) state.rows[j],
        ];
        state = state.copyWith(
          summary: working,
          rows: remainingRows.isEmpty
              ? const [AllocateRowDraft()]
              : remainingRows,
          isSubmitting: false,
          submittedRows: 0,
          totalRowsToSubmit: 0,
          errorMessage: e.message ?? 'Error',
        );
        _invalidateCaches(working);
        return null;
      } catch (e) {
        final remainingRows = [
          for (var j = 0; j < state.rows.length; j++)
            if (!consumedRowIndices.contains(j)) state.rows[j],
        ];
        state = state.copyWith(
          summary: working,
          rows: remainingRows.isEmpty
              ? const [AllocateRowDraft()]
              : remainingRows,
          isSubmitting: false,
          submittedRows: 0,
          totalRowsToSubmit: 0,
          errorMessage: e.toString(),
        );
        _invalidateCaches(working);
        return null;
      }
    }

    state = state.copyWith(
      summary: working,
      isSubmitting: false,
      submittedRows: 0,
      totalRowsToSubmit: 0,
    );
    _invalidateCaches(working);
    return working;
  }

  /// Notify the rest of the app that goal balances and monthly
  /// rollups have moved. Splitting this out keeps the success and
  /// failure branches consistent — even partial allocations should
  /// invalidate the dashboard so the surplus banner updates.
  void _invalidateCaches(MonthlySummaryModel updated) {
    ref.invalidate(dashboardProvider);
    // Goals card on the budget tab (current_amount changed for the
    // goal we just funded).
    ref.read(budgetTabProvider.notifier).refresh();
    // List + detail caches for monthly summaries.
    ref.read(monthlySummariesListProvider.notifier).replace(updated);
    ref.invalidate(monthlySummaryProvider(
      MonthlySummaryKey(year: updated.year, month: updated.month),
    ));
  }
}

final allocateMonthlySurplusProvider = AutoDisposeNotifierProviderFamily<
    AllocateMonthlySurplusNotifier,
    AllocateMonthlySurplusState,
    MonthlySummaryModel>(
  AllocateMonthlySurplusNotifier.new,
);
