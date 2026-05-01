import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';

/// Notifications screen app-bar.
///
/// Layout (start → end, RTL/LTR aware):
///   [back arrow] [title]      [Mark all as read]
///
/// `Mark all as read` only renders when there's something to mark — we
/// gate it from the screen via [showMarkAllRead] to avoid flicker after
/// the bulk action completes.
class NotificationsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const NotificationsAppBar({
    super.key,
    required this.onBack,
    required this.onMarkAllRead,
    required this.showMarkAllRead,
  });

  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;
  final bool showMarkAllRead;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppDimens.appBarHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.sm,
              end: AppSpacing.mobileMargin,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                  ),
                ),
                Text(
                  context.tr(AppStrings.notificationsTitle),
                  style: AppTextStyles.headlineMd(color: scheme.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (showMarkAllRead)
                  TextButton(
                    onPressed: onMarkAllRead,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.outline,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      context.tr(AppStrings.notificationsMarkAllRead),
                      style: AppTextStyles.labelMd(color: scheme.outline)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
