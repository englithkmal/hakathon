import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../transactions/presentation/widgets/category_icon.dart';
import '../../data/models/dashboard_model.dart';
import '../utils/home_money.dart';

/// "أحدث المعاملات" section. Displays each transaction inside its own
/// rounded card (instead of a shared list container) to match the new
/// Figma layout.
class HomeRecentTransactionsSection extends StatelessWidget {
  const HomeRecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.languageCode,
    required this.fallbackCurrency,
  });

  final List<DashboardTransaction> transactions;
  final String languageCode;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(AppStrings.homeRecentTransactions),
                  style: AppTextStyles.headlineMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.go(RouteNames.transactionsPath),
                child: Text(
                  context.tr(AppStrings.commonViewAll),
                  style: AppTextStyles.labelMd(color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (preview.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Text(
              context.tr(AppStrings.transactionsEmpty),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (var i = 0; i < preview.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _TransactionCard(
              tx: preview[i],
              languageCode: languageCode,
              fallbackCurrency: fallbackCurrency,
            ),
          ],
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.tx,
    required this.languageCode,
    required this.fallbackCurrency,
  });

  final DashboardTransaction tx;
  final String languageCode;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = tx.type == 'income';
    final accent = categoryAccentColor(tx.category.color);
    final iconBg = isIncome
        ? scheme.secondaryContainer
        : (accent != null
            ? accent.withValues(alpha: 0.18)
            : scheme.errorContainer);
    final iconFg = isIncome
        ? scheme.onSecondaryContainer
        : (accent ?? scheme.onErrorContainer);

    final amountColor = isIncome ? scheme.primary : scheme.error;
    final sign = isIncome ? '+' : '−';
    final currency = tx.currency.isNotEmpty ? tx.currency : fallbackCurrency;

    final title = tx.description.isNotEmpty
        ? tx.description
        : tx.category.displayName(languageCode);
    final categoryLabel = tx.category.displayName(languageCode);

    final when = DateTime.tryParse(tx.transactionDate)?.toLocal();
    final timeLabel = when != null ? _timeLabel(when, languageCode) : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
                  style: AppTextStyles.bodyMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel.isNotEmpty
                      ? timeLabel
                      : categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm(color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '$sign ${formatHomeMoney(tx.amount.abs(), currency)}',
                  style: AppTextStyles.bodyMd(color: amountColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                categoryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSm(color: scheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "اليوم، 02:30 م" / "Today, 02:30 PM" — falls back to a date when
  /// the transaction is older than yesterday.
  String _timeLabel(DateTime when, String lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDay = DateTime(when.year, when.month, when.day);
    final diff = today.difference(txDay).inDays;

    final time = intl.DateFormat('hh:mm a', lang).format(when);
    if (diff == 0) {
      return '${_translate(lang, today: 'اليوم', en: 'Today')}، $time';
    }
    if (diff == 1) {
      return '${_translate(lang, today: 'أمس', en: 'Yesterday')}، $time';
    }
    final dateLabel = intl.DateFormat('d MMM', lang).format(when);
    return '$dateLabel، $time';
  }

  String _translate(String lang, {required String today, required String en}) =>
      lang == 'ar' ? today : en;
}
