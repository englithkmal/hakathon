import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../constants/app_strings.dart';
import '../localization/app_localization.dart';
import '../theme/text_styles.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
  });

  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
}

const List<AppBottomNavItem> kBottomNavItems = [
  AppBottomNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    labelKey: AppStrings.navHome,
  ),
  AppBottomNavItem(
    icon: Icons.pie_chart_outline_rounded,
    activeIcon: Icons.pie_chart_rounded,
    labelKey: AppStrings.navTransactions,
  ),
  AppBottomNavItem(
    icon: Icons.track_changes_outlined,
    activeIcon: Icons.track_changes_rounded,
    labelKey: AppStrings.navBudget,
  ),
  AppBottomNavItem(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    labelKey: AppStrings.navProfile,
  ),
];

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: AppRadius.radiusXl),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: Row(
            children: List.generate(kBottomNavItems.length, (i) {
              final item = kBottomNavItems[i];
              final selected = currentIndex == i;
              return Expanded(
                child: _NavButton(
                  item: item,
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: AppRadius.brLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: AppIconSize.lg,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                context.tr(item.labelKey),
                style: AppTextStyles.labelSm(color: color).copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
