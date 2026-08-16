import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF7C4DFF);
  static const Color secondary = Color(0xFFFF4D8D);
  static const Color accent = Color(0xFF00E5FF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: secondary,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F0E1A) : const Color(0xFFF7F5FF),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor:
            isDark ? const Color(0xFF16142A) : const Color(0xFFF7F5FF),
        foregroundColor:
            isDark ? Colors.white : const Color(0xFF241F3A),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1D1A33) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF16142A) : const Color(0xFFFFFFFF),
        indicatorColor: primary.withValues(alpha: 0.2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? const Color(0xFF2A2547) : const Color(0xFFEFEAFE),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF3D3568),
          fontSize: 12,
        ),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF2A2547) : const Color(0xFF241F3A),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }
}

class AppGradient {
  static const List<Color> anime = [
    Color(0xFF7C4DFF),
    Color(0xFFFF4D8D),
  ];

  static LinearGradient hero() => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C4DFF), Color(0xFFFF4D8D)],
      );

  static List<Color> get primary => anime;
}
