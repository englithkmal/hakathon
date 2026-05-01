import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_provider.dart';
import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/data/repositories/transactions_repository.dart';

/// Compound key for the category-transactions provider — uniquely
/// identifies a "category × month × year" combination. Used as the
/// `family` argument so each (category, month) pair gets its own
/// provider state and cache.
class CategoryTransactionsKey {
  const CategoryTransactionsKey({
    required this.categoryId,
    required this.month,
    required this.year,
  });

  final int categoryId;
  final int month;
  final int year;

  @override
  bool operator ==(Object other) =>
      other is CategoryTransactionsKey &&
      other.categoryId == categoryId &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(categoryId, month, year);
}

/// Loads expense transactions for a given category in a given budget
/// period. Used by the budget category detail screen.
///
/// We only fetch the first page (50 items by default) to keep the
/// initial render snappy; the screen surfaces the most recent items
/// and points the user to the global transactions list via the
/// "see all" link for deeper history.
final categoryTransactionsProvider = FutureProvider.autoDispose
    .family<List<TransactionModel>, CategoryTransactionsKey>((ref, key) async {
  // Re-fetch on locale switches so category names stay consistent
  // with the rest of the app (server-localised via `Accept-Language`).
  ref.watch(localeProvider);

  final from = DateTime(key.year, key.month, 1);
  // Last day of the month: jump to the next month then back one day.
  final to = DateTime(key.year, key.month + 1, 0);

  final page = await ref.read(transactionsRepositoryProvider).loadPage(
        page: 1,
        perPage: 50,
        categoryId: key.categoryId,
        type: 'expense',
        from: from,
        to: to,
      );
  return page.items;
});
