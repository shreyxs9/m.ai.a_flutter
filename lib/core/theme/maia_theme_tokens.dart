import 'package:flutter/material.dart';

enum MaiaThemeKey {
  warm('warm', 'Paper', 'Old paper, evening light'),
  cool('cool', 'Terminal', 'Monospaced, green on ink'),
  editorial('editorial', 'Press', 'Editorial ivy, museum light'),
  brutalist('brutalist', 'Bold', 'High contrast, hard edges');

  const MaiaThemeKey(this.storageValue, this.label, this.blurb);

  final String storageValue;
  final String label;
  final String blurb;

  static MaiaThemeKey fromStorage(String? value) {
    return MaiaThemeKey.values.firstWhere(
      (theme) => theme.storageValue == value,
      orElse: () => MaiaThemeKey.warm,
    );
  }
}

enum MaiaThemeMode {
  light('light'),
  dark('dark');

  const MaiaThemeMode(this.storageValue);

  final String storageValue;

  Brightness get brightness {
    return switch (this) {
      MaiaThemeMode.light => Brightness.light,
      MaiaThemeMode.dark => Brightness.dark,
    };
  }

  ThemeMode get materialThemeMode {
    return switch (this) {
      MaiaThemeMode.light => ThemeMode.light,
      MaiaThemeMode.dark => ThemeMode.dark,
    };
  }

  static MaiaThemeMode fromStorage(String? value) {
    return MaiaThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => MaiaThemeMode.light,
    );
  }
}

enum MaiaFontFamily {
  dmSans,
  dmMono,
  fraunces,
  jetBrainsMono,
}

@immutable
class MaiaThemeTokens extends ThemeExtension<MaiaThemeTokens> {
  const MaiaThemeTokens({
    required this.themeKey,
    required this.mode,
    required this.label,
    required this.blurb,
    required this.bodyFont,
    required this.displayFont,
    required this.monoFont,
    required this.radius,
    required this.shadow,
    required this.shadowHover,
    required this.background,
    required this.backgroundRaised,
    required this.backgroundCard,
    required this.border,
    required this.text,
    required this.dim,
    required this.faint,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.glass,
    required this.glassBorder,
  });

  final MaiaThemeKey themeKey;
  final MaiaThemeMode mode;
  final String label;
  final String blurb;
  final MaiaFontFamily bodyFont;
  final MaiaFontFamily displayFont;
  final MaiaFontFamily monoFont;
  final double radius;
  final List<BoxShadow> shadow;
  final List<BoxShadow> shadowHover;
  final Color background;
  final Color backgroundRaised;
  final Color backgroundCard;
  final Color border;
  final Color text;
  final Color dim;
  final Color faint;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color success;
  final Color danger;
  final Color glass;
  final Color glassBorder;

  bool get isDark => mode == MaiaThemeMode.dark;

  BorderRadius get borderRadius => BorderRadius.circular(radius);

  BorderSide get borderSide => BorderSide(color: border);

  @override
  MaiaThemeTokens copyWith({
    MaiaThemeKey? themeKey,
    MaiaThemeMode? mode,
    String? label,
    String? blurb,
    MaiaFontFamily? bodyFont,
    MaiaFontFamily? displayFont,
    MaiaFontFamily? monoFont,
    double? radius,
    List<BoxShadow>? shadow,
    List<BoxShadow>? shadowHover,
    Color? background,
    Color? backgroundRaised,
    Color? backgroundCard,
    Color? border,
    Color? text,
    Color? dim,
    Color? faint,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? success,
    Color? danger,
    Color? glass,
    Color? glassBorder,
  }) {
    return MaiaThemeTokens(
      themeKey: themeKey ?? this.themeKey,
      mode: mode ?? this.mode,
      label: label ?? this.label,
      blurb: blurb ?? this.blurb,
      bodyFont: bodyFont ?? this.bodyFont,
      displayFont: displayFont ?? this.displayFont,
      monoFont: monoFont ?? this.monoFont,
      radius: radius ?? this.radius,
      shadow: shadow ?? this.shadow,
      shadowHover: shadowHover ?? this.shadowHover,
      background: background ?? this.background,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      border: border ?? this.border,
      text: text ?? this.text,
      dim: dim ?? this.dim,
      faint: faint ?? this.faint,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
    );
  }

