import '../../../../core/constants/app_strings.dart';
import '../../data/models/notification_model.dart';

/// Date grouping bucket used in the notifications screen.
class NotificationDateGroup {
  const NotificationDateGroup({
    required this.titleKey,
    required this.items,
  });

  final String titleKey;
  final List<NotificationModel> items;
}

/// Splits a flat notifications list into the four buckets the design
/// uses: Today / Yesterday / This week / Older. Empty buckets are
/// skipped so we never render a stray header.
List<NotificationDateGroup> groupNotificationsByDate(
  List<NotificationModel> items,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(const Duration(days: 7));

  final todays = <NotificationModel>[];
  final yesterdays = <NotificationModel>[];
  final thisWeek = <NotificationModel>[];
  final older = <NotificationModel>[];

  for (final n in items) {
    final created = n.createdAt;
    final day = DateTime(created.year, created.month, created.day);
    if (!day.isBefore(today)) {
      todays.add(n);
    } else if (!day.isBefore(yesterday)) {
      yesterdays.add(n);
    } else if (day.isAfter(weekStart)) {
      thisWeek.add(n);
    } else {
      older.add(n);
    }
  }

  return [
    if (todays.isNotEmpty)
      NotificationDateGroup(
        titleKey: AppStrings.notificationsGroupToday,
        items: todays,
      ),
    if (yesterdays.isNotEmpty)
      NotificationDateGroup(
        titleKey: AppStrings.notificationsGroupYesterday,
        items: yesterdays,
      ),
    if (thisWeek.isNotEmpty)
      NotificationDateGroup(
        titleKey: AppStrings.notificationsGroupThisWeek,
        items: thisWeek,
      ),
    if (older.isNotEmpty)
      NotificationDateGroup(
        titleKey: AppStrings.notificationsGroupOlder,
        items: older,
      ),
  ];
}
