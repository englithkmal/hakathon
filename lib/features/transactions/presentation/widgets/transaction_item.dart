import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/transaction_model.dart';
import 'category_icon.dart';
import 'transaction_actions.dart';

/// One row inside the transaction history card. Shows the category
/// avatar, description, time-of-day and the signed amount.
class TransactionItem extends StatelessWidget {
  const TransactionItem({
    super.key,
    required this.transaction,
    required this.languageCode,
    required this.formatTime,
  });

  final TransactionModel transaction;
  final String languageCode;
  final String Function(DateTime when) formatTime;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tx = transaction;
    final isIncome = tx.isIncome;
    final accent = categoryAccentColor(tx.category.color);
    final iconBg = isIncome
        ? scheme.secondaryContainer
        : (accent != null
            ? accent.withValues(alpha: 0.18)
            : scheme.errorContainer);
    final iconFg = isIncome
        ? scheme.onSecondaryContainer
        : (accent ?? scheme.onErrorContainer);

    final amountColor =
        isIncome ? scheme.primary : scheme.onSurface;
    final sign = isIncome ? '+' : '−';
    final money = tx.amount.abs().toStringAsFixed(2);

    final title = tx.description.isNotEmpty
        ? tx.description
        : tx.category.displayName(languageCode);

    final when = _parseDate(tx.transactionDate) ?? DateTime.now();
    final timeLabel = formatTime(when);

    // Tap = quick edit, long-press = full action menu (edit/delete).
    // Both flow through the same widgets so we don't duplicate state.
    return InkWell(
      onTap: () => showEditTransactionSheet(context, tx),
      onLongPress: () => showTransactionActionsSheet(context, tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                categoryIconFor(tx.category.icon.isNotEmpty
                    ? tx.category.icon
                    : tx.category.slug),
                size: 20,
                color: iconFg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMd(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: AppTextStyles.labelSm(color: scheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$sign $money',
                style: AppTextStyles.bodyMd(color: amountColor).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

/// Default time formatter ("08:30 PM"-style for EN, "08:30 م" for AR).
String formatTransactionTime(DateTime when, String languageCode) {
  final fmt = intl.DateFormat('hh:mm a', languageCode);
  return fmt.format(when);
}
