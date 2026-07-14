import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../data/models/notification_model.dart';
import '../utils/notification_time.dart';
import 'notification_visuals.dart';

/// Generic rounded card used by every notification kind. Type-specific
/// extras (progress bar, action button, etc.) are passed in as
/// [extraContent] so the chrome lives in one place.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.languageCode,
    required this.onTap,
    this.extraContent,
  });

  final NotificationModel notification;
  final String languageCode;
  final VoidCallback? onTap;
  final Widget? extraContent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visuals = notificationVisualsFor(context, notification);
    final time = notificationRelativeTime(notification.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: visuals.cardBackground,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: visuals.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBubble(visuals: visuals),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TitleAndTime(
                          notification: notification,
                          languageCode: languageCode,
                          timeKey: time.key,
                          timeParams: time.params,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          notification.displayMessage(languageCode),
                          style: AppTextStyles.bodySm(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _UnreadDot(color: scheme.primary),
                  ],
                ],
              ),
              if (extraContent != null) ...[
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                extraContent!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.visuals});

  final NotificationVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: visuals.iconBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(visuals.icon, size: 20, color: visuals.iconForeground),
    );
  }
}

class _TitleAndTime extends StatelessWidget {
  const _TitleAndTime({
    required this.notification,
    required this.languageCode,
    required this.timeKey,
    required this.timeParams,
  });

  final NotificationModel notification;
  final String languageCode;
  final String timeKey;
  final Map<String, Object?>? timeParams;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            notification.displayTitle(languageCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMd(color: scheme.onSurface)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          context.tr(timeKey, params: timeParams),
          style: AppTextStyles.labelSm(color: scheme.outline),
        ),
      ],
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Re-usable progress strip used by the goal-milestone card. Lives here
/// so the standalone card and any future inline use share the visual.
class NotificationProgressBar extends StatelessWidget {
  const NotificationProgressBar({
    super.key,
    required this.percent,
    required this.currentLabel,
    required this.targetLabel,
    required this.percentLabelKey,
  });

  final double percent;
  final String currentLabel;
  final String targetLabel;
  final String percentLabelKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              context.tr(
                percentLabelKey,
                params: {'pct': '${(percent * 100).round()}'},
              ),
              style: AppTextStyles.labelSm(color: scheme.primary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '$targetLabel / $currentLabel',
                style: AppTextStyles.labelSm(color: scheme.outline),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: scheme.surfaceContainerHigh),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: Container(color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// CTA button used by the budget-alert card.
class NotificationCtaButton extends StatelessWidget {
  const NotificationCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        minimumSize: const Size.fromHeight(44),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMd(color: scheme.onSurface)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Wraps [NotificationCard] with a goal-milestone progress strip beneath
/// the body text.
class GoalMilestoneNotificationCard extends StatelessWidget {
  const GoalMilestoneNotificationCard({
    super.key,
    required this.notification,
    required this.languageCode,
    required this.fallbackCurrency,
    required this.onTap,
  });

  final NotificationModel notification;
  final String languageCode;
  final String fallbackCurrency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final payload = notification.goalPayload;
    if (payload == null) {
      return NotificationCard(
        notification: notification,
        languageCode: languageCode,
        onTap: onTap,
      );
    }

    final percent = payload.targetAmount > 0
        ? (payload.currentAmount / payload.targetAmount).clamp(0.0, 1.0)
        : (payload.progressPercentage / 100).clamp(0.0, 1.0);

    final currency =
        payload.currency.isNotEmpty ? payload.currency : fallbackCurrency;

    return NotificationCard(
      notification: notification,
      languageCode: languageCode,
      onTap: onTap,
      extraContent: NotificationProgressBar(
        percent: percent.toDouble(),
        currentLabel: '${_money(payload.currentAmount)} $currency',
        targetLabel: '${_money(payload.targetAmount)} $currency',
        percentLabelKey: AppStrings.notificationsGoalProgressLabel,
      ),
    );
  }
}

/// Wraps [NotificationCard] with the "review budget" CTA underneath.
class BudgetAlertNotificationCard extends StatelessWidget {
  const BudgetAlertNotificationCard({
    super.key,
    required this.notification,
    required this.languageCode,
    required this.onTap,
    required this.onReviewBudget,
  });

  final NotificationModel notification;
  final String languageCode;
  final VoidCallback? onTap;
  final VoidCallback onReviewBudget;

  @override
  Widget build(BuildContext context) {
    return NotificationCard(
      notification: notification,
      languageCode: languageCode,
      onTap: onTap,
      extraContent: NotificationCtaButton(
        label: context.tr(AppStrings.notificationsBudgetReviewCta),
        onPressed: onReviewBudget,
      ),
    );
  }
}

/// Shorter formatting tuned for compact pills/labels. Falls back to a
/// best-effort "1,234" when intl isn't preferred (keeps file lean).
String _money(double v) {
  final whole = v.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
