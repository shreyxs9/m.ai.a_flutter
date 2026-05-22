import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'maia_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build({
    required MaiaThemeKey theme,
    required MaiaThemeMode mode,
  }) {
    final tokens = MaiaThemeTokens.resolve(theme, mode);
    final colorScheme = ColorScheme(
      brightness: mode.brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentInk,
      primaryContainer: tokens.accentSoft,
      onPrimaryContainer: tokens.accent,
      secondary: tokens.success,
      onSecondary: tokens.background,
      secondaryContainer: tokens.success.withValues(
        alpha: tokens.isDark ? 0.16 : 0.11,
      ),
      onSecondaryContainer: tokens.success,
      error: tokens.danger,
      onError: tokens.accentInk,
      errorContainer: tokens.danger.withValues(
        alpha: tokens.isDark ? 0.16 : 0.11,
      ),
      onErrorContainer: tokens.danger,
      surface: tokens.background,
      onSurface: tokens.text,
      tertiary: tokens.accentSoft,
      onTertiary: tokens.accent,
      outline: tokens.border,
      outlineVariant: tokens.faint,
      surfaceContainerLowest: tokens.background,
      surfaceContainerLow: tokens.backgroundRaised,
      surfaceContainer: tokens.backgroundCard,
      surfaceContainerHigh: tokens.backgroundCard,
      surfaceContainerHighest: tokens.backgroundRaised,
      onSurfaceVariant: tokens.dim,
    );

    final textTheme = _textTheme(tokens);
    final radius = BorderRadius.circular(tokens.radius);

    return ThemeData(
      useMaterial3: true,
      brightness: mode.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      textTheme: textTheme,
      fontFamily: _fontFamily(tokens.bodyFont),
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tokens.background,
        foregroundColor: tokens.text,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: tokens.text),
      ),
      cardTheme: CardThemeData(
        color: tokens.backgroundCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.backgroundRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius + 10),
          side: BorderSide(color: tokens.border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: tokens.text,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.dim),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radius + 14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.backgroundCard,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.text),
        actionTextColor: tokens.accent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius + 4),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.border),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.accentSoft,
        circularTrackColor: tokens.accentSoft,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.backgroundRaised,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.danger.withValues(alpha: 0.65)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: tokens.danger),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.faint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          elevation: 0,
          shadowColor: tokens.accentSoft,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          disabledBackgroundColor: tokens.faint.withValues(alpha: 0.16),
          disabledForegroundColor: tokens.faint,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.text,
          side: BorderSide(color: tokens.border),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.text,
          hoverColor: tokens.glassBorder,
          highlightColor: tokens.accentSoft,
          focusColor: tokens.accentSoft,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: tokens.backgroundCard,
          foregroundColor: tokens.dim,
          selectedBackgroundColor: tokens.accentSoft,
          selectedForegroundColor: tokens.accent,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: tokens.text),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.accentSoft,
        selectedColor: tokens.accent,
        labelStyle: textTheme.labelMedium?.copyWith(color: tokens.text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: tokens.accentInk,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 12)),
          side: BorderSide(color: tokens.border),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.accent,
        selectionColor: tokens.accentSoft,
        selectionHandleColor: tokens.accent,
      ),
    );
  }

  static ThemeData get light {
    return build(theme: MaiaThemeKey.warm, mode: MaiaThemeMode.light);
  }

  static ThemeData get dark {
    return build(theme: MaiaThemeKey.warm, mode: MaiaThemeMode.dark);
  }

  static TextTheme _textTheme(MaiaThemeTokens tokens) {
    final base = _googleTextTheme(tokens.bodyFont);
    final display = _googleTextTheme(tokens.displayFont);
    final mono = _googleTextTheme(tokens.monoFont);

    return base
        .copyWith(
          displayLarge: display.displayLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
          displayMedium: display.displayMedium?.copyWith(letterSpacing: 0),
          displaySmall: display.displaySmall?.copyWith(letterSpacing: 0),
          headlineLarge: display.headlineLarge,
          headlineMedium: display.headlineMedium,
          headlineSmall: display.headlineSmall,
          titleLarge: display.titleLarge,
          labelSmall: mono.labelSmall,
        )
        .apply(
          bodyColor: tokens.text,
          displayColor: tokens.text,
          decorationColor: tokens.accent,
        );
  }

  static TextTheme _googleTextTheme(MaiaFontFamily font) {
    return switch (font) {
      MaiaFontFamily.dmSans => GoogleFonts.dmSansTextTheme(),
      MaiaFontFamily.dmMono => GoogleFonts.dmMonoTextTheme(),
      MaiaFontFamily.fraunces => GoogleFonts.frauncesTextTheme(),
      MaiaFontFamily.jetBrainsMono => GoogleFonts.jetBrainsMonoTextTheme(),
    };
  }

  static String _fontFamily(MaiaFontFamily font) {
    return switch (font) {
      MaiaFontFamily.dmSans => GoogleFonts.dmSans().fontFamily!,
      MaiaFontFamily.dmMono => GoogleFonts.dmMono().fontFamily!,
      MaiaFontFamily.fraunces => GoogleFonts.fraunces().fontFamily!,
      MaiaFontFamily.jetBrainsMono => GoogleFonts.jetBrainsMono().fontFamily!,
    };
  }
}
