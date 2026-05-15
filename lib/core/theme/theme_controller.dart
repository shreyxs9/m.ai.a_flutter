import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'maia_theme_tokens.dart';

const maiaThemeStorageKey = 'maia_theme';
const maiaModeStorageKey = 'maia_mode';

@immutable
class MaiaThemeSelection {
  const MaiaThemeSelection({
    this.theme = MaiaThemeKey.warm,
    this.mode = MaiaThemeMode.light,
  });

  final MaiaThemeKey theme;
  final MaiaThemeMode mode;

  MaiaThemeTokens get tokens => MaiaThemeTokens.resolve(theme, mode);

  ThemeData get themeData => AppTheme.build(theme: theme, mode: mode);

  MaiaThemeSelection copyWith({
    MaiaThemeKey? theme,
    MaiaThemeMode? mode,
  }) {
    return MaiaThemeSelection(
      theme: theme ?? this.theme,
      mode: mode ?? this.mode,
    );
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, MaiaThemeSelection>(
  ThemeController.new,
);

class ThemeController extends AsyncNotifier<MaiaThemeSelection> {
  late final SharedPreferencesAsync _preferences;

  @override
  Future<MaiaThemeSelection> build() async {
    _preferences = SharedPreferencesAsync();

    final storedTheme = await _preferences.getString(maiaThemeStorageKey);
    final storedMode = await _preferences.getString(maiaModeStorageKey);

    return MaiaThemeSelection(
      theme: MaiaThemeKey.fromStorage(storedTheme),
      mode: MaiaThemeMode.fromStorage(storedMode),
    );
  }

  Future<void> setTheme(MaiaThemeKey theme) async {
    final previous = _currentSelection;
    final next = previous.copyWith(theme: theme);
    state = AsyncData(next);
    await _preferences.setString(maiaThemeStorageKey, theme.storageValue);
  }

  Future<void> setMode(MaiaThemeMode mode) async {
    final previous = _currentSelection;
    final next = previous.copyWith(mode: mode);
    state = AsyncData(next);
    await _preferences.setString(maiaModeStorageKey, mode.storageValue);
  }

  Future<void> toggleMode() async {
    final current = _currentSelection;
    final nextMode = current.mode == MaiaThemeMode.light
        ? MaiaThemeMode.dark
        : MaiaThemeMode.light;
    await setMode(nextMode);
  }

  MaiaThemeSelection get _currentSelection {
    return state.maybeWhen(
      data: (selection) => selection,
      orElse: () => const MaiaThemeSelection(),
    );
  }
}
