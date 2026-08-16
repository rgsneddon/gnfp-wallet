import 'package:flutter/material.dart';

/// GNFP 0.1.11 chrome — navy pool palette, cyan accent, rounded cards.
/// Purple `#6C63FF` is never the primary accent.
class GnfpTheme {
  static const Color navy = Color(0xFF0A1628);
  static const Color navyMid = Color(0xFF132A4A);
  static const Color navyCard = Color(0xFF1A3A5C);
  static const Color greyDark = navy;
  static const Color greyMid = navyMid;
  static const Color greyCard = navyCard;
  static const Color neonBlue = Color(0xFF2694E8);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color cream = Color(0xFFF2F5F7);
  static const Color muted = Color(0xFFA0BDD4);
  static const Color evolvePurple = Color(0xFF6C63FF);
  static const double radius = 16;

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonBlue, neonCyan],
  );

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E2038), navy],
  );

  static Color get primary => neonCyan;

  static bool get purpleIsNotPrimary => primary != evolvePurple;

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navy,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonBlue,
        surface: navyCard,
        onPrimary: navy,
        onSurface: cream,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cream,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: navyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navyMid,
        indicatorColor: const Color(0x4400E5FF),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, color: cream),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navyMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
