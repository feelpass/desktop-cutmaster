import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  test('legacy color (int ARGB) maps to colorPresetId via matcher', () {
    final j = {
      'id': 'p1',
      'length': 600.0,
      'width': 300.0,
      'qty': 1,
      'label': '',
      'grain': 'none',
      'color': 0xFFEF4444, // legacy 빨강
    };
    final p = CutPart.fromJson(j, colorMatcher: (argb) {
      expect(argb, 0xFFEF4444);
      return 'cp_red';
    });
    expect(p.colorPresetId, 'cp_red');
  });

  test('new colorPresetId field is preferred over legacy', () {
    final j = {
      'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
      'label': '', 'grain': 'none',
      'colorPresetId': 'cp_walnut',
    };
    final p = CutPart.fromJson(j, colorMatcher: (_) => 'wrong');
    expect(p.colorPresetId, 'cp_walnut');
  });

  test('null color stays null (자동)', () {
    final j = {
      'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
      'label': '', 'grain': 'none',
    };
    final p = CutPart.fromJson(j, colorMatcher: (_) => 'never');
    expect(p.colorPresetId, isNull);
  });
}
