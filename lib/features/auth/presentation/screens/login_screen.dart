import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field_v2/phone_number.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/password_field.dart';
import '../widgets/phone_input_field.dart';

/// Login screen — phone number + password. Replaces the old OTP flow.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();

  PhoneNumber? _phone;
  bool _isPhoneValid = false;
  String? _phoneError;
  String? _passwordError;
  String? _generalError;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

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
      if (_phoneError != null) _phoneError = null;
      if (_generalError != null) _generalError = null;
    });
  }

  Future<void> _submit() async {
    final phone = _phone;
    final password = _passwordController.text;
    final invalidMsg = context.tr(AppStrings.authPhoneInvalid);
    final tooShortMsg = context.tr(AppStrings.authPasswordTooShort);

    bool hasError = false;

    if (phone == null || !_isPhoneValid) {
      _phoneError = invalidMsg;
      hasError = true;
    } else {
      _phoneError = null;
    }

    if (password.length < 6) {
      _passwordError = tooShortMsg;
      hasError = true;
    } else {
      _passwordError = null;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() {
      _submitting = true;
      _generalError = null;
    });

    final e164 = phone!.completeNumber;
    final failure = await ref.read(authProvider.notifier).login(
          phoneE164: e164,
          password: password,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure != null) {
      setState(() {
        _generalError =
            failure.message ?? context.tr(AppStrings.authLoginInvalid);
      });
    }
    // On success, the router redirect sends us to /home automatically.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invalidMsg = context.tr(AppStrings.authPhoneInvalid);
    final canSubmit = !_submitting;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
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
              Text(
                context.tr(AppStrings.authWelcomeHeading),
                style: AppTextStyles.headlineXl(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.tr(AppStrings.authWelcomeTagline),
                style: AppTextStyles.bodyMd(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              PhoneInputField(
                label: context.tr(AppStrings.authPhoneLabel),
                hint: context.tr(AppStrings.authPhoneHint),
                errorText: _phoneError,
                enabled: !_submitting,
                invalidNumberMessage: invalidMsg,
                onChanged: _onPhoneChanged,
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _passwordController,
                label: context.tr(AppStrings.authPasswordLabel),
                hint: context.tr(AppStrings.authPasswordHint),
                errorText: _passwordError,
                enabled: !_submitting,
                textInputAction: TextInputAction.done,
                onSubmitted: canSubmit ? _submit : null,
              ),
              if (_generalError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _generalError!,
                  style: AppTextStyles.bodySm(color: scheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              CustomButton(
                label: context.tr(AppStrings.authLoginSubmit),
                isLoading: _submitting,
                onPressed: canSubmit ? _submit : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              _RegisterLink(submitting: _submitting),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.submitting});

  final bool submitting;

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

    return Center(
      child: GestureDetector(
        onTap: submitting
            ? null
            : () => context.push(RouteNames.registerPath),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: context.tr(AppStrings.authNoAccountYet)),
              TextSpan(
                text: context.tr(AppStrings.authCreateAccountLink),
                style: link,
              ),
            ],
          ),
          style: base,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
