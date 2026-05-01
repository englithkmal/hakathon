import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../providers/notifications_provider.dart';

/// Bell icon button with an unread-count badge. Drop-in replacement for
/// the plain `IconButton(notifications_none_rounded)` previously hard-
/// coded inside each top-level app-bar.
class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({
    super.key,
    this.onTap,
    this.iconColor,
  });

  /// Override the navigation target. Defaults to `/notifications`.
  final VoidCallback? onTap;

  /// Override the bell colour. Defaults to `colorScheme.onSurface`.
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final asyncCount = ref.watch(unreadCountProvider);
    final unread = asyncCount.valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: context.tr(AppStrings.commonNotifications),
          // `push` (not `go`) so the previous tab stays in the navigation
          // stack — without this the system back gesture would exit the
          // app instead of returning to where the user came from.
          onPressed: onTap ?? () => context.push(RouteNames.notificationsPath),
          icon: const Icon(Icons.notifications_none_rounded, size: 24),
          style: IconButton.styleFrom(
            foregroundColor: iconColor ?? scheme.onSurface,
            padding: const EdgeInsets.all(AppSpacing.sm),
          ),
        ),
        if (unread > 0)
          PositionedDirectional(
            top: 6,
            end: 6,
            child: _Badge(count: unread, scheme: scheme),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.scheme});

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          label,
          style: AppTextStyles.labelSm(color: scheme.onError).copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
