import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Supported locales for Depans Mw.
class AppLocale {
  AppLocale._();

  static const Locale french = Locale('fr');
  static const Locale creole = Locale('ht');
  static const Locale english = Locale('en');

  static const List<Locale> supported = [french, creole, english];
  static const Locale fallback = french;

  static String labelFor(Locale locale) {
    switch (locale.languageCode) {
      case 'ht':
        return 'Kreyòl Ayisyen';
      case 'en':
        return 'English';
      default:
        return 'Français';
    }
  }

  static Future<void> changeLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
  }
}
