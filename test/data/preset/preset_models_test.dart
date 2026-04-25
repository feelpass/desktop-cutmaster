import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/preset_models.dart';

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
}
