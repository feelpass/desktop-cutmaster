import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/solver/auto_recommend.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  group('AutoRecommend', () {
    test('returns plan, winner, runnerUp for both directions', () {
      final result = AutoRecommend().solve(
        stocks: const [
          StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: const [
          CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(result.plan, isNotNull);
      expect(result.runnerUp, isNotNull);
      expect(
        result.winner,
        isIn([StripDirection.verticalFirst, StripDirection.horizontalFirst]),
      );
      expect(result.runnerUpDirection, isNot(result.winner));
    });

    test('picks lower-waste direction when minimizeWaste=true', () {
      // 시트 1000x500. 부품 1000x500 qty 1 (perfect fit).
      // vertical: strip 폭 1000, segment 500. 100% efficiency.
      // horizontal: strip 폭 500, segment 1000. 100% efficiency.
      // Both placed 100%. Tie-break → vertical 선택.
      final result = AutoRecommend().solve(
        stocks: const [
          StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: const [
          CutPart(id: 'a', length: 1000, width: 500, qty: 1, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(result.winner, StripDirection.verticalFirst);
      expect(result.plan.unplaced, isEmpty);
      expect(result.runnerUp.unplaced, isEmpty);
    });

    test('picks higher-efficiency direction when toggles all OFF', () {
      // 비대칭 시트 + 부품 → 효율 명백히 다른 fixture.
      // 시트 2440x1220 (표준 합판), 부품 600x400 qty 4.
      // 둘 중 효율 높은 쪽 선택 — 정확한 winner는 알고리즘 동작이 결정.
      final result = AutoRecommend().solve(
        stocks: const [
          StockSheet(id: 's', length: 2440, width: 1220, qty: 1, label: ''),
        ],
        parts: const [
          CutPart(id: 'a', length: 600, width: 400, qty: 4, label: 'A'),
        ],
        kerf: 3,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(
        result.plan.efficiencyPercent,
        greaterThanOrEqualTo(result.runnerUp.efficiencyPercent),
      );
      // 4 parts in standard plywood, should fit.
      expect(result.plan.unplaced, isEmpty);
    });

    test('short-circuits when parts is empty (does not invoke solver)', () {
      // We can't easily mock the solver, so we test indirect proof:
      // empty input must not crash and must return an empty result with both directions noted.
      final result = AutoRecommend().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: const [],
        kerf: 0,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(result.plan.sheets, isEmpty);
      expect(result.plan.unplaced, isEmpty);
      expect(result.runnerUp.sheets, isEmpty);
      // winner is deterministic — vertical (default tie-break).
      expect(result.winner, StripDirection.verticalFirst);
    });

    test('short-circuits when stocks is empty', () {
      final result = AutoRecommend().solve(
        stocks: const [],
        parts: [
          const CutPart(id: 'a', length: 100, width: 100, qty: 1, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(result.plan.sheets, isEmpty);
      expect(result.plan.unplaced, isEmpty);
    });
  });
}
