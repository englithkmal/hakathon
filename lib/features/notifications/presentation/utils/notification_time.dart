import '../../../../core/constants/app_strings.dart';

/// Builds a localised "X minutes ago"-style label using only the
/// translation keys we control. Not as feature-rich as `timeago` but it's
/// free of extra dependencies and respects the app's localisation layer.
({String key, Map<String, Object?>? params}) notificationRelativeTime(
  DateTime when,
) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) {
    return (key: AppStrings.notificationsTimeJustNow, params: null);
  }
  if (diff.inMinutes < 60) {
    return (
      key: AppStrings.notificationsTimeMinutesAgo,
      params: {'n': diff.inMinutes.toString()},
    );
  }
  if (diff.inHours < 24) {
    return (
      key: AppStrings.notificationsTimeHoursAgo,
      params: {'n': diff.inHours.toString()},
    );
  }
  return (
    key: AppStrings.notificationsTimeDaysAgo,
    params: {'n': diff.inDays.toString()},
  );
}
