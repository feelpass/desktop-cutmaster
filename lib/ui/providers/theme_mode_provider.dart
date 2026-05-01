import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/workspace_db.dart';

const _kThemeModeKey = 'theme_mode';

/// 테마 모드를 WorkspaceDb의 setting 테이블에 영속화한다.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._workspace, ThemeMode initial) : super(initial);

  final WorkspaceDb _workspace;

  static Future<ThemeMode> loadInitial(WorkspaceDb workspace) async {
    final value = await workspace.getSetting(_kThemeModeKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _workspace.setSetting(_kThemeModeKey, mode.name);
  }

  /// 현재 모드의 light/dark 사이클. system이면 light로 시작.
  Future<void> toggle(Brightness platformBrightness) async {
    final ThemeMode next;
    switch (state) {
      case ThemeMode.system:
        next = platformBrightness == Brightness.dark
            ? ThemeMode.light
            : ThemeMode.dark;
      case ThemeMode.light:
        next = ThemeMode.dark;
      case ThemeMode.dark:
        next = ThemeMode.light;
    }
    await setMode(next);
  }
}

/// `main.dart`에서 초기값을 로드해 override로 주입한다.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  throw UnimplementedError(
      'themeModeProvider must be overridden with a ThemeModeNotifier');
});
