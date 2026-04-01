import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter does not ship Material/Cupertino localizations for [Locale('ht')].
/// Without them, Material widgets throw ("No MaterialLocalizations found"),
/// which breaks scrolling, taps, and paints gray error boxes.
///
/// These delegates load French framework strings for Haitian Creole while
/// [easy_localization] still serves app copy from `ht.json`.
class MaterialLocalizationsHtFallback extends LocalizationsDelegate<MaterialLocalizations> {
  const MaterialLocalizationsHtFallback();

  static const Locale _materialFallback = Locale('fr');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ht';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return GlobalMaterialLocalizations.delegate.load(_materialFallback);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> old) =>
      false;
}

class CupertinoLocalizationsHtFallback extends LocalizationsDelegate<CupertinoLocalizations> {
  const CupertinoLocalizationsHtFallback();

  static const Locale _cupertinoFallback = Locale('fr');

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ht';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return GlobalCupertinoLocalizations.delegate.load(_cupertinoFallback);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> old) =>
      false;
}
