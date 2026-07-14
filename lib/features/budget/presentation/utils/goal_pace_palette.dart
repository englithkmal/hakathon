import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../data/models/saving_goal_model.dart';

/// Color + label pair the UI uses to render a `pace.status` chip.
///
/// The palette is intentionally kept here (not in `AppColors`) so the
/// goal feature owns its semantic mapping — adding a new pace state
/// only requires touching this file plus the localization keys.
class GoalPaceVisuals {
  const GoalPaceVisuals({
    required this.foreground,
    required this.background,
    required this.icon,
    required this.label,
  });

  final Color foreground;
  final Color background;
  final IconData icon;
  final String label;
}

GoalPaceVisuals goalPaceVisuals(
  BuildContext context,
  GoalPaceStatus status,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case GoalPaceStatus.ahead:
      return GoalPaceVisuals(
        foreground: AppColors.green700,
        background: AppColors.green100,
        icon: Icons.trending_up_rounded,
        label: context.tr(AppStrings.goalPaceAhead),
      );
    case GoalPaceStatus.onTrack:
      return GoalPaceVisuals(
        foreground: AppColors.teal700,
        background: AppColors.teal100,
        icon: Icons.check_circle_outline_rounded,
        label: context.tr(AppStrings.goalPaceOnTrack),
      );
    case GoalPaceStatus.offTrack:
      return GoalPaceVisuals(
        foreground: AppColors.amber700,
        background: AppColors.amber100,
        icon: Icons.warning_amber_rounded,
        label: context.tr(AppStrings.goalPaceOffTrack),
      );
    case GoalPaceStatus.inactive:
      return GoalPaceVisuals(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHigh,
        icon: Icons.pause_circle_outline_rounded,
        label: context.tr(AppStrings.goalPaceInactive),
      );
    case GoalPaceStatus.unscheduled:
      return GoalPaceVisuals(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainer,
        icon: Icons.event_busy_rounded,
        label: context.tr(AppStrings.goalPaceUnscheduled),
      );
    case GoalPaceStatus.unknown:
      return GoalPaceVisuals(
        foreground: scheme.onSurfaceVariant,
        background: scheme.surfaceContainer,
        icon: Icons.help_outline_rounded,
        label: '',
      );
  }
}

/// Border accent used to color goal cards. Returns `null` for states
/// where the default outline is preferable (e.g. unknown / inactive).
Color? goalPaceBorder(BuildContext context, GoalPaceStatus status) {
  switch (status) {
    case GoalPaceStatus.ahead:
      return AppColors.green500;
    case GoalPaceStatus.onTrack:
      return AppColors.teal500;
    case GoalPaceStatus.offTrack:
      return AppColors.amber500;
    case GoalPaceStatus.inactive:
    case GoalPaceStatus.unscheduled:
    case GoalPaceStatus.unknown:
      return null;
  }
}
