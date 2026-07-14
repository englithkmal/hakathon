import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field_v2/phone_number.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/password_field.dart';
import '../widgets/phone_input_field.dart';

/// Account-creation screen: phone + password + profile info.
/// Replaces the old OTP-gated registration flow — anyone can land here
/// directly from [LoginScreen] via "Create account".
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _incomeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  PhoneNumber? _phone;
  bool _isPhoneValid = false;

  String? _phoneError;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  late String _currency;
  late String _language;

  bool _submitting = false;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _currency = AppConstants.defaultCurrency;
    _language = ref.read(localeProvider).languageCode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _incomeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _nameController.text.trim().isNotEmpty && _isPhoneValid;

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
    });
  }

  Future<void> _submit() async {
    final phone = _phone;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final incomeRaw = _incomeController.text.trim().replaceAll(',', '');
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    var hasError = false;

    if (phone == null || !_isPhoneValid) {
      _phoneError = context.tr(AppStrings.authPhoneInvalid);
      hasError = true;
    } else {
      _phoneError = null;
    }

    if (name.isEmpty) {
      _nameError = context.tr(AppStrings.authRegisterNameRequired);
      hasError = true;
    } else {
      _nameError = null;
    }

    if (email.isNotEmpty && !Validators.isValidEmail(email)) {
      _emailError = context.tr(AppStrings.authRegisterEmailInvalid);
      hasError = true;
    } else {
      _emailError = null;
    }

    if (password.length < 6) {
      _passwordError = context.tr(AppStrings.authPasswordTooShort);
      hasError = true;
    } else {
      _passwordError = null;
    }

    if (confirmPassword != password) {
      _confirmPasswordError = context.tr(AppStrings.authPasswordsDontMatch);
      hasError = true;
    } else {
      _confirmPasswordError = null;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    final monthlyIncome = incomeRaw.isEmpty ? null : num.tryParse(incomeRaw);

    setState(() {
      _submitting = true;
      _generalError = null;
    });

    final e164 = phone!.completeNumber;

    final failure = await ref.read(authProvider.notifier).register(
          phoneE164: e164,
          password: password,
          name: name,
          currency: _currency,
          language: _language,
          email: email.isEmpty ? null : email,
          monthlyIncome: monthlyIncome,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (failure != null) {
      setState(() => _generalError = failure.message ?? '');
      return;
    }
    // Router will redirect to /home on AuthAuthenticated.
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
                  AppSpacing.md,
                  AppSpacing.mobileMargin,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(
                      icon: Icons.person_add_alt_1_rounded,
                      title: context.tr(AppStrings.authRegisterTitle),
                      subtitle: context.tr(AppStrings.authRegisterSubtitle),
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PhoneInputField(
                      label: context.tr(AppStrings.authPhoneLabel),
                      hint: context.tr(AppStrings.authPhoneHint),
                      errorText: _phoneError,
                      enabled: !_submitting,
                      autofocus: false,
                      invalidNumberMessage: invalidMsg,
                      onChanged: _onPhoneChanged,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: _nameController,
                      label: context.tr(AppStrings.authRegisterName),
                      hint: context.tr(AppStrings.authRegisterNameHint),
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                      errorText: _nameError,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _passwordController,
                      label: context.tr(AppStrings.authPasswordLabel),
                      hint: context.tr(AppStrings.authPasswordHint),
                      errorText: _passwordError,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: _confirmPasswordController,
                      label: context.tr(AppStrings.authConfirmPasswordLabel),
                      hint: context.tr(AppStrings.authPasswordHint),
                      errorText: _confirmPasswordError,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: _emailController,
                      label: context.tr(AppStrings.authRegisterEmail),
                      hint: context.tr(AppStrings.authRegisterEmailHint),
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: _incomeController,
                      label: context.tr(AppStrings.authRegisterIncome),
                      hint: context.tr(AppStrings.authRegisterIncomeHint),
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CurrencyDropdown(
                      label: context.tr(AppStrings.authRegisterCurrency),
                      value: _currency,
                      enabled: !_submitting,
                      onChanged: (val) => setState(() => _currency = val),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LanguageDropdown(
                      label: context.tr(AppStrings.authRegisterLanguage),
                      value: _language,
                      enabled: !_submitting,
                      onChanged: (val) => setState(() => _language = val),
                    ),
                    if (_generalError != null &&
                        _generalError!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _generalError!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelMd(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _LoginLink(submitting: _submitting),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mobileMargin,
                AppSpacing.sm,
                AppSpacing.mobileMargin,
                AppSpacing.lg,
              ),
              child: CustomButton(
                label: context.tr(AppStrings.authRegisterSubmit),
                isLoading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginLink extends StatelessWidget {
  const _LoginLink({required this.submitting});

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
        onTap: submitting ? null : () => context.pop(),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: context.tr(AppStrings.authHaveAccountAlready)),
              TextSpan(
                text: context.tr(AppStrings.authGoToLoginLink),
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

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLg(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          onChanged: enabled ? (v) => v != null ? onChanged(v) : null : null,
          items: [
            for (final c in AppConstants.supportedCurrencies)
              DropdownMenuItem<String>(
                value: c,
                child: Text(c, style: theme.textTheme.bodyLarge),
              ),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLg(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          onChanged: enabled ? (v) => v != null ? onChanged(v) : null : null,
          items: [
            DropdownMenuItem<String>(
              value: 'ar',
              child: Text(
                context.tr(AppStrings.authLanguageArabic),
                style: theme.textTheme.bodyLarge,
              ),
            ),
            DropdownMenuItem<String>(
              value: 'en',
              child: Text(
                context.tr(AppStrings.authLanguageEnglish),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
          decoration: InputDecoration(
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.brMd,
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
