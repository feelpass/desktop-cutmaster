import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../../data/preset/preset_repository.dart';

extension ColorPresetCopyWith on ColorPreset {
  ColorPreset copyWith({String? name, int? argb}) =>
      ColorPreset(id: id, name: name ?? this.name, argb: argb ?? this.argb);
}

class PresetsNotifier extends ChangeNotifier {
  PresetsNotifier(this._repo);
  final PresetRepository _repo;
  PresetState _state = PresetState.seeded;
  PresetState get state => _state;

  Future<void> load() async {
    _state = await _repo.load();
    notifyListeners();
  }

  Future<void> _persist() => _repo.save(_state);

  // ===== ColorPreset =====
  Future<void> addColor(ColorPreset c) async {
    _state = PresetState(
      colors: [..._state.colors, c],
      parts: _state.parts,
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updateColor(ColorPreset c) async {
    _state = PresetState(
      colors: _state.colors.map((e) => e.id == c.id ? c : e).toList(),
      parts: _state.parts,
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removeColor(String id) async {
    DimensionPreset clearIfMatch(DimensionPreset d) =>
        d.colorPresetId == id
            ? DimensionPreset(
                id: d.id, length: d.length, width: d.width,
                label: d.label, colorPresetId: null,
                grainDirection: d.grainDirection)
            : d;
    _state = PresetState(
      colors: _state.colors.where((e) => e.id != id).toList(),
      parts: _state.parts.map(clearIfMatch).toList(),
      stocks: _state.stocks.map(clearIfMatch).toList(),
    );
    notifyListeners();
    await _persist();
  }

  // ===== Part / Stock DimensionPreset =====
  Future<void> addPartPreset(DimensionPreset d) async {
    _state = PresetState(
      colors: _state.colors,
      parts: [..._state.parts, d],
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updatePartPreset(DimensionPreset d) async {
    _state = PresetState(
      colors: _state.colors,
      parts: _state.parts.map((e) => e.id == d.id ? d : e).toList(),
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removePartPreset(String id) async {
    _state = PresetState(
      colors: _state.colors,
      parts: _state.parts.where((e) => e.id != id).toList(),
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> addStockPreset(DimensionPreset d) async {
    _state = PresetState(
      colors: _state.colors,
      parts: _state.parts,
      stocks: [..._state.stocks, d],
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updateStockPreset(DimensionPreset d) async {
    _state = PresetState(
      colors: _state.colors,
      parts: _state.parts,
      stocks: _state.stocks.map((e) => e.id == d.id ? d : e).toList(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removeStockPreset(String id) async {
    _state = PresetState(
      colors: _state.colors,
      parts: _state.parts,
      stocks: _state.stocks.where((e) => e.id != id).toList(),
    );
    notifyListeners();
    await _persist();
  }

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
