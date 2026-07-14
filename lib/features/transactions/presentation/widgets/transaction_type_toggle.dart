import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Visual variants for [TransactionTypeToggle]. The original `green`
/// variant is used inside the inline add-transaction card. The newer
/// `light` variant matches the full-screen add-transaction sheet where
/// the active slot has a white pill on a light grey background.
enum TransactionTypeToggleVariant { green, light }

/// Pill-style segmented control with two slots: "Expense" and "Income".
/// Sits at the top of the add-transaction surfaces and decides which
/// set of categories the picker below should show.
class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.variant = TransactionTypeToggleVariant.green,
  });

  /// Active type: `'expense'` or `'income'`.
  final String value;
  final ValueChanged<String> onChanged;
  final TransactionTypeToggleVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _ToggleSlot(
            label: context.tr(AppStrings.transactionsTypeExpense),
            isActive: value == 'expense',
            variant: variant,
            onTap: () => onChanged('expense'),
          ),
          _ToggleSlot(
            label: context.tr(AppStrings.transactionsTypeIncome),
            isActive: value == 'income',
            variant: variant,
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ToggleSlot extends StatelessWidget {
  const _ToggleSlot({
    required this.label,
    required this.isActive,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final TransactionTypeToggleVariant variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // In dark mode `surfaceContainerLowest` is *darker* than the rail
    // (`surfaceContainerHigh`), which makes the active pill look sunken
    // and creates the harsh contrast border visible in the Figma
    // dark-mode export. Pick the highest tonal step in dark and the
    // lowest in light so the active slot always sits one elevation
    // above the rail with a smooth, soft transition.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = switch (variant) {
      TransactionTypeToggleVariant.green => scheme.primary,
      TransactionTypeToggleVariant.light => isDark
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLowest,
    };
    final activeFg = switch (variant) {
      TransactionTypeToggleVariant.green => scheme.onPrimary,
      TransactionTypeToggleVariant.light => scheme.onSurface,
    };
    // The "light" variant ships without a shadow to match the Figma
    // reference (clean white pill on a light grey rail). The "green"
    // variant keeps a soft tinted shadow because the primary colour
    // benefits from a tiny lift on busy backgrounds.
    final boxShadow = switch (variant) {
      TransactionTypeToggleVariant.green when isActive => [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.16),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      _ => const <BoxShadow>[],
    };

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: boxShadow,
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMd(
                color: isActive ? activeFg : scheme.onSurfaceVariant,
              ).copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
