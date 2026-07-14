import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../utils/home_money.dart' show kHomeMoneyFormat;

/// Standalone card that surfaces the user's "total balance" in the
/// big-number style of the original Figma reference, with a smaller
/// "total income" line above it for context.
///
/// Lives directly above [HomeBalanceCard] so the user always sees the
/// at-a-glance net cash figure, while the more detailed budget
/// breakdown stays underneath.
///
/// The eye toggle masks the digits with bullets (`••••••`) — useful
/// when the user is showing the screen to someone or recording it.
/// The masked state is local to this widget; toggling it doesn't
/// persist between cold starts (which mirrors how most banking apps
/// behave in the same situation).
class HomeTotalBalanceCard extends StatefulWidget {
  const HomeTotalBalanceCard({
    super.key,
    required this.balance,
    required this.totalIncome,
    required this.currency,
  });

  final double balance;
  final double totalIncome;
  final String currency;

  @override
  State<HomeTotalBalanceCard> createState() => _HomeTotalBalanceCardState();
}

class _HomeTotalBalanceCardState extends State<HomeTotalBalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balanceText = _hidden
        ? '••••••'
        : kHomeMoneyFormat.format(widget.balance);
    final incomeText = _hidden
        ? '••••'
        : kHomeMoneyFormat.format(widget.totalIncome);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small "total income" line on top — gives the headline
                // balance some context (income earned this period).
                _SmallStat(
                  label: context.tr(AppStrings.homeTotalIncome),
                  currency: widget.currency,
                  value: incomeText,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr(AppStrings.homeTotalBalance),
                  style: AppTextStyles.labelSm(color: scheme.outline),
                ),
                const SizedBox(height: AppSpacing.xs),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          widget.currency,
                          style: AppTextStyles.labelMd(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          balanceText,
                          style: AppTextStyles.headlineXl(
                            color: scheme.primary,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr(
              _hidden
                  ? AppStrings.homeBalanceShow
                  : AppStrings.homeBalanceHide,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              minimumSize: const Size(40, 40),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "label + currency + amount" line used for the secondary
/// figure rendered above the headline balance.
class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.label,
    required this.currency,
    required this.value,
    required this.color,
  });

  final String label;
  final String currency;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSm(color: scheme.outline),
        ),
        const SizedBox(width: AppSpacing.xs),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currency,
                style: AppTextStyles.labelSm(color: color),
              ),
              const SizedBox(width: 3),
              Text(
                value,
                style: AppTextStyles.bodyMd(color: color)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
