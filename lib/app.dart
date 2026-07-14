import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/localization/app_localization.dart';
import 'core/localization/locale_provider.dart';
import 'core/notifications/app_notification.dart';
import 'core/notifications/notification_providers.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/devices/application/authenticated_device_service.dart';
import 'features/home/presentation/providers/dashboard_provider.dart';
import 'features/monthly_summaries/presentation/providers/monthly_summaries_provider.dart';
import 'features/notifications/presentation/providers/notifications_provider.dart';
import 'features/notifications/presentation/utils/notification_deeplink.dart';

class WafferApp extends ConsumerStatefulWidget {
  const WafferApp({super.key});

  @override
  ConsumerState<WafferApp> createState() => _WafferAppState();
}

class _WafferAppState extends ConsumerState<WafferApp> {
  @override
  void initState() {
    super.initState();
    // Boot the FCM token-refresh listener for the authenticated device flow.
    // The service is otherwise driven by the `authProvider` listener wired
    // up in [build] below.
    ref.read(authenticatedDeviceServiceProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);

    // Whenever the user transitions into [AuthAuthenticated] (initial login,
    // re-login as a different user, or session restored from cold start),
    // link the current FCM token to their account via `POST /devices/register`
    // so the backend can target them with per-user pushes (alerts, tips,
    // transaction reminders, ...). Without this call only OTP pushes — which
    // carry the FCM token in the request body — make it through, which is
    // the "OTP works but everything else doesn't" symptom.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is! AuthAuthenticated) return;
      final user = next.user;
      // Prefer the authenticated user's id; fall back to phone if the
      // backend ever returns a session without a populated user object.
      final identity = (user?.id.isNotEmpty ?? false)
          ? user!.id
          : next.phoneE164;
      if (identity.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[WafferApp] AuthAuthenticated with no usable user id — '
            'skipping device registration.',
          );
        }
        return;
      }
      ref.read(authenticatedDeviceServiceProvider).onAuthenticated(identity);
    });

    // ─── Push → in-app refresh bridge ─────────────────────────────
    // Whenever an FCM message lands (foreground / background-tap /
    // cold-start tap), poke the notification providers so:
    //   • the bell badge counter updates immediately,
    //   • the notifications screen — if it's the current top route —
    //     re-fetches and renders the new entry without a manual
    //     pull-to-refresh.
    // We use `invalidate` so providers nobody is currently watching
    // stay dormant; they only refetch the next time the user opens
    // a screen that consumes them.
    ref.listen<AsyncValue<AppNotification>>(
      notificationStreamProvider,
      (previous, next) {
        next.whenData((notification) {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);

          // Some FCM types invalidate provider caches even when the
          // user didn't open the notification — e.g. a fresh
          // `monthly_summary_ready` push means the dashboard's
          // `monthly_summary` block is now stale and we want the
          // banner to surface as soon as the home tab is reopened.
          final type = (notification.data['type'] ??
                  notification.data['notification_type'] ??
                  '')
              .toString()
              .toLowerCase();
          if (type == 'monthly_summary_ready') {
            ref.invalidate(dashboardProvider);
            ref.invalidate(monthlySummariesListProvider);
            final yearStr = notification.data['year']?.toString();
            final monthStr = notification.data['month']?.toString();
            final year = int.tryParse(yearStr ?? '');
            final month = int.tryParse(monthStr ?? '');
            if (year != null && month != null) {
              ref.invalidate(
                monthlySummaryProvider(
                  MonthlySummaryKey(year: year, month: month),
                ),
              );
            }
          }

          // Tapped notifications navigate to the resolved deeplink.
          // Foreground messages just refresh caches above so we don't
          // hijack the user's current screen mid-task.
          if (notification.opened) {
            final resolved = resolveFcmDeeplink(notification.data);
            if (resolved != null && resolved.isNotEmpty) {
              router.push(resolved);
            }
          }
        });
      },
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
