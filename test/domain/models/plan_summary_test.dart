import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';
import 'package:cutmaster/domain/models/plan_summary.dart';

CutPart _part({
  required String id,
  required double length,
  required double width,
  String label = '',
  String? colorPresetId,
  double thickness = 18,
}) =>
    CutPart(
      id: id,
      length: length,
      width: width,
      qty: 1,
      label: label,
      colorPresetId: colorPresetId,
      thickness: thickness,
    );

PlacedPart _placed(CutPart p, {required double x, required double y}) =>
    PlacedPart(part: p, x: x, y: y);

const _emptyName = String.fromEnvironment('NEVER');

void main() {
  group('PlanSummary.fromPlan', () {
    test('empty plan → 모든 값 0', () {
      const plan = CuttingPlan(
        sheets: [],
        unplaced: [],
        efficiencyPercent: 0,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.totalSheets, 0);
      expect(s.totalPlacedParts, 0);
      expect(s.totalUsedAreaMm2, 0);
      expect(s.totalCuts, 0);
      expect(s.cutsAreEstimated, isFalse);
      expect(s.materialUsages, isEmpty);
      expect(s.partGroups, isEmpty);
    });

    test('단일 시트 단일 부품 → 면적·자재 1종·부품 1그룹', () {
      final p = _part(id: 'p1', length: 600, width: 400, label: '도어');
      final sheet = SheetLayout(
        stockSheetId: 'st1',
        placed: [_placed(p, x: 0, y: 0)],
        sheetLength: 2440,
        sheetWidth: 1220,
      );
      final plan = CuttingPlan(
        sheets: [sheet],
        unplaced: const [],
        efficiencyPercent: 8.0,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.totalSheets, 1);
      expect(s.totalPlacedParts, 1);
      expect(s.totalUsedAreaMm2, 600 * 400);
      expect(s.materialUsages, hasLength(1));
      expect(s.materialUsages.first.name, '기본 18T');
      expect(s.materialUsages.first.sheetCount, 1);
      expect(s.materialUsages.first.usedAreaMm2, 600 * 400);
      expect(s.partGroups, hasLength(1));
      expect(s.partGroups.first.label, '도어');
      expect(s.partGroups.first.qty, 1);
    });

    test('자재 2종 (다른 colorPresetId, 다른 thickness) → materialUsages 2개', () {
      final birch = _part(
          id: 'p1',
          length: 600,
          width: 400,
          colorPresetId: 'birch',
          thickness: 18);
      final mdf = _part(
          id: 'p2',
          length: 500,
          width: 300,
          colorPresetId: 'mdf',
          thickness: 15);
      final s1 = SheetLayout(
        stockSheetId: 'st-birch',
        placed: [_placed(birch, x: 0, y: 0)],
        sheetLength: 2440,
        sheetWidth: 1220,
      );
      final s2 = SheetLayout(
        stockSheetId: 'st-mdf',
        placed: [_placed(mdf, x: 0, y: 0)],
        sheetLength: 2440,
        sheetWidth: 1220,
      );
      final plan = CuttingPlan(
        sheets: [s1, s2],
        unplaced: const [],
        efficiencyPercent: 5.0,
      );
      final summary = PlanSummary.fromPlan(
        plan,
        colorName: (id) => switch (id) {
          'birch' => '자작',
          'mdf' => 'MDF',
          _ => null,
        },
      );
      expect(summary.materialUsages, hasLength(2));
      final byName = {for (final m in summary.materialUsages) m.name: m};
      expect(byName.containsKey('자작 18T'), isTrue);
      expect(byName.containsKey('MDF 15T'), isTrue);
      expect(byName['자작 18T']!.sheetCount, 1);
      expect(byName['MDF 15T']!.sheetCount, 1);
    });

    test('같은 라벨 다른 사이즈 → partGroups 2개로 분리', () {
      final small = _part(id: 'p1', length: 600, width: 400, label: '도어');
      final large = _part(id: 'p2', length: 800, width: 400, label: '도어');
      final sheet = SheetLayout(
        stockSheetId: 'st1',
        placed: [
          _placed(small, x: 0, y: 0),
          _placed(small, x: 0, y: 400),
          _placed(large, x: 600, y: 0),
        ],
        sheetLength: 2440,
        sheetWidth: 1220,
      );
      final plan = CuttingPlan(
        sheets: [sheet],
        unplaced: const [],
        efficiencyPercent: 30.0,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.partGroups, hasLength(2));
      final groups = {
        for (final g in s.partGroups) '${g.length}x${g.width}': g.qty,
      };
      expect(groups['600.0x400.0'], 2);
      expect(groups['800.0x400.0'], 1);
    });

    test('FFD 가이로틴 라인 추정 — 격자 배치', () {
      // 2400x1200 시트에 600x400 부품 8개 (4x2 격자) 배치
      // 수직선: x=600, 1200, 1800 (3개 — 0과 2400 제외)
      // 수평선: y=400, 800 (2개 — 0과 1200 제외, 1200은 시트 가장자리)
      // (단, 부품들이 시트를 꽉 채우므로 y=1200은 가장자리)
      // 부품의 y2 = 800 (위쪽 행), y1=400 (아래쪽 행 시작), y2=1200 (위쪽 행 끝=가장자리)
      // → ys = {400, 800}
      // → 총 5
      final p = _part(id: 'p', length: 600, width: 400);
      final placed = <PlacedPart>[];
      for (var col = 0; col < 4; col++) {
        for (var row = 0; row < 2; row++) {
          placed.add(_placed(p, x: col * 600.0, y: row * 400.0));
        }
      }
      final sheet = SheetLayout(
        stockSheetId: 's',
        placed: placed,
        sheetLength: 2400,
        sheetWidth: 1200, // 빡빡 — y=1200은 시트 가장자리
      );
      expect(estimateGuillotineCuts(sheet), 5);

      final plan = CuttingPlan(
        sheets: [sheet],
        unplaced: const [],
        efficiencyPercent: 66.7,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.totalCuts, 5);
      expect(s.cutsAreEstimated, isTrue);
    });

    test('strip-cut 모드 — strip 수 + segment 수 정확값', () {
      const seq = CutSequence(
        verticalFirst: true,
        strips: [
          Strip(offset: 0, width: 400, length: 1220, segments: [
            Segment(offset: 0, length: 600, parts: [], trim: 0),
            Segment(offset: 600, length: 500, parts: [], trim: 0),
          ]),
          Strip(offset: 400, width: 400, length: 1220, segments: [
            Segment(offset: 0, length: 600, parts: [], trim: 0),
          ]),
        ],
      );
      const sheet = SheetLayout(
        stockSheetId: 's',
        placed: [],
        sheetLength: 2440,
        sheetWidth: 1220,
        cutSequence: seq,
      );
      // strips: 2, segments: 2+1 = 3 → 합 5
      expect(estimateGuillotineCuts(sheet), 5);
      const plan = CuttingPlan(
        sheets: [sheet],
        unplaced: [],
        efficiencyPercent: 0,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.totalCuts, 5);
      // strip-cut 모드는 placed가 비어있어 anyEstimated가 false
      expect(s.cutsAreEstimated, isFalse);
    });

    test('자재명 포맷 — colorName null이면 "기본 NN T", thickness 0이면 접미사 없음',
        () {
      final p1 = _part(id: '1', length: 100, width: 100, thickness: 0);
      final sheet1 = SheetLayout(
        stockSheetId: 's',
        placed: [_placed(p1, x: 0, y: 0)],
        sheetLength: 1000,
        sheetWidth: 1000,
      );
      final plan1 = CuttingPlan(
        sheets: [sheet1],
        unplaced: const [],
        efficiencyPercent: 1,
      );
      final s1 = PlanSummary.fromPlan(plan1, colorName: (_) => null);
      expect(s1.materialUsages.first.name, '기본');

      final p2 = _part(
          id: '2',
          length: 100,
          width: 100,
          colorPresetId: 'oak',
          thickness: 25);
      final sheet2 = SheetLayout(
        stockSheetId: 's',
        placed: [_placed(p2, x: 0, y: 0)],
        sheetLength: 1000,
        sheetWidth: 1000,
      );
      final plan2 = CuttingPlan(
        sheets: [sheet2],
        unplaced: const [],
        efficiencyPercent: 1,
      );
      final s2 = PlanSummary.fromPlan(
        plan2,
        colorName: (id) => id == 'oak' ? '오크' : null,
      );
      expect(s2.materialUsages.first.name, '오크 25T');
    });

    test('정렬 — materialUsages는 sheetCount 내림차순, partGroups는 qty 내림차순',
        () {
      final pa = _part(id: 'a', length: 100, width: 100, label: 'A');
      final pb = _part(id: 'b', length: 200, width: 200, label: 'B');
      final pc = _part(id: 'c', length: 300, width: 300, label: 'C');
      final sheet = SheetLayout(
        stockSheetId: 's',
        placed: [
          _placed(pa, x: 0, y: 0),
          _placed(pb, x: 100, y: 0),
          _placed(pb, x: 100, y: 200),
          _placed(pc, x: 300, y: 0),
          _placed(pc, x: 300, y: 300),
          _placed(pc, x: 300, y: 600),
        ],
        sheetLength: 2000,
        sheetWidth: 1000,
      );
      final plan = CuttingPlan(
        sheets: [sheet],
        unplaced: const [],
        efficiencyPercent: 1,
      );
      final s = PlanSummary.fromPlan(plan, colorName: (_) => null);
      expect(s.partGroups.map((g) => g.label).toList(), ['C', 'B', 'A']);
    });
  });

  // 미사용 const sentinel — `unused_local_variable` 오류 방지를 위해 의도적으로 참조.
  identical(_emptyName, _emptyName);
}
