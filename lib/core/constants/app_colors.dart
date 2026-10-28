import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0D0F12);
  static const Color surface = Color(0xFF161A20);
  static const Color surfaceElevated = Color(0xFF1E242D);
  static const Color card = Color(0xFF222933);
  static const Color divider = Color(0xFF2C3442);

  // Brand & Accents
  static const Color primary = Color(0xFF388BFD); // Apple / Premiere Blue
  static const Color primaryGlow = Color(0x33388BFD);
  static const Color accentAmber = Color(0xFFFFB400); // Premiere Speed Accent
  static const Color accentCyan = Color(0xFF00E5FF); // Optical Flow Glow
  static const Color success = Color(0xFF2EA043);
  static const Color warning = Color(0xFFE3B341);
  static const Color danger = Color(0xFFF85149);

  // Text
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // Gradient definitions
  static const LinearGradient flowGradient = LinearGradient(
    colors: [Color(0xFF388BFD), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient speedGradient = LinearGradient(
    colors: [Color(0xFFFFB400), Color(0xFFFF5252)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1B2129), Color(0xFF13171D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
