import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF086547);
  static const Color primaryGreenDark = Color(0xFF022B20);
  static const Color primaryGreenLight = Color(0xFF0D5C45);

  // Surfaces & Backgrounds
  static const Color surfaceBackground = Color(
    0xFFF3F5F8,
  ); // Crisp canvas that separates white work surfaces.
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceCardMuted = Color(0xFFEDF1F5);
  static const Color actionSurface = Color(0xFFE1F3EA);

  // Accents & Semantics
  static const Color accentGreen = Color(0xFF159A68);
  static const Color textPrimary = Color(0xFF111827); // Dark Slate
  static const Color textSecondary = Color(
    0xFF53615B,
  ); // Muted, readable slate-green
  static const Color textMuted = Color(0xFF66736D); // Readable secondary labels

  // Alert & Warning States
  static const Color alertCritical = Color(0xFFEF4444); // Red
  static const Color warningLow = Color(0xFFF59E0B); // Amber

  // Pill & Badge Backgrounds
  static const Color badgeGreenBg = Color(0xFFE1F3EA);
  static const Color badgeGreenText = Color(0xFF065F46);
  static const Color badgeAmberBg = Color(0xFFFEF3C7);
  static const Color badgeAmberText = Color(0xFF92400E);
  static const Color badgeRedBg = Color(0xFFFEE2E2);
  static const Color badgeRedText = Color(0xFF991B1B);
  static const Color badgeNeutralBg = Color(0xFFE5E7EB);
  static const Color badgeNeutralText = Color(0xFF374151);
  static const Color badgeInfoBg = Color(0xFFE8EDFF);
  static const Color badgeInfoText = Color(0xFF3949A3);

  // Borders & Dividers
  static const Color dividerColor = Color(0xFFDCE3E9);
  static const Color outlineColor = Color(0xFFB7C4CE);
}

class AppNumbers {
  static const price = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryGreen,
    height: 1.15,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const total = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const metric = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class AppButtonStyles {
  static ButtonStyle get tonal => OutlinedButton.styleFrom(
    backgroundColor: AppColors.actionSurface,
    foregroundColor: AppColors.primaryGreen,
    disabledBackgroundColor: AppColors.surfaceCardMuted,
    disabledForegroundColor: AppColors.textMuted,
    side: BorderSide.none,
    minimumSize: const Size(48, 48),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}

class AppTheme {
  static const String fontFamily = 'Satoshi';

  static ThemeData get lightTheme {
    const TextTheme satoshiTextTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.25,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.15,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.05,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: 0,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
        letterSpacing: 0.15,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
        height: 1.25,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
        height: 1.25,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
        height: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.surfaceBackground,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primaryGreen,
            surface: AppColors.surfaceCard,
          ).copyWith(
            primary: AppColors.primaryGreen,
            onPrimary: Colors.white,
            primaryContainer: AppColors.primaryGreenLight,
            onPrimaryContainer: Colors.white,
            secondary: AppColors.accentGreen,
            onSecondary: Colors.white,
            error: AppColors.alertCritical,
            onError: Colors.white,
            surface: AppColors.surfaceCard,
            onSurface: AppColors.textPrimary,
            outline: AppColors.outlineColor,
          ),
      textTheme: satoshiTextTheme,
      primaryTextTheme: satoshiTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.15,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.dividerColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.actionSurface,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
              letterSpacing: 0.1,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.1,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryGreen, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 22);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          backgroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.outlineColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryGreen,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryGreen
                : AppColors.dividerColor,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.actionSurface
                : Colors.white,
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.primaryGreen),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.dividerColor),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
