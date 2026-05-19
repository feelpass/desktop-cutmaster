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

    test('부품별 grainDirection.lengthwise: 프로젝트 grainLocked=false여도 회전 금지', () {
      // 시트 1000x100. 부품 50x200 — 정방향(50w, 200h) 안 들어감 (200>100).
      // 회전(200w, 50h)이면 들어가지만 부품의 결방향이 lengthwise이므로 회전 금지여야 함.
      // → 미배치되어야 함 (grainLocked=false임에도).
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(
          id: 'p1',
          length: 50,
          width: 200,
          qty: 1,
          grainDirection: GrainDirection.lengthwise,
        ),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced.length, 1, reason: 'lengthwise 부품은 회전 금지');
      expect(plan.sheets, isEmpty);
    });

    test('부품별 grainDirection.lengthwise: 모든 부품이 rotated=false로 배치', () {
      // 부품 600x400 — 결 lengthwise. 시트 2440x1220.
      // grainLocked=false라도 lengthwise는 회전 금지 → 항상 정방향.
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      const parts = [
        CutPart(
          id: 'p1',
          length: 600,
          width: 400,
          qty: 4,
          grainDirection: GrainDirection.lengthwise,
        ),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.placed.every((p) => !p.rotated), true,
          reason: 'lengthwise 부품은 모두 정방향이어야 함');
    });

    test('부품별 grainDirection.widthwise: 강제 회전', () {
      // 부품 50x200 — 결 widthwise. 시트 1000x100.
      // 정방향(50, 200)은 안 들어가지만 강제 회전(200, 50) → 들어감.
      const stocks = [
        StockSheet(id: 's1', length: 1000, width: 100, qty: 1),
      ];
      const parts = [
        CutPart(
          id: 'p1',
          length: 50,
          width: 200,
          qty: 5,
          grainDirection: GrainDirection.widthwise,
        ),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.placed.every((p) => p.rotated), true,
          reason: 'widthwise 부품은 모두 회전 배치');
    });

    test('좌측 컴팩션: 배치 후 어떤 부품도 더 왼쪽으로 슬라이드할 수 없어야 함', () {
      // 임의의 부품 묶음. 솔버가 어떻게 배치하든 후처리로 왼쪽 정렬되어야 함.
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      // 가는 strip(한 변 <=50mm) 부품은 thin-relocation 패스로 우측 이동되어
      // 순수 좌측 컴팩션 불변량을 깸. 여기서는 strip 없는 입력으로 검증.
      const parts = [
        CutPart(id: 'a', length: 1109, width: 360, qty: 6),
        CutPart(id: 'b', length: 1000, width: 60, qty: 1),
        CutPart(id: 'c', length: 200, width: 60, qty: 1),
        CutPart(id: 'd', length: 800, width: 60, qty: 1),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );

      // 컴팩션 불변량: 각 부품 P 에 대해 y로 겹치는 좌측 부품 중 가장 오른쪽 모서리에서
      // kerf만큼 떨어져 있거나(왼쪽 이웃 존재) 시트 좌단(x=0)이어야 함.
      for (final sheet in plan.sheets) {
        for (final p in sheet.placed) {
          final pw = p.rotated ? p.part.width : p.part.length;
          final ph = p.rotated ? p.part.length : p.part.width;
          assert(pw > 0);
          double maxLeftWall = 0;
          for (final q in sheet.placed) {
            if (identical(p, q)) continue;
            final qw = q.rotated ? q.part.width : q.part.length;
            final qh = q.rotated ? q.part.length : q.part.width;
            final yOverlap =
                (q.y < p.y + ph + 3) && (q.y + qh + 3 > p.y);
            if (yOverlap && q.x + qw <= p.x) {
              final wall = q.x + qw + 3;
              if (wall > maxLeftWall) maxLeftWall = wall;
            }
          }
          expect(
            (p.x - maxLeftWall).abs() < 0.5 || p.x < 0.5,
            true,
            reason:
                'part(${p.part.id}) x=${p.x} 가 좌측 벽($maxLeftWall) 또는 0이 아님',
          );
        }
      }
    });

    test('상단 컴팩션: 배치 후 어떤 부품도 더 위로 슬라이드할 수 없어야 함', () {
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      // 가는 strip(<=50mm 한 변) 부품은 thin-relocation 패스가 우측으로 이동시키므로
      // 순수 상단 컴팩션 불변량과 충돌. 여기서는 strip 없는 입력으로 검증.
      const parts = [
        CutPart(id: 'a', length: 800, width: 361, qty: 4),
        CutPart(id: 'b', length: 300, width: 380, qty: 6),
        CutPart(id: 'c', length: 300, width: 361, qty: 3),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );

      // 컴팩션 불변량: 각 부품 P 에 대해 x로 겹치는 상측 부품 중 가장 아래 모서리에서
      // kerf만큼 떨어져 있거나(상측 이웃 존재) 시트 상단(y=0)이어야 함.
      for (final sheet in plan.sheets) {
        for (final p in sheet.placed) {
          final pw = p.rotated ? p.part.width : p.part.length;
          double maxTopWall = 0;
          for (final q in sheet.placed) {
            if (identical(p, q)) continue;
            final qw = q.rotated ? q.part.width : q.part.length;
            final qh = q.rotated ? q.part.length : q.part.width;
            final xOverlap =
                (q.x < p.x + pw + 3) && (q.x + qw + 3 > p.x);
            if (xOverlap && q.y + qh <= p.y) {
              final wall = q.y + qh + 3;
              if (wall > maxTopWall) maxTopWall = wall;
            }
          }
          expect(
            (p.y - maxTopWall).abs() < 0.5 || p.y < 0.5,
            true,
            reason:
                'part(${p.part.id}) y=${p.y} 가 상단 벽($maxTopWall) 또는 0이 아님',
          );
        }
      }
    });

    test('thin strip 재배치: 가는 부품들이 본체 우측 빈 영역으로 모임', () {
      // 본체 부품(400×400)이 좌상단 절반만 차지하고 우측에 큰 빈 영역이 남는 케이스.
      // 가는 strip(전면밴드, 길이200 두께20)들이 우측 strip으로 재배치되는지 확인.
      const stocks = [
        StockSheet(id: 's1', length: 2440, width: 1220, qty: 1),
      ];
      const parts = [
        CutPart(id: 'body', length: 400, width: 400, qty: 6),
        CutPart(id: 'strip', length: 200, width: 20, qty: 4),
      ];
      final plan = solver.solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );

      // 본체 부품들의 우측 끝.
      double bodyRight = 0;
      for (final p in plan.sheets.first.placed) {
        if (p.part.id != 'body') continue;
        final pw = p.rotated ? p.part.width : p.part.length;
        final r = p.x + pw;
        if (r > bodyRight) bodyRight = r;
      }
      // 모든 strip 부품이 본체 우측(>= bodyRight)에 위치해야 함.
      for (final p in plan.sheets.first.placed) {
        if (p.part.id != 'strip') continue;
        expect(p.x >= bodyRight, true,
            reason:
                'strip 부품 x=${p.x} 가 본체 우측($bodyRight)보다 작음 — 재배치 실패');
      }
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
