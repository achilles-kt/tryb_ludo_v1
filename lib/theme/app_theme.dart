import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color bgDark = Color(0xFF0F1218); // Matches GameScreen
  static const Color surface = Color(0xFF1E293B); // Dark Blue/Grey
  static const Color neonBlue = Color(0xFF3B82F6);
  static const Color neonPurple = Color(0xFFA259FF);
  static const Color neonGreen = Color(0xFF22C55E);
  static const Color neonRed = Color(0xFFEF4444);
  static const Color gold = Color(0xFFFFD700);

  static const LinearGradient primaryGrad = LinearGradient(
    colors: [neonPurple, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x0DFFFFFF), Color(0x05FFFFFF)], // 5% - 2% white
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Text Styles
  static TextStyle get header => const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 24,
      );

  static TextStyle get text => const TextStyle(
        fontFamily: 'Poppins', // Fallback to Poppins as Inter is missing
        color: Colors.white,
        fontSize: 14,
      );

  static TextStyle get label => const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );

  // Theme Data for Material App
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDark,
      primaryColor: neonBlue,
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Poppins',
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
      colorScheme: const ColorScheme.dark(
        primary: neonBlue,
        secondary: neonPurple,
        surface: surface,
        background: bgDark,
      ),
    );
  }
}
