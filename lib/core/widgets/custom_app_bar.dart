import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../theme/text_styles.dart';

/// Shared top app bar used across the four primary tabs.
///
/// Layout (in RTL): `[avatar  title]            [notifications]`
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.leadingAvatar,
    this.onNotificationsTap,
    this.actions,
    this.showNotifications = true,
  });

  final String title;
  final Widget? leadingAvatar;
  final VoidCallback? onNotificationsTap;
  final List<Widget>? actions;
  final bool showNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      titleSpacing: AppSpacing.mobileMargin,
      title: Row(
        children: [
          leadingAvatar ?? _DefaultAvatar(theme: theme),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headlineMd(color: theme.colorScheme.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (showNotifications)
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            color: theme.colorScheme.primary,
            onPressed: onNotificationsTap,
            tooltip: 'Notifications',
          ),
        ...?actions,
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimens.avatarSm,
      height: AppDimens.avatarSm,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: AppIconSize.md,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