  @override
  MaiaThemeTokens lerp(ThemeExtension<MaiaThemeTokens>? other, double t) {
    if (other is! MaiaThemeTokens) {
      return this;
    }

    return MaiaThemeTokens(
      themeKey: t < 0.5 ? themeKey : other.themeKey,
      mode: t < 0.5 ? mode : other.mode,
      label: t < 0.5 ? label : other.label,
      blurb: t < 0.5 ? blurb : other.blurb,
      bodyFont: t < 0.5 ? bodyFont : other.bodyFont,
      displayFont: t < 0.5 ? displayFont : other.displayFont,
      monoFont: t < 0.5 ? monoFont : other.monoFont,
      radius: _lerpDouble(radius, other.radius, t),
      shadow: t < 0.5 ? shadow : other.shadow,
      shadowHover: t < 0.5 ? shadowHover : other.shadowHover,
      background: Color.lerp(background, other.background, t)!,
      backgroundRaised: Color.lerp(
        backgroundRaised,
        other.backgroundRaised,
        t,
      )!,
      backgroundCard: Color.lerp(backgroundCard, other.backgroundCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      dim: Color.lerp(dim, other.dim, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
    );
  }

  static MaiaThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<MaiaThemeTokens>()!;
  }

  static MaiaThemeTokens resolve(MaiaThemeKey theme, MaiaThemeMode mode) {
    return switch ((theme, mode)) {
      (MaiaThemeKey.warm, MaiaThemeMode.dark) => _warmDark,
      (MaiaThemeKey.warm, MaiaThemeMode.light) => _warmLight,
      (MaiaThemeKey.cool, MaiaThemeMode.dark) => _coolDark,
      (MaiaThemeKey.cool, MaiaThemeMode.light) => _coolLight,
      (MaiaThemeKey.editorial, MaiaThemeMode.dark) => _editorialDark,
      (MaiaThemeKey.editorial, MaiaThemeMode.light) => _editorialLight,
      (MaiaThemeKey.brutalist, MaiaThemeMode.dark) => _brutalistDark,
      (MaiaThemeKey.brutalist, MaiaThemeMode.light) => _brutalistLight,
    };
  }
}

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

List<BoxShadow> _softShadow(Color color) {
  return [
    BoxShadow(
      color: color.withValues(alpha: 0.22),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.24),
      blurRadius: 24,
      spreadRadius: -12,
      offset: const Offset(0, 8),
    ),
  ];
}

List<BoxShadow> _softShadowHover(Color color) {
  return [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.32),
      blurRadius: 40,
      spreadRadius: -16,
      offset: const Offset(0, 16),
    ),
  ];
}

List<BoxShadow> _coolShadow(double alpha) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: alpha),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: alpha + 0.10),
      blurRadius: 14,
      spreadRadius: -8,
      offset: const Offset(0, 4),
    ),
  ];
}

List<BoxShadow> _editorialShadow(double alpha) {
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: alpha),
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF08140A).withValues(alpha: alpha + 0.26),
      blurRadius: 18,
      spreadRadius: -10,
      offset: const Offset(0, 4),
    ),
  ];
}

List<BoxShadow> _brutalistShadow(Color color) {
  return [
    BoxShadow(
      color: color,
      offset: const Offset(3, 3),
    ),
  ];
}

const _warmBase = Color(0xFF180E04);

final _warmDark = MaiaThemeTokens(
  themeKey: MaiaThemeKey.warm,
  mode: MaiaThemeMode.dark,
  label: MaiaThemeKey.warm.label,
  blurb: MaiaThemeKey.warm.blurb,
  bodyFont: MaiaFontFamily.dmSans,
  displayFont: MaiaFontFamily.fraunces,
  monoFont: MaiaFontFamily.dmMono,
  radius: 14,
  shadow: _softShadow(_warmBase),
  shadowHover: _softShadowHover(_warmBase),
  background: const Color(0xFF15110C),
  backgroundRaised: const Color(0xFF1C1812),
  backgroundCard: const Color(0xFF221D16),
  border: const Color.fromRGBO(248, 232, 200, 0.09),
  text: const Color(0xFFF5EBD8),
  dim: const Color.fromRGBO(245, 235, 216, 0.68),
  faint: const Color.fromRGBO(245, 235, 216, 0.38),
  accent: const Color(0xFFE8B26A),
  accentInk: const Color(0xFF1A1208),
  accentSoft: const Color.fromRGBO(232, 178, 106, 0.14),
  success: const Color(0xFF9CC381),
  danger: const Color(0xFFD88A7A),
  glass: const Color.fromRGBO(232, 178, 106, 0.04),
  glassBorder: const Color.fromRGBO(232, 178, 106, 0.10),
);

