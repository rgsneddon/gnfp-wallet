import 'package:flutter/material.dart';

/// Black facade so the mediakit logo sits in-scheme.
/// User type: white bold headings, cyan labels, lime balance, yellow tip.
/// Purple `#6C63FF` is never the primary accent.
class GnfpTheme {
  static const Color black = Color(0xFF000000);
  static const Color blackCard = Color(0xFF0A0A0A);
  static const Color blackMid = Color(0xFF111111);
  static const Color navy = black;
  static const Color navyMid = blackMid;
  static const Color navyCard = blackCard;
  static const Color greyDark = black;
  static const Color greyMid = blackMid;
  static const Color greyCard = blackCard;
  static const Color neonBlue = Color(0xFF2694E8);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonLime = Color(0xFF39FF14);
  static const Color neonYellow = Color(0xFFFFE600);
  static const Color cream = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFB0B0B0);
  static const Color evolvePurple = Color(0xFF6C63FF);
  static const double radius = 16;

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonCyan, neonLime],
  );

  static const LinearGradient shellGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [black, black],
  );

  static Color get primary => neonCyan;

  static bool get purpleIsNotPrimary => primary != evolvePurple;

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonLime,
        surface: blackCard,
        onPrimary: black,
        onSurface: cream,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: cream,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: blackCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: Color(0xFF1C1C1C)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: black,
        indicatorColor: const Color(0x4400E5FF),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontSize: 11, color: cream, fontWeight: FontWeight.w700),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: neonCyan),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blackMid,
        labelStyle: const TextStyle(color: neonCyan),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonCyan),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neonCyan),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonCyan,
          foregroundColor: black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
