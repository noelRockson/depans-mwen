import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_locale.dart';
import 'core/l10n/material_localizations_ht_fallback.dart';
import 'pages/session_gate.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  try {
    await Firebase.initializeApp();
    await AuthService.instance.ensureInitialized();
  } catch (e) {
    // ignore: avoid_print
    print('Initialization error: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: AppLocale.supported,
      path: 'assets/translations',
      fallbackLocale: AppLocale.fallback,
      startLocale: AppLocale.fallback,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        ...context.localizationDelegates,
        const MaterialLocalizationsHtFallback(),
        const CupertinoLocalizationsHtFallback(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SessionGate(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}
