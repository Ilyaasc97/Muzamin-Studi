import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SomaliMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const SomaliMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const DefaultMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(SomaliMaterialLocalizationsDelegate old) => false;
}

class SomaliCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const SomaliCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const DefaultCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(SomaliCupertinoLocalizationsDelegate old) => false;
}

class AppLocalization {
  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('so'),
  ];

  static const fallbackLocale = Locale('ar');

  static const String translationPath = 'assets/translations';

  static List<LocalizationsDelegate<dynamic>> get extraDelegates => const [
        SomaliMaterialLocalizationsDelegate(),
        SomaliCupertinoLocalizationsDelegate(),
      ];

  static Future<void> initialize() async {
    await EasyLocalization.ensureInitialized();
  }

  static Locale getDefaultLocale() => const Locale('ar');

  static String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'so':
        return 'Soomaali';
      default:
        return languageCode;
    }
  }

  static bool isRTL(BuildContext context) {
    final currentLocale =
        EasyLocalization.of(context)?.currentLocale ?? const Locale('ar');
    return currentLocale.languageCode == 'ar';
  }
}