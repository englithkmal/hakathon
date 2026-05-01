import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Big centered "SAR 0.00" display used at the top of the
/// add-transaction sheet. Uses the primary colour when the user has
/// started typing, dims to a subtle outline tone for the placeholder.
class AddTransactionAmountDisplay extends StatelessWidget {
  const AddTransactionAmountDisplay({
    super.key,
    required this.amountText,
    required this.currency,
  });

  final String amountText;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPlaceholder = amountText == '0' || amountText.isEmpty;
    final formatted = _formatAmount(amountText);
    final color = isPlaceholder
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currency,
                style: AppTextStyles.headlineMd(color: color).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatted,
                    style: AppTextStyles.headlineLg(color: color).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 56,
                      height: 1.05,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.tr(AppStrings.transactionsAmountEnterHint),
          style: AppTextStyles.labelMd(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Mirrors what the user typed but adds thousands grouping for the
  /// integer portion so big values stay readable. Decimal handling is
  /// kept verbatim so trailing dots & partial fractions still show.
  String _formatAmount(String raw) {
    if (raw.isEmpty) return '0.00';
    final dotIdx = raw.indexOf('.');
    final intPart = dotIdx < 0 ? raw : raw.substring(0, dotIdx);
    final fractionPart = dotIdx < 0 ? '' : raw.substring(dotIdx);

    String grouped = intPart;
    if (intPart.length > 3) {
      final buf = StringBuffer();
      for (var i = 0; i < intPart.length; i++) {
        final reversedIdx = intPart.length - i;
        if (i > 0 && reversedIdx % 3 == 0) buf.write(',');
        buf.write(intPart[i]);
      }
      grouped = buf.toString();
    }

    if (fractionPart.isEmpty && raw == intPart) {
      return '$grouped.00';
    }
    return '$grouped$fractionPart';
  }
}
