import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/storage_providers.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _themeKey = 'user_theme_mode';

  ThemeNotifier(this._prefs) : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedTheme = _prefs.getString(_themeKey);
    if (savedTheme == 'dark') {
      state = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      state = ThemeMode.light;
    } else {
      // Default to system or light if no preference
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await _prefs.setString(_themeKey, 'dark');
    } else {
      state = ThemeMode.light;
      await _prefs.setString(_themeKey, 'light');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(
        _themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
