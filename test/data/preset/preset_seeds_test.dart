import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';

void main() {
  test('seed has 24 color presets with unique ids', () {
    final ids = seedColorPresets.map((c) => c.id).toSet();
    expect(seedColorPresets.length, 24);
    expect(ids.length, 24);
  });

  test('seed has 6 stock presets', () {
    expect(seedStockPresets.length, 6);
  });

  test('seed part presets is empty', () {
    expect(seedPartPresets, isEmpty);
  });

  test('all stock seeds reference null colorPresetId (자동)', () {
    for (final s in seedStockPresets) {
      expect(s.colorPresetId, isNull, reason: '시드 자재는 색 자동');
    }
  });

  test('color seeds include both vivid (빨강) and wood-tone (호두)', () {
    final names = seedColorPresets.map((c) => c.name).toList();
    expect(names, contains('빨강'));
    expect(names, contains('호두'));
  });
}
