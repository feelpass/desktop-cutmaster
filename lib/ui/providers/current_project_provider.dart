import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cut_part.dart';
import '../../domain/models/project.dart';
import '../../domain/models/stock_sheet.dart';
import 'db_provider.dart';

/// 현재 편집 중인 프로젝트의 상태. 변경 시 debounce 후 자동 저장.
class CurrentProjectNotifier extends StateNotifier<Project> {
  CurrentProjectNotifier(this._ref)
      : super(Project.create(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '새 프로젝트',
        ));

  final Ref _ref;
  Timer? _saveDebounce;

  void setProject(Project p) {
    state = p;
    _scheduleSave();
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
    _scheduleSave();
  }

  void updateStocks(List<StockSheet> stocks) {
    state = state.copyWith(stocks: stocks);
    _scheduleSave();
  }

  void updateParts(List<CutPart> parts) {
    state = state.copyWith(parts: parts);
    _scheduleSave();
  }

  void updateKerf(double kerf) {
    state = state.copyWith(kerf: kerf);
    _scheduleSave();
  }

  void updateGrainLocked(bool v) {
    state = state.copyWith(grainLocked: v);
    _scheduleSave();
  }

  void updateShowPartLabels(bool v) {
    state = state.copyWith(showPartLabels: v);
    _scheduleSave();
  }

  void updateUseSingleSheet(bool v) {
    state = state.copyWith(useSingleSheet: v);
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistNow);
  }

  Future<void> _persistNow() async {
    final db = await _ref.read(dbProvider.future);
    await db.upsertProject(state);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }
}

final currentProjectProvider =
    StateNotifierProvider<CurrentProjectNotifier, Project>(
  (ref) => CurrentProjectNotifier(ref),
);
