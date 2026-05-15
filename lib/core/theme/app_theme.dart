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
      secondary: tokens.success,
      onSecondary: tokens.background,
      error: tokens.danger,
      onError: tokens.accentInk,
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
      dividerTheme: DividerThemeData(color: tokens.border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.backgroundRaised,
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
        hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.faint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.text,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textTheme.labelLarge,
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

    return base.copyWith(
      displayLarge: display.displayLarge,
      displayMedium: display.displayMedium,
      displaySmall: display.displaySmall,
      headlineLarge: display.headlineLarge,
      headlineMedium: display.headlineMedium,
      headlineSmall: display.headlineSmall,
      titleLarge: display.titleLarge,
      labelSmall: mono.labelSmall,
    ).apply(
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
