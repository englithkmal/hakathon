import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Empty-state used both as a full-screen placeholder when the list is
/// empty (`isFullScreen=true`) and as the bottom "no older notifications"
/// hint at the end of the scrollable list (`isFullScreen=false`).
class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({
    super.key,
    this.isFullScreen = true,
  });

  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isFullScreen ? AppSpacing.xxl : AppSpacing.lg,
        horizontal: AppSpacing.mobileMargin,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: AppRadius.brMd,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_none_rounded,
              size: 30,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            context.tr(
              isFullScreen
                  ? AppStrings.notificationsEmptyTitle
                  : AppStrings.notificationsNoOlder,
            ),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMd(color: scheme.outline),
          ),
          if (isFullScreen) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr(AppStrings.notificationsEmptySubtitle),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: scheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}
