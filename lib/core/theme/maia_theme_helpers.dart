import 'package:flutter/material.dart';

import 'maia_theme_tokens.dart';

extension MaiaThemeContext on BuildContext {
  MaiaThemeTokens get maia => MaiaThemeTokens.of(this);
}

extension MaiaThemeDataHelpers on ThemeData {
  MaiaThemeTokens get maia => extension<MaiaThemeTokens>()!;
}

extension MaiaThemeTokenHelpers on MaiaThemeTokens {
  Color get surface => background;
  Color get raisedSurface => backgroundRaised;
  Color get cardSurface => backgroundCard;
  Color get borderColor => border;
  Color get dangerColor => danger;
  Color get successColor => success;
  Color get accentColor => accent;

  BoxDecoration surfaceDecoration({
    Color? color,
    BorderRadiusGeometry? borderRadius,
    bool withBorder = true,
    bool withShadow = false,
  }) {
    return BoxDecoration(
      color: color ?? backgroundCard,
      borderRadius: borderRadius ?? this.borderRadius,
      border: withBorder ? Border.all(color: border) : null,
      boxShadow: withShadow ? shadow : null,
    );
  }

  BoxDecoration raisedSurfaceDecoration({
    bool withBorder = true,
    bool withShadow = false,
  }) {
    return surfaceDecoration(
      color: backgroundRaised,
      withBorder: withBorder,
      withShadow: withShadow,
    );
  }

  BoxDecoration glassSurfaceDecoration() {
    return BoxDecoration(
      color: glass,
      borderRadius: borderRadius,
      border: Border.all(color: glassBorder),
    );
  }

  BoxDecoration accentSurfaceDecoration() {
    return BoxDecoration(
      color: accentSoft,
      borderRadius: borderRadius,
      border: Border.all(color: accentSoft),
    );
  }

  BoxDecoration successSurfaceDecoration() {
    return BoxDecoration(
      color: success.withValues(alpha: isDark ? 0.14 : 0.10),
      borderRadius: borderRadius,
      border: Border.all(color: success.withValues(alpha: 0.26)),
    );
  }

  BoxDecoration dangerSurfaceDecoration() {
    return BoxDecoration(
      color: danger.withValues(alpha: isDark ? 0.14 : 0.10),
      borderRadius: borderRadius,
      border: Border.all(color: danger.withValues(alpha: 0.26)),
    );
  }
}
