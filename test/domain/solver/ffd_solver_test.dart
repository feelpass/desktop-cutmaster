import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';

void main() {
  final solver = FFDSolver();

  group('FFDSolver — 정상 입력', () {
    test('자재 1개 + 부품 4개(2x2 정확히 들어감) → 효율 95% 이상', () {
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 1200, width: 600, qty: 4, label: 'A'),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, greaterThanOrEqualTo(95));
      expect(plan.sheets.length, 1);
      expect(plan.sheets.first.placed.length, 4);
    });
  });

  group('FFDSolver — edge cases', () {
    test('빈 자재: stocks=[] → unplaced=parts 전체', () {
      const parts = [
        CutPart(id: 'p1', length: 100, width: 100, qty: 3),
      ];
      final plan = solver.solve(
        stocks: const [],
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced.length, 3);
      expect(plan.sheets, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });

    test('빈 부품: parts=[] → 빈 결과', () {
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: const [],
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });

    test('오버사이즈: 부품이 시트보다 큼 → 그 부품만 unplaced 분리', () {
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 500, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 500, width: 400, qty: 1, label: 'fits'),
        CutPart(id: 'p2', length: 2000, width: 1000, qty: 1, label: 'too big'),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced.length, 1);
      expect(plan.unplaced.first.id, 'p2');
      expect(plan.sheets.length, 1);
      expect(plan.sheets.first.placed.length, 1);
      expect(plan.sheets.first.placed.first.part.id, 'p1');
    });

    test('결방향 ON: 회전해야만 들어가는 부품 → unplaced', () {
      // 시트 1000x100. 부품 50x200 — 정방향(50w, 200h) 안 들어감 (200>100).
      // 회전(200w, 50h) 가능하지만 grainLocked로 금지.
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 50, width: 200, qty: 1),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: true,
      );
      expect(plan.unplaced.length, 1);
      expect(plan.sheets, isEmpty);
    });

    test('결방향 OFF: 회전으로 더 많이 배치 가능', () {
      // 같은 부품 (50x200), grainLocked=false면 회전(200x50)으로 들어감.
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 50, width: 200, qty: 5),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.placed.length, 5);
      // 모두 회전된 상태로 배치
      expect(plan.sheets.first.placed.every((p) => p.rotated), true);
    });

    test('kerf 반영: kerf=0 vs kerf=10 결과 다름 (kerf=10이 더 미배치)', () {
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 200, width: 100, qty: 5),
      ];
      final p0 = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      final p10 = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 10,
        grainLocked: false,
      );
      // kerf=0: 5장 정확히 들어감 (5*200=1000)
      // kerf=10: 4장 + kerf 3개 = 4*200+3*10=830 ≤ 1000, 5번째 시도 = 5*200+4*10=1040 > 1000 → 1개 미배치
      expect(p0.unplaced.length, 0);
      expect(p10.unplaced.length, greaterThan(0));
    });

    test('결정성: 같은 입력 5회 → 동일 효율과 미배치 수', () {
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 600, width: 400, qty: 4),
        CutPart(id: 'p2', length: 300, width: 200, qty: 2),
      ];
      final results = List.generate(
        5,
        (_) => solver.solve(
          stocks: stocks,
          parts: parts,
          kerf: 0,
          grainLocked: false,
        ),
      );
      for (int i = 1; i < 5; i++) {
        expect(results[i].efficiencyPercent, results[0].efficiencyPercent);
        expect(results[i].unplaced.length, results[0].unplaced.length);
        expect(results[i].sheets.length, results[0].sheets.length);
      }
    });
  });
}
