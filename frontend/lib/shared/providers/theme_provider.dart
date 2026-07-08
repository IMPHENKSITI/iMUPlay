import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Enum untuk 3 pilihan tema: Light, Dark, System
enum AppThemeMode { light, dark, system }

/// Provider utama untuk mengatur tema aplikasi.
/// Menyimpan preferensi ke Hive agar tetap tersimpan walau aplikasi ditutup.
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _boxName = 'settings';
  static const String _key = 'theme_mode';

  ThemeNotifier() : super(AppThemeMode.system) {
    _loadFromStorage();
  }

  /// Memuat preferensi tema dari Hive saat aplikasi pertama kali dibuka
  void _loadFromStorage() {
    try {
      final box = Hive.box<String>(_boxName);
      final stored = box.get(_key, defaultValue: 'system');
      switch (stored) {
        case 'light':
          state = AppThemeMode.light;
          break;
        case 'dark':
          state = AppThemeMode.dark;
          break;
        default:
          state = AppThemeMode.system;
      }
    } catch (e) {
      debugPrint("Error loading theme: $e");
    }
  }

  /// Dipanggil saat user memilih tema baru dari halaman Settings
  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final box = Hive.box<String>(_boxName);
    await box.put(_key, mode.name); // Simpan ke storage: 'light', 'dark', atau 'system'
  }

  /// Konversi ke ThemeMode bawaan Flutter
  ThemeMode get flutterThemeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Provider global yang bisa diakses dari mana saja di aplikasi
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
