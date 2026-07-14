import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';

/// Visual descriptor consumed by the rendered notification cards.
///
/// Centralised so every card resolves the icon/colours from the same
/// place and we can extend the design without scattering switches across
/// widgets.
class NotificationVisuals {
  const NotificationVisuals({
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.cardBorder,
    required this.cardBackground,
    required this.usesPrimaryAccent,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final Color cardBorder;
  final Color cardBackground;
  final bool usesPrimaryAccent;
}

NotificationVisuals notificationVisualsFor(
  BuildContext context,
  NotificationModel n,
) {
  final scheme = Theme.of(context).colorScheme;

  switch (n.type) {
    case NotificationType.tip:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.lightbulb_outline_rounded),
        iconBackground: scheme.primary.withValues(alpha: 0.14),
        iconForeground: scheme.primary,
        cardBorder: scheme.primary.withValues(alpha: 0.18),
        cardBackground: scheme.primaryContainer.withValues(alpha: 0.16),
        usesPrimaryAccent: true,
      );
    case NotificationType.goalMilestone:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.emoji_events_outlined),
        iconBackground: scheme.primary.withValues(alpha: 0.14),
        iconForeground: scheme.primary,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.55),
        cardBackground: scheme.surfaceContainerLowest,
        usesPrimaryAccent: false,
      );
    case NotificationType.budgetAlert:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.warning_amber_rounded),
        iconBackground: scheme.error.withValues(alpha: 0.14),
        iconForeground: scheme.error,
        cardBorder: scheme.error.withValues(alpha: 0.55),
        cardBackground: scheme.surfaceContainerLowest,
        usesPrimaryAccent: false,
      );
    case NotificationType.bankSync:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.refresh_rounded),
        iconBackground: scheme.surfaceContainerHigh,
        iconForeground: scheme.onSurfaceVariant,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.55),
        cardBackground: scheme.surfaceContainerLowest,
        usesPrimaryAccent: false,
      );
    case NotificationType.transaction:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.swap_horiz_rounded),
        iconBackground: scheme.surfaceContainerHigh,
        iconForeground: scheme.onSurfaceVariant,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.55),
        cardBackground: scheme.surfaceContainerLowest,
        usesPrimaryAccent: false,
      );
    case NotificationType.system:
    case NotificationType.unknown:
      return NotificationVisuals(
        icon: _iconFor(n.icon, fallback: Icons.info_outline_rounded),
        iconBackground: scheme.surfaceContainerHigh,
        iconForeground: scheme.onSurfaceVariant,
        cardBorder: scheme.outlineVariant.withValues(alpha: 0.55),
        cardBackground: scheme.surfaceContainerLowest,
        usesPrimaryAccent: false,
      );
  }
}

/// Maps the heroicon-style key the backend stores onto a Material icon.
/// We're conservative — unknown keys fall back to the supplied default.
IconData _iconFor(String rawKey, {required IconData fallback}) {
  final key = rawKey.toLowerCase();
  if (key.contains('light-bulb') || key.contains('bulb')) {
    return Icons.lightbulb_outline_rounded;
  }
  if (key.contains('trophy') || key.contains('star')) {
    return Icons.emoji_events_outlined;
  }
  if (key.contains('exclamation') || key.contains('warning')) {
    return Icons.warning_amber_rounded;
  }
  if (key.contains('refresh') || key.contains('arrow-path') ||
      key.contains('sync')) {
    return Icons.refresh_rounded;
  }
  if (key.contains('shield')) return Icons.verified_user_outlined;
  if (key.contains('wallet') || key.contains('cash')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (key.contains('chart')) return Icons.bar_chart_rounded;
  if (key.contains('cog')) return Icons.settings_outlined;
  if (key.contains('information') || key.contains('info')) {
    return Icons.info_outline_rounded;
  }
  return fallback;
}
