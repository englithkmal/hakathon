/// Pure validation helpers used across the auth flow.
///
/// Country-specific phone validation now lives inside the `intl_phone_field_v2`
/// package (every country has its own `min/max` length) — see
/// [PhoneInputField]. The helpers below cover only the cases we still need
/// to validate ourselves (OTP, email, etc.).
class Validators {
  Validators._();

  /// Returns `true` for an OTP that is exactly [length] digits.
  static bool isValidOtp(String code, {int length = 6}) {
    if (code.length != length) return false;
    return RegExp(r'^\d+$').hasMatch(code);
  }

  /// Strips formatting (spaces / dashes) and keeps digits only.
  static String onlyDigits(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  /// Loose email validation — good enough for client-side gating before
  /// the backend re-validates.
  static bool isValidEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }
}
