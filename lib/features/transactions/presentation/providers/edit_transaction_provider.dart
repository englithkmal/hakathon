import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transactions_repository.dart';
import 'transactions_provider.dart';

/// Form state for the "Edit transaction" bottom sheet. Hydrates from
/// the row the user long-pressed on the history list and tracks
/// changes against that snapshot so we only ship modified fields to
/// `PUT /transactions/{id}`.
class EditTransactionState {
  const EditTransactionState({
    required this.original,
    required this.amountText,
    required this.type,
    required this.categoryId,
    required this.note,
    required this.transactionDate,
    required this.isSubmitting,
    required this.isDeleting,
    required this.errorMessage,
    required this.fieldErrors,
  });

  factory EditTransactionState.from(TransactionModel tx) {
    final parsedDate = DateTime.tryParse(tx.transactionDate)?.toLocal() ??
        DateTime.now();
    return EditTransactionState(
      original: tx,
      // Pretty-print so we don't surface trailing `.0` artefacts when
      // amounts are whole numbers (e.g. "150" instead of "150.0").
      amountText: tx.amount % 1 == 0
          ? tx.amount.toInt().toString()
          : tx.amount.toString(),
      type: tx.type,
      categoryId: tx.category.id,
      note: tx.description,
      transactionDate: parsedDate,
      isSubmitting: false,
      isDeleting: false,
      errorMessage: null,
      fieldErrors: const {},
    );
  }

  /// Snapshot of the row at the moment the sheet opened. Used to build
  /// a diff payload and to render labels (currency, category icon,
  /// etc.).
  final TransactionModel original;

  final String amountText;
  final String type;
  final int categoryId;
  final String note;
  final DateTime transactionDate;
  final bool isSubmitting;
  final bool isDeleting;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;

  double get amount {
    final raw = amountText.replaceAll(',', '.').trim();
    return double.tryParse(raw) ?? 0;
  }

  bool get hasAmount => amount > 0;
  bool get canSubmit =>
      !isSubmitting && !isDeleting && hasAmount && categoryId > 0;

  /// True when at least one field differs from the original. The CTA
  /// stays disabled when nothing changed so we don't fire a no-op
  /// `PUT`.
  bool get isDirty {
    final origDate =
        DateTime.tryParse(original.transactionDate)?.toLocal();
    final origDay = origDate == null
        ? null
        : DateTime(origDate.year, origDate.month, origDate.day);
    final newDay = DateTime(
      transactionDate.year,
      transactionDate.month,
      transactionDate.day,
    );
    return amount != original.amount ||
        type != original.type ||
        categoryId != original.category.id ||
        note.trim() != original.description.trim() ||
        origDay != newDay;
  }

  EditTransactionState copyWith({
    String? amountText,
    String? type,
    int? categoryId,
    String? note,
    DateTime? transactionDate,
    bool? isSubmitting,
    bool? isDeleting,
    Object? errorMessage = _unset,
    Map<String, List<String>>? fieldErrors,
  }) {
    return EditTransactionState(
      original: original,
      amountText: amountText ?? this.amountText,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      transactionDate: transactionDate ?? this.transactionDate,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}

const Object _unset = Object();

class EditTransactionNotifier extends AutoDisposeFamilyNotifier<
    EditTransactionState, TransactionModel> {
  @override
  EditTransactionState build(TransactionModel arg) {
    return EditTransactionState.from(arg);
  }

  void setAmount(String value) {
    state = state.copyWith(amountText: value, errorMessage: null);
  }

  void setNote(String value) {
    state = state.copyWith(note: value, errorMessage: null);
  }

  void setDate(DateTime date) {
    state = state.copyWith(transactionDate: date, errorMessage: null);
  }

  void setCategory(int id, {String? type}) {
    state = state.copyWith(
      categoryId: id,
      type: type ?? state.type,
      errorMessage: null,
    );
  }

  void setType(String type) {
    if (type == state.type) return;
    state = state.copyWith(
      type: type,
      // Clearing the category forces the user to re-pick from the
      // type-filtered grid — the previously-selected one might not
      // belong to the new type any more.
      categoryId: 0,
      errorMessage: null,
    );
  }

  /// Builds the diff payload and sends `PUT /transactions/{id}`. Also
  /// kicks the dashboard cache to refresh because budget rollups,
  /// recent-transactions and category spend all depend on this row.
  ///
  /// Returns the updated [TransactionModel] on success, `null` on
  /// failure (the error is in [state]).
  Future<TransactionModel?> submit() async {
    if (!state.canSubmit) return null;
    final original = state.original;
    final payload = UpdateTransactionPayload(
      amount: state.amount != original.amount ? state.amount : _unset,
      type: state.type != original.type ? state.type : _unset,
      categoryId:
          state.categoryId != original.category.id ? state.categoryId : _unset,
      transactionDate: _changedDate(original.transactionDate, state.transactionDate),
      description: state.note.trim() != original.description.trim()
          ? state.note.trim()
          : _unset,
    );
    if (!payload.hasChanges) {
      // Nothing actually changed — short-circuit so we don't fire a
      // no-op PUT.
      return original;
    }

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      fieldErrors: const {},
    );
    try {
      final repo = ref.read(transactionsRepositoryProvider);
      final updated = await repo.update(original.id, payload);
      ref.read(transactionsProvider.notifier).replace(updated);
      // The dashboard caches budget rollups + recent transactions, so
      // edits ripple there. Invalidate so the next read refetches.
      ref.invalidate(dashboardProvider);
      return updated;
    } on ValidationException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        fieldErrors: e.fieldErrors ?? const {},
      );
      return null;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
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

  Future<bool> delete() async {
    state = state.copyWith(isDeleting: true, errorMessage: null);
    try {
      await ref.read(transactionsRepositoryProvider).delete(state.original.id);
      ref.read(transactionsProvider.notifier).removeById(state.original.id);
      ref.invalidate(dashboardProvider);
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: e.message,
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

  Object? _changedDate(String originalRaw, DateTime current) {
    final original = DateTime.tryParse(originalRaw)?.toLocal();
    if (original != null &&
        original.year == current.year &&
        original.month == current.month &&
        original.day == current.day) {
      return _unset;
    }
    return current;
  }
}

final editTransactionProvider = AutoDisposeNotifierProviderFamily<
    EditTransactionNotifier, EditTransactionState, TransactionModel>(
  EditTransactionNotifier.new,
);
