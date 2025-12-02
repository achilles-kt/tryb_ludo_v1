import 'package:flutter/material.dart';

class AppColors {
  static const bgDark = Color(0xFF0F1218);
  static const neonPurple = Color(0xFFA259FF);
  static const neonBlue = Color(0xFF3B82F6);
  static const neonGreen = Color(0xFF22C55E);
  static const neonRed = Color(0xFFEF4444);
  static const neonYellow = Color(0xFFEAB308);
  static const glassSurface = Color.fromRGBO(255, 255, 255, 0.05);
  static const glassBorder = Color.fromRGBO(255, 255, 255, 0.10);
  static const textMuted = Color(0xFF94A3B8);

  static LinearGradient primaryGrad = LinearGradient(
    colors: [neonPurple, neonBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
