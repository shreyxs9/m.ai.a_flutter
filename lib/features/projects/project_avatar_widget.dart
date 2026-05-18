import 'package:flutter/material.dart';

import '../../core/theme/maia_theme_helpers.dart';
import 'project_icon_registry.dart';

class ProjectAvatarWidget extends StatelessWidget {
  const ProjectAvatarWidget({
    required this.code,
    required this.accent,
    this.icon,
    this.size = 44,
    this.radius = 12,
    super.key,
  });

  final String code;
  final String? icon;
  final String accent;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final accentColor = _parseColor(accent) ?? tokens.accent;
    final iconData = ProjectIconRegistry.resolve(icon);
    final initials = code.trim().isEmpty ? 'MA' : code.trim().toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: tokens.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: iconData == null
          ? Text(
              initials.length > 3 ? initials.substring(0, 3) : initials,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                fontSize: size * 0.28,
              ),
            )
          : Icon(iconData, size: size * 0.48, color: accentColor),
    );
  }
}

Color? _parseColor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (hex.length == 6) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed != null) {
      return Color(0xFF000000 | parsed);
    }
  }
  if (hex.length == 8) {
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed != null) {
      return Color(parsed);
    }
  }
  return null;
}
