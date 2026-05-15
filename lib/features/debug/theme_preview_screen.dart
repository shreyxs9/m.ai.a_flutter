import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/maia_theme_helpers.dart';
import '../../core/theme/maia_theme_tokens.dart';
import '../../core/theme/theme_controller.dart';

class ThemePreviewScreen extends ConsumerWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(themeControllerProvider).maybeWhen(
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final theme in MaiaThemeKey.values)
                  ChoiceChip(
                    label: Text(theme.label),
                    selected: selection.theme == theme,
                    onSelected: (_) => controller.setTheme(theme),
                  ),
              ],
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

class _SamplePanel extends StatelessWidget {
  const _SamplePanel({
    required this.label,
    required this.decoration,
  });

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
  const _Swatch({
    required this.label,
    required this.color,
  });

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
