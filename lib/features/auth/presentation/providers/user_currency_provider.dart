import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../home/presentation/providers/dashboard_provider.dart';
import 'auth_provider.dart';

/// Single source of truth for "what currency does this user use?".
///
/// **The API owns this value, not the app.** We never store a local
/// preference; we just surface whatever the backend last returned. The
/// resolution order tries the most-live API source first:
///
///  1. `GET /dashboard` (`dashboard.currency`) — refreshed on every
///     home open / pull-to-refresh, so it tracks server changes
///     immediately,
///  2. `GET /auth/me` (`user.currency`) — same value, just from the
///     auth payload; used while the dashboard isn't loaded yet,
///  3. [AppConstants.defaultCurrency] — only as a hard fallback if
///     both API responses are missing the field. Should never be hit
///     against a healthy backend.
///
/// Use this anywhere you need a default currency for **new** resources
/// (creating a budget, a saving goal, an inline transaction…).
/// Existing resources must always render with their own
/// `currency` field — they may have been created when the user was on
/// a different currency, and the value lives on the resource itself.
final userCurrencyProvider = Provider<String>((ref) {
  final dashCurrency =
      ref.watch(dashboardProvider).valueOrNull?.dashboard.currency;
  if (dashCurrency != null && dashCurrency.trim().isNotEmpty) {
    return dashCurrency.trim();
  }

  final auth = ref.watch(authProvider);
  if (auth is AuthAuthenticated) {
    final c = auth.user?.currency;
    if (c != null && c.trim().isNotEmpty) return c.trim();
  }
  return AppConstants.defaultCurrency;
});
