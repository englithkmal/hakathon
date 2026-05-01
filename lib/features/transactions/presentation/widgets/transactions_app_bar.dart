import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../home/presentation/widgets/home_app_bar.dart';
import '../../../notifications/presentation/widgets/notifications_bell.dart';

/// Top bar shown on the Transactions screen — same anatomy as the home
/// app-bar (avatar at start, title, bell at end) but with the screen's
/// own headline.
class TransactionsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TransactionsAppBar({
    super.key,
    required this.user,
    required this.onNotificationsTap,
  });

  final UserModel? user;
  final VoidCallback onNotificationsTap;

  @override
  Size get preferredSize => const Size.fromHeight(AppDimens.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppDimens.appBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.mobileMargin,
              ),
              child: Row(
                children: [
                  HomeUserAvatar(user: user),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: Text(
                      context.tr(AppStrings.transactionsTitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineMd(
                        color: scheme.primary,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 26 / 20,
                      ),
                    ),
                  ),
                  NotificationsBell(
                    onTap: onNotificationsTap,
                    iconColor: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
