import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/maia_theme_tokens.dart';
import 'core/theme/theme_controller.dart';

class MaiaApp extends ConsumerWidget {
  const MaiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSelection = ref.watch(themeControllerProvider).maybeWhen(
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
    );
  }
}
