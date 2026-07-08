import 'package:flutter/material.dart';

/// Central Design System Token untuk iMUplay.
/// Light Mode: #70E1F5 → #FFD194 (Pink & Soft Peach)
/// Dark Mode:  #67F3CE → #4890EA (Tosca & Biru Cerah)
class AppColors {
  AppColors._();

  // ── Light Mode (Pink & Soft Peach) ────────────────────────────────────
  static const Color lightStart   = Color(0xFFFF9A9E); // Premium Pink
  static const Color lightEnd     = Color(0xFFFFC3A0); // Soft Peach
  static const Color lightPrimary = Color(0xFFFF8E9F); // Slightly saturated pink

  // ── Dark Mode ─────────────────────────────────────────────────────────
  static const Color darkStart   = Color(0xFF67F3CE);
  static const Color darkEnd     = Color(0xFF4890EA);
  static const Color darkPrimary = Color(0xFF5BC2DA);

  // ── Gradients ─────────────────────────────────────────────────────────
  static LinearGradient gradient({required bool isDark}) => LinearGradient(
    colors: isDark ? [darkStart, darkEnd] : [lightStart, lightEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient gradientDiagonal({required bool isDark}) => LinearGradient(
    colors: isDark ? [darkStart, darkEnd] : [lightStart, lightEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Premium Colored Glass Gradient (Solid colors but slightly translucent for blur effect)
  static LinearGradient gradientGlass({required bool isDark, double alpha = 0.85}) => LinearGradient(
    colors: isDark
        ? [darkStart.withValues(alpha: alpha), darkEnd.withValues(alpha: alpha)]
        : [lightStart.withValues(alpha: alpha), lightEnd.withValues(alpha: alpha)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static Color primary({required bool isDark}) =>
      isDark ? darkPrimary : lightPrimary;

  // ── Spatial Shadows ───────────────────────────────────────────────────
  static BoxShadow coloredShadow({required bool isDark, double opacity = 0.35}) =>
      BoxShadow(
        color: (isDark ? darkStart : lightStart).withValues(alpha: opacity),
        blurRadius: 20,
        spreadRadius: -4,
        offset: const Offset(0, 8),
      );

  static BoxShadow elevatedShadow({required bool isDark}) =>
      BoxShadow(
        color: (isDark ? darkEnd : lightEnd).withValues(alpha: 0.25),
        blurRadius: 16,
        spreadRadius: -2,
        offset: const Offset(0, 4),
      );

  // ── Glassmorphism ────────────────────────────────────────────────────
  static Color glassBackground({required bool isDark}) => isDark
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.72);

  static Color glassBorder({required bool isDark}) => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.8);

  // ── Surfaces ─────────────────────────────────────────────────────────
  static Color cardColor({required bool isDark}) =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;

  static Color textPrimary({required bool isDark}) =>
      isDark ? Colors.white : const Color(0xFF111111);

  static Color textSecondary({required bool isDark}) =>
      isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
}
