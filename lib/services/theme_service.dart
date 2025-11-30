import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'dark_mode';
  static ThemeService? _instance;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeService._internal() {
    _loadTheme();
  }

  factory ThemeService() {
    _instance ??= ThemeService._internal();
    return _instance!;
  }

  static ThemeService? get instance => _instance;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getBool(_themeKey);
      if (savedTheme != null) {
        _isDarkMode = savedTheme;
      }
      // Always notify listeners after loading
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
      // Still notify even on error
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _saveTheme();
    notifyListeners();
  }

  Future<void> setTheme(bool isDark) async {
    // Always update, even if same value, to ensure UI refreshes
    _isDarkMode = isDark;
    await _saveTheme();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardColor: Colors.white,
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
      // Ensure background color is set
      canvasColor: Colors.white,
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      dividerColor: Colors.grey[800],
      // Ensure background color is set
      canvasColor: const Color(0xFF121212),
    );
  }
}

