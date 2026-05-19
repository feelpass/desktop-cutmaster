import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/workspace_db.dart';

const _kLeftPaneTopHeightKey = 'left_pane_top_height';
const double kLeftPaneTopHeightDefault = 540;
const double kLeftPaneTopHeightMin = 160;
const double kLeftPaneTopHeightMax = 1200;

/// 좌측 패널 상단(주문/재단조건) 높이를 WorkspaceDb setting 테이블에 영속화.
class LeftPaneSplitNotifier extends StateNotifier<double> {
  LeftPaneSplitNotifier(this._workspace, double initial) : super(initial);

  final WorkspaceDb _workspace;

  static Future<double> loadInitial(WorkspaceDb workspace) async {
    final value = await workspace.getSetting(_kLeftPaneTopHeightKey);
    if (value == null) return kLeftPaneTopHeightDefault;
    final parsed = double.tryParse(value);
    if (parsed == null) return kLeftPaneTopHeightDefault;
    return parsed.clamp(kLeftPaneTopHeightMin, kLeftPaneTopHeightMax);
  }

  Future<void> setHeight(double h) async {
    final clamped = h.clamp(kLeftPaneTopHeightMin, kLeftPaneTopHeightMax);
    state = clamped;
    await _workspace.setSetting(
        _kLeftPaneTopHeightKey, clamped.toStringAsFixed(1));
  }
}

/// `main.dart`에서 초기값을 로드해 override로 주입한다.
final leftPaneSplitProvider =
    StateNotifierProvider<LeftPaneSplitNotifier, double>((ref) {
  throw UnimplementedError(
      'leftPaneSplitProvider must be overridden with a LeftPaneSplitNotifier');
});
