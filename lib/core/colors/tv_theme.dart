import 'package:flutter/material.dart';

class TVTheme {
  TVTheme._();

  // Colors
  static const Color background = Color(0xFF0D0D12);
  static const Color surface = Color(0xFF161620);
  static const Color border = Color(0xFF2A2A3A);
  
  static const Color accentRed = Color(0xFF800000);
  static const Color accentRedLight = Color(0xFFE57373);
  static const Color accentRedDark = Color(0xFF5A0000);
  
  static const Color activeGreen = Color(0xFF4CAF50);
  static const Color activeGreenBg = Color(0xFF091A10);
  static const Color activeGreenBorder = Color(0xFF2E7D52);

  // Typography Scale (Optimized for 10-foot TV viewing)
  static const TextStyle titleLarge = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    color: Colors.white,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelSmall = TextStyle(
    color: Colors.white54,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  // Focus effect decorations
  static BoxDecoration focusDecoration({
    required bool focused,
    Color glowColor = accentRed,
    double radius = 14,
    bool isDestructive = false,
  }) {
    final activeGlow = isDestructive ? const Color(0xFFE57373) : glowColor;
    return BoxDecoration(
      color: focused
          ? (isDestructive ? const Color(0xFF3A0808) : Colors.white.withOpacity(0.08))
          : (isDestructive ? const Color(0xFF1A0505) : Colors.white.withOpacity(0.04)),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused ? activeGlow : Colors.white.withOpacity(0.09),
        width: focused ? 2.5 : 1.0,
      ),
      boxShadow: focused
          ? [
              BoxShadow(
                color: activeGlow.withOpacity(0.45),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ]
          : null,
    );
  }
}
