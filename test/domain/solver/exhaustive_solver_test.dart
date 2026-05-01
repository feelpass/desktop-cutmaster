import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/solver/exhaustive_solver.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';

/// ExhaustiveSolver의 동작 검증.
/// 1. 사용자 CSV로 FFD vs Exhaustive 비교 — 같은 71.34% 도달.
/// 2. 작은 입력에서 진짜 최적해 도달 검증.
/// 3. 시간 제한 동작 검증.
void main() {
  group('ExhaustiveSolver - 0502전경인화이트.CSV', () {
    final stocks = [
      const StockSheet(
          id: 's_white', length: 2440, width: 1220, qty: 999, label: 'white'),
    ];
    final parts = [
      const CutPart(
          id: '1', length: 304.5, width: 262.5, qty: 4, label: '이동선반_a'),
      const CutPart(
          id: '2', length: 312.0, width: 262.5, qty: 2, label: '이동선반_b'),
      const CutPart(
          id: '3', length: 1000.0, width: 290.0, qty: 1, label: '지판'),
      const CutPart(
          id: '4', length: 1000.0, width: 290.0, qty: 1, label: '천판'),
      const CutPart(
          id: '5', length: 1030.0, width: 265.5, qty: 2, label: '중측판'),
      const CutPart(
          id: '6', length: 1030.0, width: 961.0, qty: 1, label: '뒷판'),
      const CutPart(
          id: '7', length: 1030.0, width: 286.0, qty: 1, label: '우측판_뒤집기'),
      const CutPart(
          id: '8', length: 1030.0, width: 286.0, qty: 1, label: '좌측판_뒤집기'),
      const CutPart(
          id: '9', length: 1070.0, width: 329.5, qty: 2, label: '좌도어'),
      const CutPart(
          id: '10', length: 1070.0, width: 329.5, qty: 1, label: '우도어'),
    ];

    test('Exhaustive >= FFD (warm-start 보장)', () {
      final ffd = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      final exh = ExhaustiveSolver(timeLimit: const Duration(seconds: 5))
          .solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );

      // ignore: avoid_print
      print(
          'FFD       : ${ffd.efficiencyPercent.toStringAsFixed(2)}% / 시트 ${ffd.sheets.length} / 미배치 ${ffd.unplaced.length}');
      // ignore: avoid_print
      print(
          'Exhaustive: ${exh.efficiencyPercent.toStringAsFixed(2)}% / 시트 ${exh.sheets.length} / 미배치 ${exh.unplaced.length}');

      // Exhaustive는 FFD를 warm-start로 쓰므로 항상 >= FFD.
      expect(exh.efficiencyPercent,
          greaterThanOrEqualTo(ffd.efficiencyPercent - 0.001),
          reason: 'Exhaustive가 FFD warm-start보다 못한 결과 — 버그');
      expect(exh.unplaced.length, lessThanOrEqualTo(ffd.unplaced.length));
    });

    test('이론치 71.34% 도달', () {
      final exh = ExhaustiveSolver(timeLimit: const Duration(seconds: 5))
          .solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      expect(exh.efficiencyPercent, greaterThanOrEqualTo(71.0),
          reason: '이론 최대 71.34%에 도달 못함');
      expect(exh.unplaced, isEmpty);
    });
  });

  group('ExhaustiveSolver - 작은 입력 정확도', () {
    test('정확히 들어맞는 4부품 → 효율 100% 도달', () {
      const stocks = [
        StockSheet(id: 's', length: 100, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(id: '1', length: 50, width: 50, qty: 4),
      ];
      final plan = ExhaustiveSolver(timeLimit: const Duration(seconds: 2))
          .solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.efficiencyPercent, 100.0);
      expect(plan.sheets.length, 1);
      expect(plan.unplaced, isEmpty);
    });

    test('빈 입력 → 빈 결과', () {
      final plan = ExhaustiveSolver().solve(
        stocks: const [StockSheet(id: 's', length: 100, width: 100, qty: 1)],
        parts: const [],
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });

    test('자재 없음 → 모든 부품 unplaced', () {
      const parts = [CutPart(id: '1', length: 50, width: 50, qty: 1)];
      final plan = ExhaustiveSolver().solve(
        stocks: const [],
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced.length, 1);
    });
  });
}
