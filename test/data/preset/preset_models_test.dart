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

    test('hashCode consistent with equality', () {
      const a = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      const b = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
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
        grainDirection: GrainDirection.lengthwise,
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
        grainDirection: GrainDirection.none,
      );
      expect(DimensionPreset.fromJson(d.toJson()), d);
    });

    test('fromJson with missing grain key defaults to none', () {
      final j = {
        'id': 'dp_x',
        'length': 100.0,
        'width': 50.0,
        'label': '',
      };
      final d = DimensionPreset.fromJson(j);
      expect(d.grainDirection, GrainDirection.none);
    });

    test('equality + hashCode consistency', () {
      const a = DimensionPreset(
        id: 'dp_x',
        length: 600,
        width: 300,
        label: '',
        colorPresetId: null,
        grainDirection: GrainDirection.none,
      );
      const b = DimensionPreset(
        id: 'dp_x',
        length: 600,
        width: 300,
        label: '',
        colorPresetId: null,
        grainDirection: GrainDirection.none,
      );
      const c = DimensionPreset(
        id: 'dp_y',
        length: 600,
        width: 300,
        label: '',
        colorPresetId: null,
        grainDirection: GrainDirection.none,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, false);
    });

    test('copyWith with clearColor=true sets colorPresetId null', () {
      const d = DimensionPreset(
        id: 'dp_x',
        length: 600,
        width: 300,
        label: 'A',
        colorPresetId: 'cp_red',
        grainDirection: GrainDirection.none,
      );
      final cleared = d.copyWith(clearColor: true);
      expect(cleared.colorPresetId, isNull);
    });
  });
}
