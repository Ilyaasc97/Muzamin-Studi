import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'config/app_localization.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await SettingsService.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocalization.supportedLocales,
      path: AppLocalization.translationPath,
      fallbackLocale: AppLocalization.fallbackLocale,
      assetLoader: const RootBundleAssetLoader(),
      child: const TafsirTimingApp(),
    ),
  );
}

class TafsirTimingApp extends StatelessWidget {
  const TafsirTimingApp({super.key});

  static const Color _darkSurface = Color(0xFF0C1322);
  static const Color _primary = Color(0xFF0F766E);
  static const Color _primaryDark = Color(0xFF2DD4BF);

  static ThemeData _buildDarkTheme() {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: _primaryDark,
      onPrimary: Color(0xFF003731),
      primaryContainer: Color(0xFF144F4B),
      onPrimaryContainer: Color(0xFF89BFBA),
      secondary: Color(0xFF9AD1CB),
      onSecondary: Color(0xFF003734),
      secondaryContainer: Color(0xFF144F4B),
      onSecondaryContainer: Color(0xFF89BFBA),
      tertiary: Color(0xFF64F0D9),
      onTertiary: Color(0xFF003730),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: _darkSurface,
      surfaceContainerLow: Color(0xFF111827),
      surfaceContainer: Color(0xFF151C2C),
      surfaceContainerHigh: Color(0xFF1E293B),
      surfaceContainerHighest: Color(0xFF2C384D),
      onSurface: Color(0xFFDCE2F7),
      onSurfaceVariant: Color(0xFFBACAC5),
      outline: Color(0xFF859490),
      outlineVariant: Color(0xFF3C4A46),
      inverseSurface: Color(0xFFDCE2F7),
      onInverseSurface: Color(0xFF293040),
      inversePrimary: Color(0xFF006B5F),
      surfaceTint: Color(0xFF3CDDC7),
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkSurface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A2333),
        foregroundColor: _primaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF151C2C),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C384D)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C384D),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryDark,
          foregroundColor: const Color(0xFF003731),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _primaryDark,
        thumbColor: _primaryDark,
        inactiveTrackColor: Color(0xFF2E3545),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141B2B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2C384D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2C384D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryDark, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2E3545),
        contentTextStyle: const TextStyle(color: Color(0xFFDCE2F7)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCCFBF1),
      onPrimaryContainer: Color(0xFF115E59),
      secondary: Color(0xFF0F766E),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0F2FE),
      onSecondaryContainer: Color(0xFF0369A1),
      surface: Colors.white,
      surfaceContainerLow: Color(0xFFF8FAFC),
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFE2E8F0),
      surfaceContainerHighest: Color(0xFFCBD5E1),
      onSurface: Color(0xFF0F172A),
      onSurfaceVariant: Color(0xFF334155),
      outline: Color(0xFF94A3B8),
      outlineVariant: Color(0xFFE2E8F0),
      error: Color(0xFFDC2626),
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _primary,
        thumbColor: _primary,
        inactiveTrackColor: Color(0xFFE2E8F0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (BuildContext context, Widget? _) {
        final ThemeMode currentMode = SettingsService.instance.themeMode;

        return MaterialApp(
          onGenerateTitle: (BuildContext ctx) => 'app_title'.tr(),
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          localizationsDelegates: [
            ...AppLocalization.extraDelegates,
            ...context.localizationDelegates,
          ],
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (BuildContext context, Widget? child) {
            final bool isRtl = context.locale.languageCode == 'ar';
            return Directionality(
              textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}