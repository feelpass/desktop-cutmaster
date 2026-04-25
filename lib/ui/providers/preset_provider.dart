import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../../data/preset/preset_repository.dart';

extension ColorPresetCopyWith on ColorPreset {
  ColorPreset copyWith({String? name, int? argb}) =>
      ColorPreset(id: id, name: name ?? this.name, argb: argb ?? this.argb);
}

/// 글로벌 프리셋(색상/부품/자재)의 in-memory 상태를 보유하며 디스크와 동기화한다.
/// 모든 mutator는 메모리 → notifyListeners → 비동기 persist 순서로 동작.
class PresetsNotifier extends ChangeNotifier {
  PresetsNotifier(this._repo);
  final PresetRepository _repo;
  PresetState _state = PresetState.seeded;
  PresetState get state => _state;

  Object? _lastSaveError;

  /// 가장 최근 [_apply]에서 발생한 persist 실패. 성공 시 null로 리셋.
  /// UI는 이를 구독해 사용자에게 surface 할 수 있다.
  Object? get lastSaveError => _lastSaveError;

  Future<void> load() async {
    _state = await _repo.load();
    notifyListeners();
  }

  Future<void> _apply(PresetState next) async {
    _state = next;
    notifyListeners();
    try {
      await _repo.save(_state);
      _lastSaveError = null;
    } catch (e, st) {
      _lastSaveError = e;
      debugPrint('PresetsNotifier persist failed: $e\n$st');
      notifyListeners(); // surface error state
    }
  }

  // ===== ColorPreset =====
  Future<void> addColor(ColorPreset c) =>
      _apply(_state.copyWith(colors: [..._state.colors, c]));

  Future<void> updateColor(ColorPreset c) => _apply(_state.copyWith(
      colors: _state.colors.map((e) => e.id == c.id ? c : e).toList()));

  /// 색상 프리셋을 풀에서 제거하고, 그 색을 참조하던 모든 부품/자재
  /// 프리셋의 [DimensionPreset.colorPresetId]를 null로 cascade 처리한다.
  /// (즉 "삭제"가 아니라 "자동 색상으로 강등".) 다른 필드(length/width/
  /// label/grainDirection)는 유지된다.
  Future<void> removeColor(String id) {
    DimensionPreset clearIfMatch(DimensionPreset d) =>
        d.colorPresetId == id ? d.copyWith(clearColor: true) : d;
    return _apply(_state.copyWith(
      colors: _state.colors.where((e) => e.id != id).toList(),
      parts: _state.parts.map(clearIfMatch).toList(),
      stocks: _state.stocks.map(clearIfMatch).toList(),
    ));
  }

  // ===== Part / Stock DimensionPreset =====
  Future<void> addPartPreset(DimensionPreset d) =>
      _apply(_state.copyWith(parts: [..._state.parts, d]));

  Future<void> updatePartPreset(DimensionPreset d) => _apply(_state.copyWith(
      parts: _state.parts.map((e) => e.id == d.id ? d : e).toList()));

  Future<void> removePartPreset(String id) => _apply(_state.copyWith(
      parts: _state.parts.where((e) => e.id != id).toList()));

  Future<void> addStockPreset(DimensionPreset d) =>
      _apply(_state.copyWith(stocks: [..._state.stocks, d]));

  Future<void> updateStockPreset(DimensionPreset d) => _apply(_state.copyWith(
      stocks: _state.stocks.map((e) => e.id == d.id ? d : e).toList()));

  Future<void> removeStockPreset(String id) => _apply(_state.copyWith(
      stocks: _state.stocks.where((e) => e.id != id).toList()));

  // Lookup helper
  ColorPreset? colorById(String? id) {
    if (id == null) return null;
    for (final c in _state.colors) {
      if (c.id == id) return c;
    }
    return null;
  }
}

final presetsProvider =
    ChangeNotifierProvider<PresetsNotifier>((ref) {
  throw UnimplementedError('main()에서 override 됨');
});
