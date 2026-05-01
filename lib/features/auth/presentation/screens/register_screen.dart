import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Profile-completion screen for users who passed `verify-otp` with
/// `is_new_user: true`. Submits to `POST /auth/register` via the
/// auth notifier, which already holds the verified `phone` + `code`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _incomeController = TextEditingController();

  String? _nameError;
  String? _emailError;

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
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _nameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final incomeRaw = _incomeController.text.trim().replaceAll(',', '');

    var hasError = false;
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

    if (hasError) {
      setState(() {});
      return;
    }

    final monthlyIncome = incomeRaw.isEmpty ? null : num.tryParse(incomeRaw);

    setState(() {
      _submitting = true;
      _generalError = null;
    });

    final failure = await ref.read(authProvider.notifier).register(
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
    final state = ref.watch(authProvider);
    final phone = state is AuthRegistrationRequired ? state.displayPhone : '';

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
                    if (phone.isNotEmpty) ...[
                      _PhonePill(phone: phone),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

class _PhonePill extends StatelessWidget {
  const _PhonePill({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: AppRadius.brMd,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            size: AppIconSize.lg,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              phone,
              style: AppTextStyles.headlineSm(
                color: scheme.onPrimaryContainer,
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
            ),
          ),
        ],
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
