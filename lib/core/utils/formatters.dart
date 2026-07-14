/// Text-formatting helpers (display-only — no business logic).
class Formatters {
  Formatters._();

  /// Renders an E.164 number with a single space between the dial code and
  /// the national digits, e.g. `+966512345678` → `+966 512345678`.
  ///
  /// Falls back to the original string when [e164] does not start with `+`
  /// or when no plausible split point can be found.
  static String phoneE164ForDisplay(String e164) {
    if (!e164.startsWith('+')) return e164;
    // The dial code is always 1–4 digits after the leading `+`. Split at
    // the first non-leading boundary that still keeps at least 4 national
    // digits — country-agnostic but readable.
    for (var i = 4; i >= 1; i--) {
      if (e164.length > i + 4) {
        final code = e164.substring(0, i + 1);
        final rest = e164.substring(i + 1);
        if (RegExp(r'^\d+$').hasMatch(rest)) {
          return '$code $rest';
        }
      }
    }
    return e164;
  }

  /// Masks all but the last 4 digits of a phone number for previews.
  /// `+966512345678` → `+966 ••• •• 5678`.
  static String maskPhone(String e164) {
    if (e164.length < 4) return e164;
    final last4 = e164.substring(e164.length - 4);
    return '${e164.substring(0, e164.length - 4).replaceAll(RegExp(r'\d'), '•')}$last4';
  }
}
