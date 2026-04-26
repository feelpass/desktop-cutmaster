import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/solver/auto_recommend.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';
import 'package:cutmaster/domain/solver/strip_cut_solver.dart';

void main() {
  group('Strip-cut integration smoke (standard plywood)', () {
    final stocks = [
      const StockSheet(id: 's', length: 2440, width: 1220, qty: 2, label: '12T'),
    ];
    final parts = [
      const CutPart(id: 'a', length: 600, width: 400, qty: 4, label: '문짝'),
      const CutPart(id: 'b', length: 800, width: 300, qty: 2, label: '측판'),
      const CutPart(id: 'c', length: 400, width: 400, qty: 6, label: '선반'),
    ];

    test('FFDSolver produces valid plan', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, greaterThan(0));
      // FFD: cutSequence is null.
      for (final s in plan.sheets) {
        expect(s.cutSequence, isNull);
      }
    });

    test('StripCutSolver verticalFirst 3-stage all toggles ON', () {
      final plan = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(plan.efficiencyPercent, greaterThan(0));
      for (final s in plan.sheets) {
        expect(s.cutSequence, isNotNull);
        expect(s.cutSequence!.verticalFirst, true);
      }
    });

    test('StripCutSolver horizontalFirst 3-stage all toggles ON', () {
      final plan = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(plan.efficiencyPercent, greaterThan(0));
      for (final s in plan.sheets) {
        expect(s.cutSequence, isNotNull);
        expect(s.cutSequence!.verticalFirst, false);
      }
    });

    test('AutoRecommend produces winner + runner-up', () {
      final result = AutoRecommend().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(result.plan.efficiencyPercent, greaterThan(0));
      expect(result.runnerUp.efficiencyPercent, greaterThan(0));
      expect(result.winner, isNot(result.runnerUpDirection));
    });

    test('Project v3 roundtrip with strip-cut mode', () {
      final p = Project.create(id: 'p1', name: 'integration').copyWith(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
        solverMode: SolverMode.stripCut,
        stripDirection: StripDirection.auto,
        maxStages: 4,
        preferSameWidth: false,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      final json = p.toJson();
      final restored = Project.fromJson(json);
      expect(restored.solverMode, SolverMode.stripCut);
      expect(restored.stripDirection, StripDirection.auto);
      expect(restored.maxStages, 4);
      expect(restored.preferSameWidth, false);
      expect(restored.minimizeCuts, true);
      expect(restored.minimizeWaste, true);
    });

    test('All toggle combinations + maxStages 2/3/4 do not crash', () {
      final solver = StripCutSolver();
      for (final maxStages in [2, 3, 4]) {
        for (final dir in [StripDirection.verticalFirst, StripDirection.horizontalFirst]) {
          for (final psw in [true, false]) {
            for (final mc in [true, false]) {
              for (final mw in [true, false]) {
                final plan = solver.solve(
                  stocks: stocks,
                  parts: parts,
                  kerf: 3,
                  grainLocked: true,
                  direction: dir,
                  maxStages: maxStages,
                  preferSameWidth: psw,
                  minimizeCuts: mc,
                  minimizeWaste: mw,
                );
                expect(plan, isNotNull);
                expect(plan.efficiencyPercent, greaterThanOrEqualTo(0));
              }
            }
          }
        }
      }
    });
  });
}
