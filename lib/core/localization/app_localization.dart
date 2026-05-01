import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// Lightweight JSON-backed localization. Each language ships as a flat
/// `key -> value` map under `assets/translations/{code}.json`.
class AppLocalizations {
  AppLocalizations(this.locale, this._values);

  final Locale locale;
  final Map<String, String> _values;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(result != null, 'AppLocalizations not found in context.');
    return result!;
  }

  static Iterable<Locale> get supportedLocales =>
      AppConstants.supportedLocales.map(Locale.new);

  /// Returns the translated value for [key], or [key] itself when missing.
  String t(String key, {Map<String, Object?>? params}) {
    final raw = _values[key] ?? key;
    if (params == null || params.isEmpty) return raw;
    var out = raw;
    params.forEach((k, v) {
      out = out.replaceAll('{$k}', '$v');
    });
    return out;
  }

  static Future<Map<String, String>> _load(Locale locale) async {
    final path = 'assets/translations/${locale.languageCode}.json';
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      debugPrint('AppLocalizations: failed to load $path → $e');
      return const {};
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppConstants.supportedLocales.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final values = await AppLocalizations._load(locale);
    return AppLocalizations(locale, values);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience extension: `context.tr(AppStrings.appTitle)`.
extension LocalizationContext on BuildContext {
  String tr(String key, {Map<String, Object?>? params}) =>
      AppLocalizations.of(this).t(key, params: params);
}
