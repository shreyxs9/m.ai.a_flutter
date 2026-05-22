import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/maia_theme_helpers.dart';
import '../../core/theme/maia_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';

class ThemePreviewScreen extends ConsumerWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref
        .watch(themeControllerProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MaiaThemeSelection(),
        );
    final controller = ref.read(themeControllerProvider.notifier);
    final tokens = context.maia;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Preview'),
        actions: [
          IconButton(
            tooltip: 'Toggle mode',
            onPressed: controller.toggleMode,
            icon: Icon(
              selection.mode == MaiaThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 3.4 : 1.65,
                  children: [
                    for (final theme in MaiaThemeKey.values)
                      _ThemePreviewCard(
                        theme: theme,
                        mode: selection.mode,
                        selected: selection.theme == theme,
                        onTap: () => controller.setTheme(theme),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<MaiaThemeMode>(
              segments: const [
                ButtonSegment(
                  value: MaiaThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: MaiaThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {selection.mode},
              onSelectionChanged: (modes) => controller.setMode(modes.first),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: tokens.surfaceDecoration(withShadow: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tokens.label, style: textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(tokens.blurb, style: textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Swatch(label: 'accent', color: tokens.accent),
                      _Swatch(label: 'success', color: tokens.success),
                      _Swatch(label: 'danger', color: tokens.danger),
                      _Swatch(label: 'border', color: tokens.border),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SamplePanel(
                    label: 'Raised',
                    decoration: tokens.raisedSurfaceDecoration(
                      withShadow: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SamplePanel(
                    label: 'Glass',
                    decoration: tokens.glassSurfaceDecoration(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SamplePanel(
                    label: 'Success',
                    decoration: tokens.successSurfaceDecoration(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SamplePanel(
                    label: 'Danger',
                    decoration: tokens.dangerSurfaceDecoration(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final MaiaThemeKey theme;
  final MaiaThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.maia;
    final preview = MaiaThemeTokens.resolve(theme, mode);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: tokens
            .surfaceDecoration(withShadow: selected)
            .copyWith(
              color: selected ? tokens.accentSoft : tokens.backgroundCard,
              border: Border.all(
                color: selected ? tokens.accent : tokens.border,
                width: selected ? 1.5 : 1,
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: preview.background,
                  borderRadius: BorderRadius.circular(preview.radius),
                  border: Border.all(color: preview.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 4,
                          backgroundColor: preview.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: preview.faint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Aa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: preview.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    theme.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: tokens.accent,
                  ),
              ],
            ),
            Text(
              theme.blurb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.dim),
            ),
          ],
        ),
      ),
    );
  }
}

class _SamplePanel extends StatelessWidget {
  const _SamplePanel({required this.label, required this.decoration});

  final String label;
  final BoxDecoration decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(label),
    );
  }
}
