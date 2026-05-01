import 'category_model.dart';

/// Single row from `GET /transactions` (paginated `data[]`).
///
/// Mirrors the same shape used by `recent_transactions` inside
/// `GET /dashboard`, plus the few extra fields that the dedicated list
/// endpoint can surface.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.description,
    required this.merchant,
    required this.source,
    required this.reference,
    required this.transactionDate,
    required this.budgetId,
    required this.category,
    required this.createdAt,
  });

  final int id;
  final double amount;
  final String currency;

  /// `expense` | `income` | `saving` (lowercase per the API).
  final String type;
  final String description;
  final String merchant;
  final String source;
  final String reference;

  /// ISO timestamp the operation actually happened.
  final String transactionDate;

  final int budgetId;
  final CategoryModel category;
  final String createdAt;

  bool get isIncome => type == 'income';
  bool get isSaving => type == 'saving';
  bool get isExpense => !isIncome && !isSaving;

  /// Signed amount: negative for expenses, positive otherwise.
  double get signedAmount => isExpense ? -amount.abs() : amount.abs();

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    return TransactionModel(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      type: (json['type'] ?? 'expense').toString(),
      description:
          (json['description'] ?? json['title'] ?? '').toString().trim(),
      merchant: (json['merchant'] ?? '').toString(),
      source: (json['source'] ?? 'manual').toString(),
      reference: (json['reference'] ?? '').toString(),
      transactionDate: (json['transaction_date'] ??
              json['transactionDate'] ??
              json['date'] ??
              '')
          .toString(),
      budgetId: _toInt(json['budget_id']),
      category: CategoryModel.fromJson(_asMap(cat)),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'currency': currency,
        'type': type,
        'description': description,
        'merchant': merchant,
        'source': source,
        'reference': reference,
        'transaction_date': transactionDate,
        'budget_id': budgetId,
        'category': category.toJson(),
        'created_at': createdAt,
      };
}

/// Body sent to `POST /transactions` when the user submits the in-screen
/// add-transaction card.
class CreateTransactionPayload {
  const CreateTransactionPayload({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.transactionDate,
    this.currency,
    this.description,
    this.merchant,
  });

  final double amount;
  final String type;
  final int categoryId;
  final DateTime transactionDate;
  final String? currency;
  final String? description;
  final String? merchant;

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'transaction_date': transactionDate.toIso8601String(),
    };
    if (currency != null && currency!.isNotEmpty) out['currency'] = currency;
    if (description != null && description!.trim().isNotEmpty) {
      out['description'] = description!.trim();
    }
    if (merchant != null && merchant!.trim().isNotEmpty) {
      out['merchant'] = merchant!.trim();
    }
    return out;
  }
}

/// Body sent to `PUT /transactions/{id}` — every field is optional so
/// the caller only ships what the user actually changed (Laravel's
/// `sometimes|...` rules treat unset keys as no-ops).
///
/// Use the [field] sentinel ([_unset]) to distinguish "user cleared
/// the field" (passes the value as `null` / empty string) from "user
/// didn't touch this field" (key omitted entirely from the payload).
class UpdateTransactionPayload {
  const UpdateTransactionPayload({
    this.amount = _unset,
    this.type = _unset,
    this.categoryId = _unset,
    this.transactionDate = _unset,
    this.currency = _unset,
    this.description = _unset,
    this.merchant = _unset,
  });

  final Object? amount;
  final Object? type;
  final Object? categoryId;
  final Object? transactionDate;
  final Object? currency;
  final Object? description;
  final Object? merchant;

  bool get hasChanges =>
      !identical(amount, _unset) ||
      !identical(type, _unset) ||
      !identical(categoryId, _unset) ||
      !identical(transactionDate, _unset) ||
      !identical(currency, _unset) ||
      !identical(description, _unset) ||
      !identical(merchant, _unset);

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    if (!identical(amount, _unset)) out['amount'] = amount;
    if (!identical(type, _unset)) out['type'] = type;
    if (!identical(categoryId, _unset)) out['category_id'] = categoryId;
    if (!identical(transactionDate, _unset)) {
      final v = transactionDate;
      out['transaction_date'] =
          v is DateTime ? v.toIso8601String() : v;
    }
    if (!identical(currency, _unset)) out['currency'] = currency;
    if (!identical(description, _unset)) out['description'] = description;
    if (!identical(merchant, _unset)) out['merchant'] = merchant;
    return out;
  }
}

const Object _unset = Object();

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
