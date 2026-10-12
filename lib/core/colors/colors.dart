import 'package:flutter/material.dart';

class AppColor {
  // Premium Netflix-inspired Palette mapped to #800000
  static const Color background = Color(0xFF000000);   // Pure Black
  static const Color surfaceDark = Color(0xFF141414);  // Very Dark Grey (Obsidian)
  static const Color accentCyan = Color(0xFF800000);   
  static const Color accentBlue = Color(0xFF800000);   
  static const Color accentGold = Color(0xFF800000);   
  static const Color accentGreen = Color(0xFF22C55E);  // Soft green (for statuses only)
  static const Color accentRed = Color(0xFF800000);    
  
  // Legacy / Existing Variable Compatibility
  static const Color lightGrey = Color(0xFFCCCCCC);
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF1F1F1F);
  static const Color darkRed = Color(0xFF600000);
  static const Color moreLightGrey = Color(0xFF808080);
  static const Color midGrey = Color(0xFF555555);
  static const Color charcoal = Color(0xFF1F1F1F);
  static const Color red = Color(0xFF800000);
  static const Color paleGrey = Color(0xFFD4D4D4);
  static const Color deepGrey = Color(0xFF0A0A0A);
  static const Color veryLightGrey = Color(0xFFE5E5E5);
  static const Color softYellow = Color(0xFF800000);   
  static const Color steelGrey = Color(0xFF333333);
  static const Color wineRed = Color(0xFF7F0000);
  static const Color silver = Color(0xFFE5E5E5);
  static const Color coralRed = Color(0xFF800000);
  static const Color lightAsh = Color(0xFFE5E5E5);
  static const Color maroon = Color(0xFF7F0000);
  static const Color lavenderGrey = Color(0xFF808080);
  static const Color brownGrey = Color(0xFF555555);
  static const Color mustard = Color(0xFF800000);      
  static const Color lightGold = Color(0xFFFFFFFF);     
  static const Color oliveGreen = Color(0xFF22C55E);
  static const Color grey = Color(0xFF800000);
  static const Color peach = Color(0xFFE5E5E5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color forestGreen = Color(0xFF15803D);
  static const Color darkGrey2 = Color(0xFF262626);
  static const Color mossGreen = Color(0xFF166534);
  static const Color darkBrownRed = Color(0xFF450A0A);
  static const Color sageGreen = Color(0xFF4ADE80);
  static const Color warmBrown = Color(0xFF7F0000);
  static const Color lightGreen = Color(0xFF22C55E);
  static const Color limeGreen = Color(0xFF4ADE80);
  static const Color neonGreen = Color(0xFF22C55E);
  static const Color greyLavender = Color(0xFFD4D4D4);
  static const Color softRed = Color(0xFF800000);
  static const Color orangeRed = Color(0xFF800000);
  static const Color orange = Color(0xFF800000);
  static const Color brightYellow = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFE5E5E5);
  static const Color deepOrange = Color(0xFF600000);
  static const Color lightOrange = Color(0xFF800000);
  static const Color golden = Color(0xFFFFFFFF);
  static const Color pastelYellow = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);
  static const Color darkBlue = Color(0xFF141414);     

  // Linear Gradients using Red, Black, and Dark Grey
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF800000), Color(0xFF600000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1F1F1F), Color(0xFF141414)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient crownGradient = LinearGradient(
    colors: [Color(0xFF800000), Color(0xFF400000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentRedGradient = LinearGradient(
    colors: [Color(0xFF800000), Color(0xFF600000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF141414), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- PERF: Pre-computed Opacity Colors ---
  // Using .withOpacity() in a build method creates a new Color object on every frame.
  // Pre-computing these saves thousands of allocations per second on TV grid screens.
  static const Color coralRedOpacity80 = Color(0xCC800000); // 0.8
  static const Color coralRedOpacity75 = Color(0xBF800000); // 0.75
  static const Color coralRedOpacity50 = Color(0x80800000); // 0.5
  static const Color coralRedOpacity40 = Color(0x66800000); // 0.4
  static const Color coralRedOpacity25 = Color(0x40800000); // 0.25
  static const Color coralRedOpacity15 = Color(0x26800000); // 0.15

  static const Color whiteOpacity50 = Color(0x80FFFFFF); // 0.5
  static const Color whiteOpacity30 = Color(0x4DFFFFFF); // 0.3
  static const Color whiteOpacity25 = Color(0x40FFFFFF); // 0.25
  static const Color whiteOpacity20 = Color(0x33FFFFFF); // 0.2
  static const Color whiteOpacity10 = Color(0x1AFFFFFF); // 0.1
  static const Color whiteOpacity08 = Color(0x14FFFFFF); // 0.08
  static const Color whiteOpacity05 = Color(0x0DFFFFFF); // 0.05
  
  static const Color accentRedOpacity75 = Color(0xBF800000); // 0.75
  static const Color accentRedOpacity70 = Color(0xB3800000); // 0.7
  static const Color accentRedOpacity50 = Color(0x80800000); // 0.5
  static const Color accentRedOpacity30 = Color(0x4D800000); // 0.3
  static const Color accentRedOpacity25 = Color(0x40800000); // 0.25

  static const Color blackOpacity95 = Color(0xF2000000); // 0.95
  static const Color blackOpacity75 = Color(0xBF000000); // 0.75
  static const Color blackOpacity55 = Color(0x8C000000); // 0.55
  static const Color blackOpacity40 = Color(0x66000000); // 0.4
  static const Color blackOpacity20 = Color(0x33000000); // 0.2

  static const Color cyanOpacity60 = Color(0x9900BCD4); // 0.6
  static const Color cyanOpacity50 = Color(0x8000BCD4); // 0.5

  // --- PERF: Pre-computed Gradients ---
  static const LinearGradient coralRedGradientFocused = LinearGradient(
    colors: [coralRedOpacity25, coralRedOpacity15],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient coralRedGradientSelected = LinearGradient(
    colors: [coralRedOpacity80, coralRedOpacity50],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient whiteGradientIdle = LinearGradient(
    colors: [whiteOpacity10, whiteOpacity05],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentRedGradientFocused = LinearGradient(
    colors: [accentRedOpacity75, accentRedOpacity50],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient blackGradientIdle = LinearGradient(
    colors: [blackOpacity75, blackOpacity55],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}