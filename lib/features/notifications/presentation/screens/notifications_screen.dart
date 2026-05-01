import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../auth/presentation/providers/user_currency_provider.dart';
import '../../data/models/notification_model.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_deeplink.dart';
import '../utils/notification_groups.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_group_header.dart';
import '../widgets/notifications_app_bar.dart';
import '../widgets/notifications_empty_state.dart';

/// Notifications list. Pulls data from [notificationsProvider] and
/// renders the date-grouped layout from the Figma design.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_maybeLoadMore);
    // Always re-fetch on entry so the user sees notifications that
    // landed while the screen was off-stage — without forcing them
    // to pull-to-refresh. The existing `refresh()` keeps the previous
    // list visible during the fetch via `copyWithPrevious`, so this
    // doesn't flash an empty state on warm re-enters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    // Trigger when within 240px of the bottom — gives the network call a
    // head-start before the user reaches the end.
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asyncState = ref.watch(notificationsProvider);
    final lang = ref.watch(localeProvider).languageCode;
    // Single resolver: prefers `/dashboard.currency`, falls back to
    // the cached user. Keeps server as the source of truth.
    final fallbackCurrency = ref.watch(userCurrencyProvider);

    final state = asyncState.valueOrNull;
    final showMarkAll = (state?.unreadCount ?? 0) > 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: NotificationsAppBar(
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.homePath);
          }
        },
        showMarkAllRead: showMarkAll,
        onMarkAllRead: () async {
          await ref.read(notificationsProvider.notifier).markAllRead();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(AppStrings.notificationsAllReadSnack)),
            ),
          );
        },
      ),
      body: asyncState.when(
        data: (state) => _NotificationsBody(
          controller: _controller,
          state: state,
          languageCode: lang,
          fallbackCurrency: fallbackCurrency,
          onRefresh: () =>
              ref.read(notificationsProvider.notifier).refresh(),
          onTapNotification: (n) async {
            // Mark as read first, then follow the deeplink if it resolves
            // to a route the app actually has wired up.
            await ref.read(notificationsProvider.notifier).markRead(n.id);
            if (!context.mounted) return;
            final resolved = resolveNotificationDeeplink(n.deeplink);
            if (resolved != null) context.go(resolved);
          },
          onReviewBudget: (n) {
            ref.read(notificationsProvider.notifier).markRead(n.id);
            final resolved = resolveNotificationDeeplink(n.deeplink) ??
                RouteNames.budgetPath;
            context.go(resolved);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.controller,
    required this.state,
    required this.languageCode,
    required this.fallbackCurrency,
    required this.onRefresh,
    required this.onTapNotification,
    required this.onReviewBudget,
  });

  final ScrollController controller;
  final NotificationsState state;
  final String languageCode;
  final String fallbackCurrency;
  final Future<void> Function() onRefresh;
  final void Function(NotificationModel) onTapNotification;
  final void Function(NotificationModel) onReviewBudget;

  @override
  Widget build(BuildContext context) {
    final groups = groupNotificationsByDate(state.items);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.mobileMargin,
          AppSpacing.sm,
          AppSpacing.mobileMargin,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
        ),
        children: [
          if (state.items.isEmpty) const NotificationsEmptyState(),
          for (final group in groups) ...[
            NotificationGroupHeader(titleKey: group.titleKey),
            for (var i = 0; i < group.items.length; i++) ...[
              _CardForNotification(
                notification: group.items[i],
                languageCode: languageCode,
                fallbackCurrency: fallbackCurrency,
                onTap: () => onTapNotification(group.items[i]),
                onReviewBudget: () => onReviewBudget(group.items[i]),
              ),
              if (i < group.items.length - 1)
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!state.hasMore && state.items.isNotEmpty)
            const NotificationsEmptyState(isFullScreen: false),
        ],
      ),
    );
  }
}

/// Picks the right card variant for the notification's [type].
class _CardForNotification extends StatelessWidget {
  const _CardForNotification({
    required this.notification,
    required this.languageCode,
    required this.fallbackCurrency,
    required this.onTap,
    required this.onReviewBudget,
  });

  final NotificationModel notification;
  final String languageCode;
  final String fallbackCurrency;
  final VoidCallback onTap;
  final VoidCallback onReviewBudget;

  @override
  Widget build(BuildContext context) {
    switch (notification.type) {
      case NotificationType.goalMilestone:
        return GoalMilestoneNotificationCard(
          notification: notification,
          languageCode: languageCode,
          fallbackCurrency: fallbackCurrency,
          onTap: onTap,
        );
      case NotificationType.budgetAlert:
        return BudgetAlertNotificationCard(
          notification: notification,
          languageCode: languageCode,
          onTap: onTap,
          onReviewBudget: onReviewBudget,
        );
      case NotificationType.tip:
      case NotificationType.bankSync:
      case NotificationType.system:
      case NotificationType.transaction:
      case NotificationType.unknown:
        return NotificationCard(
          notification: notification,
          languageCode: languageCode,
          onTap: onTap,
        );
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mobileMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 36, color: scheme.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.tr(AppStrings.notificationsLoadFailed),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.tr(AppStrings.commonRetry)),
            ),
          ],
        ),
      ),
    );
  }
}
