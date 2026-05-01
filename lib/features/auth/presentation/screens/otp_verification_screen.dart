import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/otp_input_field.dart';

/// OTP verification — second stop in the auth flow.
///
/// Layout follows the **Serene Finance** spec: sticky white app bar
/// ("رمز التحقق"), a centred two-line title block ("تحقق من رقمك" + the
/// E.164 phone), the multi-box OTP input, an inline resend section, and a
/// sticky bottom confirm button.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final GlobalKey<OtpInputFieldState> _otpKey = GlobalKey<OtpInputFieldState>();
  String _code = '';
  String? _errorText;
  bool _verifying = false;
  bool _resending = false;

  Timer? _resendTimer;
  int _resendSecondsLeft = 0;

  Timer? _expiryTimer;
  int _expirySecondsLeft = 0;
  bool get _isExpired => _expirySecondsLeft <= 0 && _expiryTimer != null;

  @override
  void initState() {
    super.initState();
    final state = ref.read(authProvider);
    if (state is AuthAwaitingOtp) {
      _startResendCountdown(state.cooldownSeconds);
      _startExpiryCountdown(state.expiresIn);
    } else {
      _startResendCountdown(AppConstants.otpResendCooldownFallback);
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendSecondsLeft = seconds);
    if (seconds <= 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  void _startExpiryCountdown(int seconds) {
    _expiryTimer?.cancel();
    if (!mounted) return;
    setState(() => _expirySecondsLeft = seconds);
    if (seconds <= 0) return;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_expirySecondsLeft <= 1) {
        timer.cancel();
        setState(() => _expirySecondsLeft = 0);
      } else {
        setState(() => _expirySecondsLeft -= 1);
      }
    });
  }

  Future<void> _verify(String code) async {
    if (_verifying || _isExpired) return;
    setState(() {
      _verifying = true;
      _errorText = null;
    });

    final failure = await ref.read(authProvider.notifier).verifyOtp(code);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (failure != null) {
      setState(() {
        _errorText = failure.message ?? context.tr(AppStrings.authOtpInvalid);
      });
      _otpKey.currentState?.clear();
    }
    // On success, the router redirect kicks the user to /home (existing user)
    // or /login/register (new user).
  }

  Future<void> _resend() async {
    if (_resendSecondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    final failure = await ref.read(authProvider.notifier).resendOtp();
    if (!mounted) return;
    setState(() => _resending = false);

    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Resend failed')),
      );
      return;
    }
    _otpKey.currentState?.clear();
    setState(() => _errorText = null);
    // The cooldown + expiry timers will be (re)started by the ref.listen
    // hook below once the notifier emits the fresh AuthAwaitingOtp state.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(AppStrings.authOtpResent))),
    );
  }

  void _editPhone() {
    ref.read(authProvider.notifier).editPhone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = ref.watch(authProvider);

    // Whenever the notifier replaces the awaiting-state (e.g. after a
    // successful resend), restart both timers from the fresh values.
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next is AuthAwaitingOtp && !identical(prev, next)) {
        _startResendCountdown(next.cooldownSeconds);
        _startExpiryCountdown(next.expiresIn);
      }
    });

    final awaiting = auth is AuthAwaitingOtp ? auth : null;
    final displayPhone = awaiting?.displayPhone ?? '';
    final delivery = awaiting?.delivery;
    final showPushHint = delivery == 'push';
    // Always source the hint from our localized strings — the backend only
    // ships an Arabic copy, so English-locale users would otherwise see Arabic.

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mobileMargin,
                AppSpacing.xl,
                AppSpacing.mobileMargin,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Centred title + subtitle block (matches design's
                  // "تحقق من رقمك" + "تم إرسال رمز ... إلى +966 …").
                  Text(
                    context.tr(AppStrings.authOtpHeading),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineLg(color: scheme.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _OtpSubtitle(
                    subtitle: context.tr(AppStrings.authOtpSubtitle),
                    phoneE164: displayPhone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton.icon(
                      onPressed: _verifying ? null : _editPhone,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(context.tr(AppStrings.authOtpEditPhone)),
                    ),
                  ),
                  if (showPushHint) ...[
                    const SizedBox(height: AppSpacing.md),
                    _DeliveryHintBanner(
                      icon: Icons.notifications_active_rounded,
                      message: context.tr(AppStrings.authOtpPushHint),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  OtpInputField(
                    key: _otpKey,
                    hasError: _errorText != null,
                    enabled: !_verifying && !_isExpired,
                    onChanged: (value) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                      setState(() => _code = value);
                    },
                    onCompleted: _verify,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorText!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLg(color: scheme.error),
                    ),
                  ],
                  if (_isExpired && _errorText == null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.tr(AppStrings.authOtpExpired),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelLg(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Inline resend prompt — reads as a single sentence.
                  _ResendPrompt(
                    secondsLeft: _resendSecondsLeft,
                    resending: _resending,
                    enabled: !_verifying,
                    onResend: _resend,
                  ),
                  if (AppConstants.useMockBackend) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _DevHintCard(
                      message: context.tr(AppStrings.authOtpDevHint),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Sticky bottom action — consistent with the design's confirm CTA.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mobileMargin,
              AppSpacing.sm,
              AppSpacing.mobileMargin,
              AppSpacing.lg,
            ),
            child: CustomButton(
              label: context.tr(AppStrings.authOtpVerify),
              isLoading: _verifying,
              onPressed: _code.length == 6 && !_verifying && !_isExpired
                  ? () => _verify(_code)
                  : null,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Centred subtitle that keeps the (LTR) phone number on a stable baseline
/// even when the parent screen is in RTL.
class _OtpSubtitle extends StatelessWidget {
  const _OtpSubtitle({required this.subtitle, required this.phoneE164});

  final String subtitle;
  final String phoneE164;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
        ),
        if (phoneE164.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              phoneE164,
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodyMdEmphasis(color: scheme.onSurface),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResendPrompt extends StatelessWidget {
  const _ResendPrompt({
    required this.secondsLeft,
    required this.resending,
    required this.enabled,
    required this.onResend,
  });

  final int secondsLeft;
  final bool resending;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = AppTextStyles.bodySm(color: scheme.onSurfaceVariant);
    final highlight = AppTextStyles.labelLg(color: scheme.primary).copyWith(
      fontWeight: FontWeight.w600,
    );

    if (secondsLeft > 0) {
      return Center(
        child: Text(
          context.tr(
            AppStrings.authOtpResendIn,
            params: {'seconds': secondsLeft},
          ),
          style: muted,
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: (resending || !enabled) ? null : onResend,
        icon: resending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.refresh_rounded, size: 16, color: scheme.primary),
        label: Text(
          context.tr(AppStrings.authOtpResend),
          style: highlight,
        ),
      ),
    );
  }
}

class _DeliveryHintBanner extends StatelessWidget {
  const _DeliveryHintBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.lg, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelLg(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevHintCard extends StatelessWidget {
  const _DevHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelLg(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
