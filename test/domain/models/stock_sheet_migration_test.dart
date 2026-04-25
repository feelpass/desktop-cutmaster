import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';

void main() {
  test('legacy color (int ARGB) maps to colorPresetId via matcher', () {
    final j = {
      'id': 's1',
      'length': 2440.0,
      'width': 1220.0,
      'qty': 1,
      'label': '',
      'grain': 'none',
      'color': 0xFF8B6240, // legacy 호두
    };
    final s = StockSheet.fromJson(j, colorMatcher: (argb) {
      expect(argb, 0xFF8B6240);
      return 'cp_walnut';
    });
    expect(s.colorPresetId, 'cp_walnut');
  });

  test('new colorPresetId field is preferred over legacy', () {
    final j = {
      'id': 's1', 'length': 2440.0, 'width': 1220.0, 'qty': 1,
      'label': '', 'grain': 'none',
      'colorPresetId': 'cp_walnut',
    };
    final s = StockSheet.fromJson(j, colorMatcher: (_) => 'wrong');
    expect(s.colorPresetId, 'cp_walnut');
  });

  test('null color stays null (자동)', () {
    final j = {
      'id': 's1', 'length': 2440.0, 'width': 1220.0, 'qty': 1,
      'label': '', 'grain': 'none',
    };
    final s = StockSheet.fromJson(j, colorMatcher: (_) => 'never');
    expect(s.colorPresetId, isNull);
  });
}
