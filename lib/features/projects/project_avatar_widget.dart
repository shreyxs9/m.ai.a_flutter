import 'package:flutter/material.dart';

import '../../core/theme/maia_theme_helpers.dart';
import '../../models/models.dart';
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

class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    required this.name,
    super.key,
    this.avatarUrl,
    this.user,
    this.radius = 18,
    this.initialsChars = 2,
    this.color,
  });

  final String name;
  final String? avatarUrl;
  final User? user;
  final double radius;
  final int initialsChars;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveName = (user?.name ?? name).trim();
    final effectiveUrl = user?.avatarUrl ?? avatarUrl;
    final fallbackColor =
        color ?? _avatarColor(effectiveName, context.maia.accent);
    final initials = _initials(effectiveName, initialsChars);
    final size = radius * 2;
    final fallback = ColoredBox(
      color: fallbackColor.withValues(alpha: 0.18),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: fallbackColor,
            fontSize: (size * 0.34).clamp(9.0, 22.0).toDouble(),
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: effectiveUrl == null || effectiveUrl.isEmpty
              ? fallback
              : Image.network(
                  effectiveUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (context, error, stackTrace) => fallback,
                  loadingBuilder: (context, child, loadingProgress) =>
                      loadingProgress == null ? child : fallback,
                ),
        ),
      ),
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

String _initials(String value, int chars) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(chars)
      .map((part) => part[0].toUpperCase())
      .join();
  return parts.isEmpty ? '?' : parts;
}

Color _avatarColor(String value, Color fallback) {
  if (value.trim().isEmpty) {
    return fallback;
  }
  final colors = <Color>[
    const Color(0xFF0F9F6E),
    const Color(0xFF2563EB),
    const Color(0xFFB45309),
    const Color(0xFFBE123C),
    const Color(0xFF7C3AED),
    const Color(0xFF0E7490),
  ];
  final index = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return colors[index % colors.length];
}
