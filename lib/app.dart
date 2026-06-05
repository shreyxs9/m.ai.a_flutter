import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/maia_theme_tokens.dart';
import 'core/theme/theme_controller.dart';
import 'features/push/push_prompt_banner.dart';

class MaiaApp extends ConsumerWidget {
  const MaiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSelection = ref
        .watch(themeControllerProvider)
        .maybeWhen(
          data: (selection) => selection,
          orElse: () => const MaiaThemeSelection(),
        );
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: themeSelection.themeData,
      darkTheme: AppTheme.build(
        theme: themeSelection.theme,
        mode: MaiaThemeMode.dark,
      ),
      themeMode: themeSelection.mode.materialThemeMode,
      routerConfig: router,
      builder: (context, child) {
        return _AppShellOverlay(
          router: router,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _AppShellOverlay extends StatelessWidget {
  const _AppShellOverlay({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final location = router.routeInformationProvider.value.uri.path;
        final suppressPrompt = location.startsWith('/project/');
        return Stack(
          children: [
            child,
            PushPromptBanner(suppressed: suppressPrompt),
          ],
        );
      },
    );
  }
}
