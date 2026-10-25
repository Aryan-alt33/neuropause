import 'package:flutter/material.dart';

class AppColors {
  // Pale Mint Backgrounds
  static const Color paleMintBg = Color(0xFFF3F7F4);
  static const Color paleMintSurface = Color(0xFFE8F1EC);
  static const Color softMintContainer = Color(0xFFDFECE3);

  // Soft Sage Green Accents & Primary
  static const Color sagePrimary = Color(0xFF4A7C59);
  static const Color sageLight = Color(0xFF5D916D);
  static const Color sageDeep = Color(0xFF386445);
  static const Color sageTrack = Color(0xFF7CAFA0);
  static const Color sageSwitchTrack = Color(0xFF75A986);
  static const Color sageInactive = Color(0xFFDCE7E0);

  // Dark Forest-Green Text
  static const Color forestTextPrimary = Color(0xFF183624);
  static const Color forestTextSecondary = Color(0xFF425E4D);
  static const Color forestTextMuted = Color(0xFF6B8575);

  // White Surface & Borders
  static const Color white = Colors.white;
  static const Color borderSage = Color(0xFFDFECE3);
  static const Color borderSageSubtle = Color(0xFFE9F1EC);

  // Gentle Box Shadows
  static const Color shadowSage = Color(0x102E553B);
  static const Color shadowSageHero = Color(0x3B4A7C59);

  // Priority Badges (Accessible, Calming, Harmonized)
  static const Color urgentBg = Color(0xFFFDF0ED);
  static const Color urgentBorder = Color(0xFFF8D2CA);
  static const Color urgentText = Color(0xFFC24128);

  static const Color importantBg = Color(0xFFE6F3EB);
  static const Color importantBorder = Color(0xFFCBE3D5);
  static const Color importantText = Color(0xFF2C6943);

  static const Color canWaitBg = Color(0xFFEEF3F0);
  static const Color canWaitBorder = Color(0xFFDCE5E0);
  static const Color canWaitText = Color(0xFF5D7567);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.paleMintBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sagePrimary,
        primary: AppColors.sagePrimary,
        surface: AppColors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paleMintBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.forestTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.forestTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderSage, width: 1.2),
        ),
      ),
      dividerColor: AppColors.borderSage,
    );
  }
}
