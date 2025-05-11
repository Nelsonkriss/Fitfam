import 'package:flutter/material.dart';
import 'package:workout_planner/resource/shared_prefs_provider.dart'; // Assuming this is your SharedPrefsProvider path

class ThemeProvider with ChangeNotifier {
  final SharedPrefsProvider _prefsProvider;
  ThemeMode _themeMode = ThemeMode.system; // Default

  ThemeProvider(this._prefsProvider) {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemePreference() async {
    String? themeString = await _prefsProvider.getThemeMode();
    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system; // Default if not set or invalid
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String themeString;
    switch (mode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeString = 'system';
        break;
    }
    await _prefsProvider.setThemeMode(themeString);
    notifyListeners();
  }
}