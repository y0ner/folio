import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la app.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
      : _themeMode = ThemeMode.values.asNameMap()[_prefs.getString(_kTheme)] ??
            ThemeMode.system;

  static const String _kTheme = 'settings.themeMode';

  final SharedPreferencesWithCache _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }
}
