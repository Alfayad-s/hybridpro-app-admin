import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors aligned with Hybrid Pro Mobile App `globals.css` (dark default).
class HpColors {
  static const background = Color(0xFF0B0B0F);
  static const foreground = Color(0xFFFFFFFF);
  static const card = Color(0xFF1C1C22);
  static const popover = Color(0xFF141419);
  static const primary = Color(0xFFA0D028);
  static const primaryForeground = Color(0xFF0B0B0F);
  static const secondary = Color(0xFF141419);
  static const muted = Color(0xFF141419);
  static const mutedForeground = Color(0xFF9CA3AF);
  static const accent = Color(0xFF141419);
  static const accentForeground = Color(0xFFA0D028);
  static const destructive = Color(0xFFEF4444);
  static const border = Color(0x14FFFFFF); // ~8% white
  static const navBar = Color(0xFF000000);
  static const elevated = Color(0xFF1C1C22);
  static const subtle = Color(0xFF141419);
  static const ink = Color(0xFF0B0B0F);

  // Light tokens (optional)
  static const backgroundLight = Color(0xFFF4F4F6);
  static const foregroundLight = Color(0xFF0B0B0F);
  static const primaryLight = Color(0xFF8BB820);
  static const mutedForegroundLight = Color(0xFF6B7280);
  static const cardLight = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData dark() {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: HpColors.foreground,
      displayColor: HpColors.foreground,
    );

    final scheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: HpColors.primary,
      onPrimary: HpColors.primaryForeground,
      secondary: HpColors.secondary,
      onSecondary: HpColors.primary,
      surface: HpColors.card,
      onSurface: HpColors.foreground,
      error: HpColors.destructive,
      onError: Colors.white,
      outline: HpColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: HpColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: HpColors.background,
        foregroundColor: HpColors.foreground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HpColors.foreground,
        ),
        iconTheme: const IconThemeData(color: HpColors.foreground),
      ),
      dividerColor: HpColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HpColors.popover,
        hintStyle: const TextStyle(color: HpColors.mutedForeground),
        labelStyle: const TextStyle(color: HpColors.mutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HpColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HpColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: HpColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HpColors.primary,
          foregroundColor: HpColors.primaryForeground,
          minimumSize: const Size.fromHeight(48),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HpColors.foreground,
          side: const BorderSide(color: HpColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HpColors.subtle,
        selectedColor: HpColors.primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: HpColors.foreground),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: HpColors.primary),
        side: const BorderSide(color: HpColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HpColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HpColors.border),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HpColors.primary,
        foregroundColor: HpColors.primaryForeground,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: HpColors.mutedForeground,
        textColor: HpColors.foreground,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HpColors.card,
        contentTextStyle: GoogleFonts.inter(color: HpColors.foreground),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HpColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HpColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HpColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  /// Kept for completeness; app defaults to [dark].
  static ThemeData light() {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: HpColors.foregroundLight,
      displayColor: HpColors.foregroundLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: HpColors.primaryLight,
        onPrimary: HpColors.ink,
        surface: HpColors.cardLight,
        onSurface: HpColors.foregroundLight,
      ),
      scaffoldBackgroundColor: HpColors.backgroundLight,
    );
  }
}
