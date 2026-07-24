import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── FarmFeed Color Palette ────────────────────────────────────────────────────
class FarmColors {
  FarmColors._();

  // Greens
  static const Color darkGreen = Color(0xFF1B4332);
  static const Color primaryGreen = Color(0xFF2D6A4F);
  static const Color mediumGreen = Color(0xFF40916C);
  static const Color lightGreen = Color(0xFF52B788);
  static const Color accentLime = Color(0xFF74C69D);
  static const Color sageLight = Color(0xFFB7E4C7);
  static const Color mintFaint = Color(0xFFD8F3DC);
  static const Color mintBackground = Color(0xFFF0FAF4);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAF9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2EFE8);
  static const Color textPrimary = Color(0xFF081C15);
  static const Color textSecondary = Color(0xFF4A6B57);
  static const Color textHint = Color(0xFF8FAF9A);

  // Semantic
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color info = Color(0xFF0284C7);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkGreen, primaryGreen, mediumGreen],
  );
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, mediumGreen],
  );
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mintFaint, mintBackground],
  );
}

// ── FarmFeed Text Styles ──────────────────────────────────────────────────────
class FarmTextStyles {
  FarmTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: FarmColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: FarmColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: FarmColors.textPrimary,
      );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: FarmColors.textPrimary,
      );

  static TextStyle get titleLarge => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FarmColors.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: FarmColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: FarmColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: FarmColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: FarmColors.textHint,
      );

  static TextStyle get labelLarge => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: FarmColors.white,
        letterSpacing: 0.3,
      );

  static TextStyle get buttonText => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );
}

// ── FarmFeed Theme ─────────────────────────────────────────────────────────────
class FarmTheme {
  FarmTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FarmColors.primaryGreen,
          primary: FarmColors.primaryGreen,
          secondary: FarmColors.accentLime,
          surface: FarmColors.white,
          error: FarmColors.error,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: FarmColors.offWhite,
        fontFamily: GoogleFonts.poppins().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: FarmColors.darkGreen,
          foregroundColor: FarmColors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: FarmColors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FarmColors.primaryGreen,
            foregroundColor: FarmColors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: FarmColors.primaryGreen,
            side: const BorderSide(color: FarmColors.primaryGreen, width: 1.5),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: FarmColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: FarmColors.borderLight, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: FarmColors.borderLight, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: FarmColors.primaryGreen, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: FarmColors.error, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: FarmColors.error, width: 1.8),
          ),
          labelStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: FarmColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: FarmColors.textSecondary,
          ),
          prefixIconColor: FarmColors.mediumGreen,
        ),
        cardTheme: CardThemeData(
          color: FarmColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: FarmColors.borderLight, width: 1),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: FarmColors.mintFaint,
          selectedColor: FarmColors.primaryGreen,
          labelStyle:
              GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dividerTheme: const DividerThemeData(
          color: FarmColors.borderLight,
          thickness: 1,
          space: 24,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: FarmColors.darkGreen,
          contentTextStyle:
              GoogleFonts.poppins(color: FarmColors.white, fontSize: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