final _warmLight = MaiaThemeTokens(
  themeKey: MaiaThemeKey.warm,
  mode: MaiaThemeMode.light,
  label: MaiaThemeKey.warm.label,
  blurb: MaiaThemeKey.warm.blurb,
  bodyFont: MaiaFontFamily.dmSans,
  displayFont: MaiaFontFamily.fraunces,
  monoFont: MaiaFontFamily.dmMono,
  radius: 14,
  shadow: _softShadow(_warmBase),
  shadowHover: _softShadowHover(_warmBase),
  background: const Color(0xFFECE0C4),
  backgroundRaised: const Color(0xFFF5EAD0),
  backgroundCard: const Color(0xFFF7EFD9),
  border: const Color.fromRGBO(48, 28, 10, 0.14),
  text: const Color(0xFF1D140A),
  dim: const Color.fromRGBO(29, 20, 10, 0.70),
  faint: const Color.fromRGBO(29, 20, 10, 0.38),
  accent: const Color(0xFFA8682A),
  accentInk: const Color(0xFFFFF5E1),
  accentSoft: const Color.fromRGBO(168, 104, 42, 0.10),
  success: const Color(0xFF4F6A30),
  danger: const Color(0xFFB8563F),
  glass: const Color.fromRGBO(255, 255, 255, 0.55),
  glassBorder: const Color.fromRGBO(168, 104, 42, 0.12),
);

final _coolDark = MaiaThemeTokens(
  themeKey: MaiaThemeKey.cool,
  mode: MaiaThemeMode.dark,
  label: MaiaThemeKey.cool.label,
  blurb: MaiaThemeKey.cool.blurb,
  bodyFont: MaiaFontFamily.jetBrainsMono,
  displayFont: MaiaFontFamily.jetBrainsMono,
  monoFont: MaiaFontFamily.jetBrainsMono,
  radius: 4,
  shadow: _coolShadow(0.14),
  shadowHover: _coolShadow(0.18),
  background: const Color(0xFF0B0F0D),
  backgroundRaised: const Color(0xFF131816),
  backgroundCard: const Color(0xFF171D1A),
  border: const Color.fromRGBO(180, 220, 190, 0.11),
  text: const Color(0xFFD4E4D8),
  dim: const Color.fromRGBO(212, 228, 216, 0.72),
  faint: const Color.fromRGBO(212, 228, 216, 0.38),
  accent: const Color(0xFF7CE3A6),
  accentInk: const Color(0xFF07120C),
  accentSoft: const Color.fromRGBO(124, 227, 166, 0.10),
  success: const Color(0xFFE8C85A),
  danger: const Color(0xFFFF7A6A),
  glass: const Color.fromRGBO(124, 227, 166, 0.04),
  glassBorder: const Color.fromRGBO(124, 227, 166, 0.10),
);

final _coolLight = MaiaThemeTokens(
  themeKey: MaiaThemeKey.cool,
  mode: MaiaThemeMode.light,
  label: MaiaThemeKey.cool.label,
  blurb: MaiaThemeKey.cool.blurb,
  bodyFont: MaiaFontFamily.jetBrainsMono,
  displayFont: MaiaFontFamily.jetBrainsMono,
  monoFont: MaiaFontFamily.jetBrainsMono,
  radius: 4,
  shadow: _coolShadow(0.14),
  shadowHover: _coolShadow(0.18),
  background: const Color(0xFFD6DEE0),
  backgroundRaised: const Color(0xFFE2E9EA),
  backgroundCard: const Color(0xFFE8EEEF),
  border: const Color.fromRGBO(15, 40, 45, 0.14),
  text: const Color(0xFF081918),
  dim: const Color.fromRGBO(8, 25, 24, 0.72),
  faint: const Color.fromRGBO(8, 25, 24, 0.38),
  accent: const Color(0xFF0F6A52),
  accentInk: const Color(0xFFEAFFF4),
  accentSoft: const Color.fromRGBO(15, 106, 82, 0.08),
  success: const Color(0xFF8A6D00),
  danger: const Color(0xFFB22E2E),
  glass: const Color.fromRGBO(255, 255, 255, 0.55),
  glassBorder: const Color.fromRGBO(15, 106, 82, 0.12),
);

final _editorialDark = MaiaThemeTokens(
  themeKey: MaiaThemeKey.editorial,
  mode: MaiaThemeMode.dark,
  label: MaiaThemeKey.editorial.label,
  blurb: MaiaThemeKey.editorial.blurb,
  bodyFont: MaiaFontFamily.fraunces,
  displayFont: MaiaFontFamily.fraunces,
  monoFont: MaiaFontFamily.dmMono,
  radius: 6,
  shadow: _editorialShadow(0.04),
  shadowHover: _editorialShadow(0.06),
  background: const Color(0xFF0D120F),
  backgroundRaised: const Color(0xFF151C17),
  backgroundCard: const Color(0xFF1A221C),
  border: const Color.fromRGBO(190, 220, 180, 0.10),
  text: const Color(0xFFEBE8D5),
  dim: const Color.fromRGBO(235, 232, 213, 0.70),
  faint: const Color.fromRGBO(235, 232, 213, 0.38),
  accent: const Color(0xFFB8A265),
  accentInk: const Color(0xFF1A1608),
  accentSoft: const Color.fromRGBO(184, 162, 101, 0.12),
  success: const Color(0xFF8AB76F),
  danger: const Color(0xFFD47A6A),
  glass: const Color.fromRGBO(184, 162, 101, 0.04),
  glassBorder: const Color.fromRGBO(184, 162, 101, 0.10),
);

