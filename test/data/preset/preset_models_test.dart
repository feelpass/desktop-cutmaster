import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  group('ColorPreset', () {
    test('toJson / fromJson round-trip', () {
      const p = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      final j = p.toJson();
      final back = ColorPreset.fromJson(j);
      expect(back, p);
    });

    test('equality based on id+name+argb', () {
      const a = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      const b = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      const c = ColorPreset(id: 'cp_x', name: '자작', argb: 0xFF8B6240);
      expect(a, b);
      expect(a == c, false);
    });
  });

  group('DimensionPreset', () {
    test('toJson / fromJson round-trip with all fields', () {
      const d = DimensionPreset(
        id: 'dp_walnut18',
        length: 2440,
        width: 1220,
        label: '호두 18T',
        colorPresetId: 'cp_walnut',
        grain: GrainDirection.lengthwise,
      );
      expect(DimensionPreset.fromJson(d.toJson()), d);
    });

    test('toJson / fromJson with null colorPresetId (자동)', () {
      const d = DimensionPreset(
        id: 'dp_x',
        length: 600,
        width: 300,
        label: '',
        colorPresetId: null,
        grain: GrainDirection.none,
      );
      expect(DimensionPreset.fromJson(d.toJson()), d);
    });
  });
}
