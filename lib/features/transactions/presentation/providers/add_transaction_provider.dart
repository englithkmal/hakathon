import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transactions_repository.dart';
import 'transactions_provider.dart';

/// Tracks every field of the full-screen add-transaction sheet so the
/// numeric keypad, category grid, type toggle and note input can all
/// drive a single source of truth.
class AddTransactionState {
  const AddTransactionState({
    required this.amountText,
    required this.type,
    required this.categoryId,
    required this.note,
    required this.transactionDate,
    required this.isSubmitting,
    required this.errorMessage,
    required this.fieldErrors,
  });

  AddTransactionState.initial()
      : amountText = '0',
        type = 'expense',
        categoryId = null,
        note = '',
        transactionDate = DateTime.now(),
        isSubmitting = false,
        errorMessage = null,
        fieldErrors = const {};

  /// Raw user-entered text from the on-screen keypad. Stored as a string
  /// so we can preserve trailing decimals like "12." while the user is
  /// still typing.
  final String amountText;

  /// `expense` | `income` | `saving`.
  final String type;

  final int? categoryId;
  final String note;
  final DateTime transactionDate;

  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, List<String>> fieldErrors;

  double get amount => double.tryParse(amountText) ?? 0;
  bool get hasAmount => amount > 0;
  bool get canSubmit =>
      !isSubmitting && hasAmount && (categoryId ?? 0) > 0;

  AddTransactionState copyWith({
    String? amountText,
    String? type,
    int? Function()? categoryId,
    String? note,
    DateTime? transactionDate,
    bool? isSubmitting,
    String? Function()? errorMessage,
    Map<String, List<String>>? fieldErrors,
  }) =>
      AddTransactionState(
        amountText: amountText ?? this.amountText,
        type: type ?? this.type,
        categoryId: categoryId == null ? this.categoryId : categoryId(),
        note: note ?? this.note,
        transactionDate: transactionDate ?? this.transactionDate,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage:
            errorMessage == null ? this.errorMessage : errorMessage(),
        fieldErrors: fieldErrors ?? this.fieldErrors,
      );
}

class AddTransactionNotifier
    extends AutoDisposeNotifier<AddTransactionState> {
  static const int _maxIntegerDigits = 9;
  static const int _maxFractionDigits = 2;

  @override
  AddTransactionState build() => AddTransactionState.initial();

  // ─────────────────────────── Mutations ────────────────────────────

  /// Appends a digit (0-9) from the on-screen keypad. Honours sensible
  /// limits so the displayed amount can't grow unbounded.
  void pressDigit(int digit) {
    if (digit < 0 || digit > 9) return;
    final current = state.amountText;
    final hasDecimal = current.contains('.');

    if (hasDecimal) {
      final fraction = current.split('.').last;
      if (fraction.length >= _maxFractionDigits) return;
    } else {
      // Strip the leading "0" so "0" + "5" → "5", but keep "0" if user
      // pressed `0` alone repeatedly.
      if (current == '0') {
        if (digit == 0) return;
        state = state.copyWith(
          amountText: '$digit',
          errorMessage: () => null,
        );
        return;
      }
      // Cap the integer portion length.
      if (current.length >= _maxIntegerDigits) return;
    }

    state = state.copyWith(
      amountText: '$current$digit',
      errorMessage: () => null,
    );
  }

  /// Appends a `.` once. No-op if the amount already has a decimal.
  void pressDecimal() {
    if (state.amountText.contains('.')) return;
    state = state.copyWith(
      amountText: '${state.amountText}.',
      errorMessage: () => null,
    );
  }

  /// Removes the last character. Resets to "0" when the field becomes
  /// empty so the displayed value never blanks out.
  void pressBackspace() {
    final current = state.amountText;
    if (current.isEmpty || current == '0') return;
    final next = current.substring(0, current.length - 1);
    state = state.copyWith(
      amountText: next.isEmpty ? '0' : next,
      errorMessage: () => null,
    );
  }

  void resetAmount() {
    state = state.copyWith(
      amountText: '0',
      errorMessage: () => null,
    );
  }

  /// Used when seeding from an external source (e.g. deep-linked amount).
  void setAmount(double value) {
    final text = value <= 0
        ? '0'
        : (value % 1 == 0 ? value.toInt().toString() : value.toString());
    state = state.copyWith(
      amountText: text,
      errorMessage: () => null,
    );
  }

  /// Picks the category and snaps `type` to whatever the category's own
  /// type is (`expense` vs `income`). The full-screen sheet's toggle
  /// already filters categories by type, so the assignment is a no-op
  /// there. The inline quick-add card has no toggle, so this is what
  /// keeps the saved record's type consistent with the user's pick.
  void selectCategory(CategoryModel cat) {
    state = state.copyWith(
      categoryId: () => cat.id,
      type: cat.isExpense ? 'expense' : 'income',
      errorMessage: () => null,
    );
  }

  /// Switches between "expense" and "income". Resets the picked category
  /// because the grid below the toggle is filtered by [type].
  void setType(String type) {
    if (type == state.type) return;
    state = state.copyWith(
      type: type,
      categoryId: () => null,
      errorMessage: () => null,
    );
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void setDate(DateTime date) {
    state = state.copyWith(transactionDate: date);
  }

  void clear() {
    state = AddTransactionState.initial();
  }

  /// Submits to `POST /transactions` and, on success, prepends the new row
  /// to the transactions list cache so the user sees it instantly without
  /// waiting for a refresh.
  Future<bool> submit({String? currency}) async {
    final categoryId = state.categoryId;
    if (state.amount <= 0 || categoryId == null) return false;
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: () => null,
      fieldErrors: const {},
    );
    try {
      final payload = CreateTransactionPayload(
        amount: state.amount,
        type: state.type,
        categoryId: categoryId,
        transactionDate: state.transactionDate,
        currency: currency,
        description: state.note.trim().isEmpty ? null : state.note.trim(),
      );
      final created =
          await ref.read(transactionsRepositoryProvider).create(payload);
      ref.read(transactionsProvider.notifier).prepend(created);
      state = AddTransactionState.initial();
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.message,
        fieldErrors: e.fieldErrors ?? const {},
      );
      return false;
    } on AppException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.toString(),
      );
      return false;
    }
  }
}

final addTransactionProvider = NotifierProvider.autoDispose<
    AddTransactionNotifier, AddTransactionState>(AddTransactionNotifier.new);
