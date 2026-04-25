import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/project.dart';

void main() {
  group('StockSheet', () {
    test('equality and copyWith', () {
      const a = StockSheet(
        id: '1',
        length: 2440,
        width: 1220,
        qty: 5,
        label: '12T',
      );
      final b = a.copyWith(qty: 3);
      expect(b.qty, 3);
      expect(b.length, 2440);
      expect(a == b, false);
    });

    test('toJson/fromJson roundtrip', () {
      const a = StockSheet(
        id: 's1',
        length: 2440,
        width: 1220,
        qty: 2,
        label: '12T 자작',
        grainDirection: GrainDirection.lengthwise,
      );
      final b = StockSheet.fromJson(a.toJson());
      expect(b, a);
    });
  });

  group('CutPart', () {
    test('toJson roundtrip', () {
      const p = CutPart(
        id: 'p1',
        length: 600,
        width: 400,
        qty: 4,
        label: '문짝',
        grainDirection: GrainDirection.lengthwise,
      );
      final p2 = CutPart.fromJson(p.toJson());
      expect(p2, p);
    });
  });

  group('Project', () {
    test('default options', () {
      final proj = Project.create(id: 'proj1', name: '테스트');
      expect(proj.kerf, 3);
      expect(proj.grainLocked, false);
      expect(proj.parts, isEmpty);
      expect(proj.stocks, isEmpty);
      expect(proj.showPartLabels, true);
      expect(proj.useSingleSheet, false);
    });

    test('copyWith updates fields and updatedAt', () async {
      final p = Project.create(id: 'p1', name: 'A');
      await Future.delayed(const Duration(milliseconds: 2));
      final p2 = p.copyWith(name: 'B', kerf: 5);
      expect(p2.name, 'B');
      expect(p2.kerf, 5);
      expect(p2.id, 'p1');
      expect(p2.updatedAt.isAfter(p.updatedAt), true);
    });
  });
}