final _editorialLight = MaiaThemeTokens(
  themeKey: MaiaThemeKey.editorial,
  mode: MaiaThemeMode.light,
  label: MaiaThemeKey.editorial.label,
  blurb: MaiaThemeKey.editorial.blurb,
  bodyFont: MaiaFontFamily.fraunces,
  displayFont: MaiaFontFamily.fraunces,
  monoFont: MaiaFontFamily.dmMono,
  radius: 6,
  shadow: _editorialShadow(0.04),
  shadowHover: _editorialShadow(0.06),
  background: const Color(0xFFEFE8D4),
  backgroundRaised: const Color(0xFFF6F0DD),
  backgroundCard: const Color(0xFFF8F2E0),
  border: const Color.fromRGBO(40, 30, 14, 0.16),
  text: const Color(0xFF1E1808),
  dim: const Color.fromRGBO(30, 24, 8, 0.72),
  faint: const Color.fromRGBO(30, 24, 8, 0.40),
  accent: const Color(0xFF7A5A1C),
  accentInk: const Color(0xFFFCF8EA),
  accentSoft: const Color.fromRGBO(122, 90, 28, 0.10),
  success: const Color(0xFF4F6E32),
  danger: const Color(0xFFA84C38),
  glass: const Color.fromRGBO(255, 255, 255, 0.55),
  glassBorder: const Color.fromRGBO(122, 90, 28, 0.12),
);

final _brutalistDark = MaiaThemeTokens(
  themeKey: MaiaThemeKey.brutalist,
  mode: MaiaThemeMode.dark,
  label: MaiaThemeKey.brutalist.label,
  blurb: MaiaThemeKey.brutalist.blurb,
  bodyFont: MaiaFontFamily.dmSans,
  displayFont: MaiaFontFamily.dmSans,
  monoFont: MaiaFontFamily.dmMono,
  radius: 0,
  shadow: _brutalistShadow(Colors.black.withValues(alpha: 0.18)),
  shadowHover: _brutalistShadow(const Color.fromRGBO(255, 92, 38, 0.35)),
  background: const Color(0xFF0A0A0A),
  backgroundRaised: const Color(0xFF141414),
  backgroundCard: const Color(0xFF191919),
  border: const Color.fromRGBO(255, 255, 255, 0.18),
  text: const Color(0xFFFAFAFA),
  dim: const Color.fromRGBO(250, 250, 250, 0.72),
  faint: const Color.fromRGBO(250, 250, 250, 0.38),
  accent: const Color(0xFFFF5C26),
  accentInk: const Color(0xFFFFFFFF),
  accentSoft: const Color.fromRGBO(255, 92, 38, 0.10),
  success: const Color(0xFF6CCE5C),
  danger: const Color(0xFFFF2E4D),
  glass: const Color.fromRGBO(255, 92, 38, 0.04),
  glassBorder: const Color.fromRGBO(255, 92, 38, 0.10),
);

final _brutalistLight = MaiaThemeTokens(
  themeKey: MaiaThemeKey.brutalist,
  mode: MaiaThemeMode.light,
  label: MaiaThemeKey.brutalist.label,
  blurb: MaiaThemeKey.brutalist.blurb,
  bodyFont: MaiaFontFamily.dmSans,
  displayFont: MaiaFontFamily.dmSans,
  monoFont: MaiaFontFamily.dmMono,
  radius: 0,
  shadow: _brutalistShadow(Colors.black.withValues(alpha: 0.18)),
  shadowHover: _brutalistShadow(const Color.fromRGBO(255, 92, 38, 0.35)),
  background: const Color(0xFFECEDEE),
  backgroundRaised: const Color(0xFFF6F7F8),
  backgroundCard: const Color(0xFFFFFFFF),
  border: const Color.fromRGBO(0, 0, 0, 0.18),
  text: const Color(0xFF0A0A0A),
  dim: const Color.fromRGBO(10, 10, 10, 0.74),
  faint: const Color.fromRGBO(10, 10, 10, 0.42),
  accent: const Color(0xFFC43A10),
  accentInk: const Color(0xFFFFFFFF),
  accentSoft: const Color.fromRGBO(196, 58, 16, 0.08),
  success: const Color(0xFF267022),
  danger: const Color(0xFFC41030),
  glass: const Color.fromRGBO(255, 255, 255, 0.55),
  glassBorder: const Color.fromRGBO(196, 58, 16, 0.12),
);
