import 'package:flutter/foundation.dart';

import '../../../../core/routes/route_names.dart';

/// Resolves a backend-supplied deeplink to a path the app's GoRouter
/// can actually handle.
///
/// Inputs come from two places:
/// * `notification.deeplink` on rows pulled from `GET /alerts`.
/// * The `data.deeplink` (or matching well-known keys) on FCM
///   payloads — `monthly_summary_ready`, `goal_off_track`,
///   `tip_*`, etc.
///
/// We map known nested resources onto their detail screens when the
/// app already implements them, otherwise we fall back to the closest
/// parent tab so the user always lands on something useful instead of
/// a 404. Truly unknown links return `null` so the caller knows to
/// skip navigation entirely.
String? resolveNotificationDeeplink(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // Strip query/hash fragments before matching segments.
  final cleaned = trimmed.split('?').first.split('#').first;
  final segments = cleaned.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;

  final root = '/${segments.first}';

  // 1. Exact matches for the routes the app already knows about.
  switch (cleaned) {
    case RouteNames.homePath:
    case RouteNames.transactionsPath:
    case RouteNames.budgetPath:
    case RouteNames.profilePath:
    case RouteNames.notificationsPath:
    case RouteNames.monthlySummariesPath:
    case RouteNames.insightsExpensePath:
    case RouteNames.budgetsHistoryPath:
      return cleaned;
  }

  // 2. Nested paths — prefer detail screens when the app supports
  //    them; otherwise map to the parent tab so the user lands
  //    somewhere sensible instead of a 404.
  switch (root) {
    // /monthly-summaries/{year}/{month} → detail screen.
    // /monthly-summaries                → list screen (handled above).
    case '/monthly-summaries':
      if (segments.length >= 3) {
        final year = int.tryParse(segments[1]);
        final month = int.tryParse(segments[2]);
        if (year != null && month != null) {
          return '/monthly-summaries/$year/$month';
        }
      }
      return RouteNames.monthlySummariesPath;

    // /goals/{id} or /saving-goals/{id} → goal detail screen
    // (lives inside the budget tab today).
    case '/goals':
    case '/savings':
    case '/saving-goals':
      if (segments.length >= 2) {
        final id = int.tryParse(segments[1]);
        if (id != null) return '/budget/goals/$id';
      }
      return RouteNames.budgetPath;

    case RouteNames.budgetPath:
      // /budget/goals/{id} — already in the canonical shape.
      if (segments.length >= 3 && segments[1] == 'goals') {
        final id = int.tryParse(segments[2]);
        if (id != null) return '/budget/goals/$id';
      }
      // /budget/{id} (legacy) → drop into the budget tab; the app
      // doesn't expose a dedicated budget-by-id detail today.
      return RouteNames.budgetPath;

    case RouteNames.transactionsPath:
      // /transactions/{id} — no per-row detail screen yet, but the
      // transactions tab will scroll to the row once we wire that.
      return RouteNames.transactionsPath;

    case '/insights':
      // /insights/expense-analysis → expense analysis screen.
      if (segments.length >= 2 && segments[1] == 'expense-analysis') {
        return RouteNames.insightsExpensePath;
      }
      return null;

    case '/tips':
      // We don't have a tip-detail screen yet — fall back to home so
      // tip-of-the-day pushes still open something.
      return RouteNames.homePath;

    case RouteNames.profilePath:
    case '/settings':
      return RouteNames.profilePath;

    case RouteNames.homePath:
      return RouteNames.homePath;
  }

  if (kDebugMode) {
    debugPrint('[Notifications] unknown deeplink "$raw" — skipping nav.');
  }
  return null;
}

/// Resolves a deeplink from an FCM data payload.
///
/// Looks at the well-known keys we ship server-side
/// (`deeplink`, `screen`, `path`, `route`, `url`) plus the alert
/// `type` so we can pin specific alert types to known routes
/// without the server having to populate `deeplink` for every
/// payload.
String? resolveFcmDeeplink(Map<String, dynamic> data) {
  if (data.isEmpty) return null;

  // 1. Direct deeplink keys ship most of the time. Try them in
  //    decreasing order of specificity.
  for (final key in const ['deeplink', 'path', 'route', 'url', 'screen']) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) {
      final resolved = resolveNotificationDeeplink(v);
      if (resolved != null) return resolved;
    }
  }

  // 2. Some payloads ship structured fields the resolver can use to
  //    synthesise a deeplink. The new monthly_summary_ready FCM
  //    payload, for instance, ships `{year, month}` on `data` so we
  //    can route even when `deeplink` is missing.
  final type = (data['type'] ?? data['notification_type'] ?? '')
      .toString()
      .toLowerCase();
  switch (type) {
    case 'monthly_summary_ready':
      final year = _parseInt(data['year']);
      final month = _parseInt(data['month']);
      if (year != null && month != null) {
        return '/monthly-summaries/$year/$month';
      }
      // Fall back to the list when we don't have year/month.
      return RouteNames.monthlySummariesPath;

    case 'goal_off_track':
    case 'goal_milestone':
    case 'goal_completed':
      final id = _parseInt(data['saving_goal_id'] ?? data['goal_id']);
      if (id != null) return '/budget/goals/$id';
      return RouteNames.budgetPath;

    case 'budget_threshold':
    case 'overspending':
      return RouteNames.budgetPath;

    case 'tip':
    case 'daily_tip':
      return RouteNames.homePath;
  }

  return null;
}

int? _parseInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
