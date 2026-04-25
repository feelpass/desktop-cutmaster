import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';

void main() {
  group('FFDSolver — 정상 입력', () {
    test('자재 1개 + 부품 4개(2x2 정확히 들어감) → 효율 95% 이상', () {
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      const parts = [
        CutPart(id: 'p1', length: 1200, width: 600, qty: 4, label: 'A'),
      ];
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty,
          reason: '4 panels of 1200x600 should fit in 2440x1220');
      expect(plan.efficiencyPercent, greaterThanOrEqualTo(95));
      expect(plan.sheets.length, 1);
      expect(plan.sheets.first.placed.length, 4);
    });
  });
}
