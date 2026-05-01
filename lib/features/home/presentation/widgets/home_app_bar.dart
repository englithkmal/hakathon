import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../notifications/presentation/widgets/notifications_bell.dart';

/// Top bar for the redesigned home screen.
///
/// Layout (start → end, RTL/LTR aware):
///   [avatar]  [bell]   …flexible spacer…   [Save pill]
///
/// The personalised greeting moves to the headline of the balance card
/// instead of living in the app-bar like the previous revision.
class HomeFigmaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeFigmaAppBar({
    super.key,
    required this.user,
    required this.onNotificationsTap,
    required this.onQuickSaveTap,
  });

  final UserModel? user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onQuickSaveTap;

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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.mobileMargin,
            ),
            child: Row(
              children: [
                HomeUserAvatar(user: user),
                const SizedBox(width: AppSpacing.sm),
                NotificationsBell(onTap: onNotificationsTap),
                const Spacer(),
                _QuickSavePill(onTap: onQuickSaveTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickSavePill extends StatelessWidget {
  const _QuickSavePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.savings_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                context.tr(AppStrings.homeQuickAddSaving),
                style: AppTextStyles.labelMd(
                  color: scheme.primary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round avatar (image or fallback initial) used by the home app-bar.
class HomeUserAvatar extends StatelessWidget {
  const HomeUserAvatar({super.key, this.user});

  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = user?.avatarUrl;
    final initial = _initialLetter(user);

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: AppDimens.avatarSm,
          height: AppDimens.avatarSm,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(theme, initial),
        ),
      );
    }
    return _fallback(theme, initial);
  }

  Widget _fallback(ThemeData theme, String letter) {
    return Container(
      width: AppDimens.avatarSm,
      height: AppDimens.avatarSm,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTextStyles.labelLg(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initialLetter(UserModel? user) {
    final name = user?.name?.trim();
    if (name != null && name.isNotEmpty) {
      final it = name.runes.iterator;
      if (it.moveNext()) {
        return String.fromCharCode(it.current).toUpperCase();
      }
    }
    final phone = user?.phoneE164 ?? '';
    if (phone.isNotEmpty) {
      final digit = RegExp(r'\d').firstMatch(phone);
      return digit != null ? phone[digit.start] : '?';
    }
    return '?';
  }
}
