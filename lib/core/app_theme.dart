import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brand palette — deep teal + gold accent.
class AppColors {
  static const primary = Color(0xFF146E82);
  static const primaryDark = Color(0xFF153C3F);
  static const accent = Color(0xFFFFC000);
  static const good = Color(0xFF2E9E6B);
  static const bad = Color(0xFFD64545);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        brightness == Brightness.light ? const Color(0xFFF5F7F8) : null,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor:
          brightness == Brightness.light ? Colors.white : null,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: brightness == Brightness.light ? Colors.white : null,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

/// Global app settings (locale + theme), persisted with SharedPreferences.
class AppSettings extends ChangeNotifier {
  static const _kLocale = 'locale';
  static const _kTheme = 'theme';

  Locale _locale = const Locale('ar');
  ThemeMode _themeMode = ThemeMode.system;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final lang = sp.getString(_kLocale);
    if (lang != null) _locale = Locale(lang);
    final theme = sp.getString(_kTheme);
    if (theme != null) {
      _themeMode = ThemeMode.values
          .firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale l) async {
    _locale = l;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLocale, l.languageCode);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kTheme, m.name);
  }
}
