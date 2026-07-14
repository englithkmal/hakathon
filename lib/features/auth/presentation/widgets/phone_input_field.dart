import 'package:flutter/material.dart';
import 'package:intl_phone_field_v2/country_picker_dialog.dart';
import 'package:intl_phone_field_v2/intl_phone_field.dart';
import 'package:intl_phone_field_v2/phone_number.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// International phone input powered by [IntlPhoneField].
///
/// Renders the digit field next to a country picker (flag + dial code) and
/// validates the digit count against the selected country's spec via the
/// underlying `intl_phone_field_v2` package — so Saudi numbers stay 9 digits
/// while Yemeni numbers (`+967`) are also enforced as 9 digits, and any other
/// country is supported automatically.
class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = true,
    this.enabled = true,
    this.initialCountryCode = 'YE',
    this.invalidNumberMessage,
    this.languageCode,
  });

  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<PhoneNumber>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;
  final bool enabled;

  /// 2-letter ISO code (e.g. `YE`, `SA`) or `+dialCode` form.
  /// Defaults to Yemen (`YE`, +967, 9 digits) — the primary launch market.
  final String initialCountryCode;
  final String? invalidNumberMessage;
  final String? languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final lang = languageCode ?? Localizations.localeOf(context).languageCode;

    final radius = AppRadius.brSm;

    OutlineInputBorder noBorder() => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        );

    OutlineInputBorder outline(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLg(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        Directionality(
          // Keep the picker + digit layout LTR even in Arabic UIs so the
          // dial code stays adjacent to the leading edge of the digits.
          textDirection: TextDirection.ltr,
          child: IntlPhoneField(
            autofocus: autofocus,
            enabled: enabled,
            initialCountryCode: initialCountryCode,
            languageCode: lang,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.left,
            autovalidateMode: AutovalidateMode.disabled,
            invalidNumberMessage:
                invalidNumberMessage ?? 'Invalid phone number',
            disableLengthCheck: false,
            showCountryFlag: true,
            showDropdownIcon: true,
            dropdownIconPosition: IconPosition.trailing,
            dropdownIcon: Icon(
              Icons.expand_more_rounded,
              size: AppIconSize.sm,
              color: scheme.onSurfaceVariant,
            ),
            flagsButtonPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
            ),
            dropdownTextStyle: AppTextStyles.bodyMdEmphasis(
              color: scheme.onSurface,
            ),
            style: AppTextStyles.bodyLg(color: scheme.onSurface).copyWith(
              letterSpacing: 1.0,
            ),
            cursorColor: scheme.primary,
            pickerDialogStyle: PickerDialogStyle(
              backgroundColor: scheme.surface,
              countryCodeStyle: AppTextStyles.bodyMd(
                color: scheme.onSurfaceVariant,
              ),
              countryNameStyle: AppTextStyles.bodyMdEmphasis(
                color: scheme.onSurface,
              ),
              searchFieldInputDecoration: InputDecoration(
                hintText: lang == 'ar' ? 'بحث' : 'Search',
                hintStyle: AppTextStyles.bodyMd(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: scheme.surfaceContainerLowest,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.onSurfaceVariant,
                ),
                border: outline(scheme.outlineVariant, 1),
                enabledBorder: outline(scheme.outlineVariant, 1),
                focusedBorder: outline(scheme.primary, 1.5),
              ),
              searchFieldPadding: const EdgeInsets.all(AppSpacing.md),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyLg(color: scheme.outlineVariant),
              // Light gray fill that only sharpens to a primary ring on focus
              // (Serene Finance "minimal input" pattern).
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              border: hasError ? outline(scheme.error, 1) : noBorder(),
              enabledBorder: hasError ? outline(scheme.error, 1) : noBorder(),
              focusedBorder: outline(
                hasError ? scheme.error : scheme.primary,
                1,
              ),
              errorBorder: outline(scheme.error, 1),
              focusedErrorBorder: outline(scheme.error, 1),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTextStyles.labelMd(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
