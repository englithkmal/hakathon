import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field_v2/phone_number.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/phone_input_field.dart';

/// Phone-number entry screen — first stop in the auth flow.
///
/// Layout follows the **Serene Finance** spec: a sticky white app bar with a
/// primary-coloured back button + title, a left-aligned welcome heading, the
/// phone input, the primary submit button, and inline T&C copy at the bottom.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  PhoneNumber? _phone;
  bool _isPhoneValid = false;
  String? _errorText;
  bool _submitting = false;

  bool get _canSubmit => _isPhoneValid && !_submitting;

  void _onPhoneChanged(PhoneNumber phone) {
    bool valid = false;
    try {
      valid = phone.isValidNumber();
    } catch (_) {
      valid = false;
    }

    setState(() {
      _phone = phone;
      _isPhoneValid = valid;
      if (_errorText != null) _errorText = null;
    });
  }

  Future<void> _submit() async {
    final phone = _phone;
    if (phone == null) {
      setState(() => _errorText = context.tr(AppStrings.authPhoneInvalid));
      return;
    }

    bool valid;
    try {
      valid = phone.isValidNumber();
    } catch (_) {
      valid = false;
    }

    if (!valid) {
      setState(() => _errorText = context.tr(AppStrings.authPhoneInvalid));
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });

    final localeCode = ref.read(localeProvider).languageCode;
    final e164 = phone.completeNumber; // e.g. "+966512345678" or "+967771234567"
    // Build the display variant straight from the library fields so we don't
    // mis-split the dial code (e.g. naive heuristics rendered "+9677 77…"
    // instead of "+967 777…"). `countryCode` already includes the leading `+`.
    final displayPhone = '${phone.countryCode} ${phone.number}';

    // Best-effort fetch of the FCM token so the backend can deliver the OTP
    // (and follow-up alerts) as a push. Never blocks the user — if FCM is
    // unavailable, we still send the request and the backend falls back.
    String? deviceToken;
    try {
      deviceToken = await ref
          .read(notificationServiceProvider)
          .getToken()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      deviceToken = null;
    }

    final failure = await ref.read(authProvider.notifier).requestOtp(
          phoneE164: e164,
          displayPhone: displayPhone,
          locale: localeCode,
          deviceToken: deviceToken,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure != null) {
      setState(() {
        _errorText = failure.message ?? context.tr(AppStrings.authPhoneInvalid);
      });
      return;
    }
    // Router redirect will move us to /login/otp.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invalidMsg = context.tr(AppStrings.authPhoneInvalid);

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
                  const SizedBox(height: AppSpacing.lg),
                  // Heading block — "أهلاً بك" + tagline (left-aligned in RTL,
                  // start-aligned in LTR).
                  Text(
                    context.tr(AppStrings.authWelcomeHeading),
                    style: AppTextStyles.headlineXl(color: scheme.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr(AppStrings.authWelcomeTagline),
                    style:
                        AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PhoneInputField(
                    label: context.tr(AppStrings.authPhoneLabel),
                    hint: context.tr(AppStrings.authPhoneHint),
                    errorText: _errorText,
                    enabled: !_submitting,
                    invalidNumberMessage: invalidMsg,
                    onChanged: _onPhoneChanged,
                    onSubmitted: () {
                      if (_canSubmit) _submit();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CustomButton(
                    label: context.tr(AppStrings.authContinue),
                    isLoading: _submitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ],
              ),
            ),
          ),
          // Inline T&C footer — links styled in primary.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.mobileMargin,
              AppSpacing.sm,
              AppSpacing.mobileMargin,
              AppSpacing.lg,
            ),
            child: _TermsFootnote(),
          ),
        ],
        ),
      ),
    );
  }
}

class _TermsFootnote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = AppTextStyles.bodySm(color: scheme.onSurfaceVariant);
    final link = AppTextStyles.bodySm(color: scheme.primary).copyWith(
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary.withValues(alpha: 0.3),
      decorationThickness: 1.2,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.tr(AppStrings.authTermsNotePrefix)),
          TextSpan(text: context.tr(AppStrings.authTermsNoteTerms), style: link),
          TextSpan(text: context.tr(AppStrings.authTermsNoteAnd)),
          TextSpan(
            text: context.tr(AppStrings.authTermsNotePrivacy),
            style: link,
          ),
          TextSpan(text: context.tr(AppStrings.authTermsNoteSuffix)),
        ],
      ),
      textAlign: TextAlign.center,
      style: base,
    );
  }
}
