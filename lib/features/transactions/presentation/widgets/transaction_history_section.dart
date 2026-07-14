import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/transaction_model.dart';
import 'transaction_item.dart';

/// "سجل العمليات" / "Recent activity" — bucketed list grouped by
/// "Today", "Yesterday" and then by date.
class TransactionHistorySection extends StatelessWidget {
  const TransactionHistorySection({
    super.key,
    required this.transactions,
    required this.languageCode,
  });

  final List<TransactionModel> transactions;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            context.tr(AppStrings.transactionsEmpty),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final groups = _groupByDay(transactions);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    String labelFor(DateTime day) {
      if (_sameDay(day, today)) {
        return context.tr(AppStrings.transactionsToday);
      }
      if (_sameDay(day, yesterday)) {
        return context.tr(AppStrings.transactionsYesterday);
      }
      return intl.DateFormat('EEEE، d MMM', languageCode).format(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            context.tr(AppStrings.transactionsHistory),
            style: AppTextStyles.headlineMd(color: scheme.onSurface).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _DayBucket(
            label: labelFor(groups[i].day),
            items: groups[i].items,
            languageCode: languageCode,
          ),
        ],
      ],
    );
  }

  static List<_DayGroup> _groupByDay(List<TransactionModel> txs) {
    final byDay = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      final parsed = DateTime.tryParse(tx.transactionDate)?.toLocal() ??
          DateTime.now();
      final day = DateTime(parsed.year, parsed.month, parsed.day);
      byDay.putIfAbsent(day, () => []).add(tx);
    }
    final entries = byDay.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries.map((e) => _DayGroup(day: e.key, items: e.value)).toList();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayGroup {
  const _DayGroup({required this.day, required this.items});

  final DateTime day;
  final List<TransactionModel> items;
}

class _DayBucket extends StatelessWidget {
  const _DayBucket({
    required this.label,
    required this.items,
    required this.languageCode,
  });

  final String label;
  final List<TransactionModel> items;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMd(color: scheme.outline),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.surfaceContainerHighest,
                  ),
                TransactionItem(
                  transaction: items[i],
                  languageCode: languageCode,
                  formatTime: (when) =>
                      formatTransactionTime(when, languageCode),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
