import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/solver/strip_cut_solver.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  group('StripCutSolver — scaffold smoke', () {
    test('empty stocks → empty plan, efficiency 0', () {
      final plan = StripCutSolver().solve(
        stocks: const [],
        parts: const [
          CutPart(id: 'a', length: 100, width: 100, qty: 1, label: 'A'),
        ],
        kerf: 3,
        grainLocked: false,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });

    test('empty parts → empty plan, efficiency 0', () {
      final plan = StripCutSolver().solve(
        stocks: const [
          StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: const [],
        kerf: 3,
        grainLocked: false,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });

    test('asserts when direction is auto', () {
      expect(
        () => StripCutSolver().solve(
          stocks: const [
            StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
          ],
          parts: const [
            CutPart(id: 'a', length: 100, width: 100, qty: 1, label: 'A'),
          ],
          kerf: 3,
          grainLocked: false,
          direction: StripDirection.auto,
          maxStages: 3,
          preferSameWidth: true,
          minimizeCuts: true,
          minimizeWaste: true,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('StripCutSolver — 3-stage vertical-first basic (all toggles OFF)', () {
    test('two identical parts fit in one strip with two segments', () {
      // 시트 1000 x 500. 부품 A: 400 x 200 x qty 2.
      // 한 strip(폭 400)에 두 segment(각 길이 200) 배치.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.sheets.length, 1);
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.placed.length, 2);
      expect(plan.sheets.first.cutSequence, isNotNull);
      expect(plan.sheets.first.cutSequence!.verticalFirst, true);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
      expect(plan.sheets.first.cutSequence!.strips.first.width, 400);
      expect(plan.sheets.first.cutSequence!.strips.first.offset, 0);
    });

    test('two different-length parts → two strips of different widths', () {
      // 시트 1000 x 500. 부품 A: 400x200 qty1, B: 300x200 qty1.
      // strip1: 폭 400, A 들어감. strip2: 폭 300, B 들어감.
      // exact-match grouping을 검증하는 fixture라 preferSameWidth: true.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 2);
      expect(plan.sheets.first.cutSequence!.strips[0].width, 400);
      expect(plan.sheets.first.cutSequence!.strips[1].width, 300);
      expect(plan.sheets.first.cutSequence!.strips[1].offset, 400);
    });

    test('part too wide → unplaced', () {
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 300, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 600, width: 100, qty: 1, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced.length, 1);
    });

    test('kerf reduces effective space', () {
      // 시트 1000 x 500. kerf 10. 부품 400x200 qty 2.
      // strip 폭 400, kerf 10 사이. 두 strip 가능: 400 + 10 + 400 = 810 ≤ 1000. ✓
      // 한 strip 안에 segment 2개: 200 + 10 + 200 = 410 ≤ 500. ✓
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
        ],
        kerf: 10,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
      // 두 번째 segment의 offset은 200 + 10 = 210
      expect(
        plan.sheets.first.cutSequence!.strips.first.segments[1].offset,
        210,
      );
    });
  });

  group('StripCutSolver — 3-stage horizontal-first basic (all toggles OFF)', () {
    test('horizontal-first mirrors vertical-first when sheet/parts swapped', () {
      // verticalFirst로 (1000x500) + (400x200 qty 2) → 잘 됨 (Task 6 fixture).
      // horizontalFirst로 (500x1000) + (200x400 qty 2) → 동일한 결과 구조.
      final h = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 1000, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 200, width: 400, qty: 2, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(h.sheets.length, 1);
      expect(h.unplaced, isEmpty);
      expect(h.sheets.first.placed.length, 2);
      expect(h.sheets.first.cutSequence, isNotNull);
      expect(h.sheets.first.cutSequence!.verticalFirst, false);
      expect(h.sheets.first.cutSequence!.strips.length, 1);
      expect(h.sheets.first.cutSequence!.strips.first.segments.length, 2);
      expect(h.sheets.first.cutSequence!.strips.first.width, 400);
      expect(h.sheets.first.cutSequence!.strips.first.offset, 0);
    });

    test('horizontal-first: two different-width parts → two strips of different widths', () {
      // 시트 500x1000. 부품 A: 200x400 qty1, B: 200x300 qty1.
      // strip1 폭 400, A. strip2 폭 300, B.
      // exact-match grouping을 검증하는 fixture라 preferSameWidth: true.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 1000, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 200, width: 400, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 200, width: 300, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 2);
      expect(plan.sheets.first.cutSequence!.strips[0].width, 400);
      expect(plan.sheets.first.cutSequence!.strips[1].width, 300);
      expect(plan.sheets.first.cutSequence!.strips[1].offset, 400);
    });

    test('horizontal-first: kerf between strips and segments', () {
      // 시트 500x1000. kerf 10. 부품 200x400 qty 2.
      // strip 폭 400, kerf 10 사이. 두 strip: 400+10+400 = 810 ≤ 1000.
      // segment 안: 200+10+200 = 410 ≤ 500.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 1000, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 200, width: 400, qty: 2, label: 'A'),
        ],
        kerf: 10,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
      expect(
        plan.sheets.first.cutSequence!.strips.first.segments[1].offset,
        210,
      );
    });
  });

  group('StripCutSolver — preferSameWidth toggle', () {
    test('preferSameWidth=true keeps exact-match (Task 6 baseline preserved)', () {
      // Same as Task 6's "two different-length parts → two strips of different widths"
      // but explicitly preferSameWidth=true.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 2);
      // exact-match invariant: 모든 segment의 trim은 0이어야 함.
      for (final strip in plan.sheets.first.cutSequence!.strips) {
        for (final seg in strip.segments) {
          expect(seg.trim, 0, reason: 'exact-match → trim must be 0');
        }
      }
    });

    test('preferSameWidth=false enables widest-fit: shorter part joins wider strip', () {
      // 시트 1000 x 500. 부품 A: 400x200 qty1, B: 300x200 qty1.
      // preferSameWidth=false → 둘 다 같은 strip (폭 400)에 들어감. trim = 100 for B.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 1); // single strip!
      expect(plan.sheets.first.cutSequence!.strips.first.width, 400);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
      // B's segment has trim = stripWidth(400) - B.length(300) = 100
      final segments = plan.sheets.first.cutSequence!.strips.first.segments;
      expect(segments[0].trim, 0); // A: exact match
      expect(segments[1].trim, 100); // B: trimmed
    });

    test('preferSameWidth=false horizontal-first widest-fit by width', () {
      // 시트 500 x 1000 + 부품 A 200x400 qty 1 + B 200x300 qty 1.
      // horizontalFirst → strip 폭 = 부품 width.
      // preferSameWidth=false → strip 폭 400, 둘 다 들어감. B의 trim = 400-300 = 100.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 1000, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 200, width: 400, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 200, width: 300, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.sheets.first.cutSequence!.strips.first.width, 400);
      final segments = plan.sheets.first.cutSequence!.strips.first.segments;
      expect(segments[0].trim, 0);
      expect(segments[1].trim, 100);
    });
  });

  group('StripCutSolver — minimizeCuts toggle', () {
    test('minimizeCuts=true sanity: produces valid plan on basic fixture', () {
      // 시트 1000x500. 부품 A 400x200 qty 2. minimizeCuts=true.
      // BFD도 단순 케이스에서는 동일하게 한 strip(폭 400)에 두 segment 배치.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: true,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.length, 1);
      expect(plan.sheets.first.placed.length, 2);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
    });

    test('minimizeCuts=true uses BFD to consolidate strips (strict)', () {
      // 시트 2500 x 1000. preferSameWidth=false, grainLocked=true, kerf=0.
      // 부품 (primary desc 정렬): A 1000x600, B 900x700, C 800x300, D 300x350.
      //
      // 진행 시나리오:
      // A → strip1 (offset 0, width 1000, currentY=600). leftover Y=400.
      // B 700>400 → strip1 안 들어감. strip2 (offset 1000, width 900, currentY=700). leftover Y=300.
      // C primary 800: strip1(leftover 100), strip2(leftover 0) 둘 다 fit.
      //   - FF: strip1 선택 → strip1 currentY=900, strip2 currentY=700.
      //   - BFD: leftover 작은 쪽(strip2) 선택 → strip1 currentY=600, strip2 currentY=1000.
      // D primary 300, secondary 350:
      //   - FF: strip1 leftover 100<350, strip2 leftover 300<350 → 새 strip3 (offset 1900, width 300, end 2200).
      //         3 strips.
      //   - BFD: strip1 leftover 400≥350 fit. strip1 사용 → 2 strips.
      final stocks = [
        const StockSheet(id: 's', length: 2500, width: 1000, qty: 1, label: ''),
      ];
      final parts = [
        const CutPart(id: 'a', length: 1000, width: 600, qty: 1, label: 'A'),
        const CutPart(id: 'b', length: 900, width: 700, qty: 1, label: 'B'),
        const CutPart(id: 'c', length: 800, width: 300, qty: 1, label: 'C'),
        const CutPart(id: 'd', length: 300, width: 350, qty: 1, label: 'D'),
      ];

      final ff = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      final bfd = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: true,
        minimizeWaste: false,
      );

      expect(ff.unplaced, isEmpty);
      expect(bfd.unplaced, isEmpty);
      expect(ff.sheets.first.cutSequence!.strips.length, 3,
          reason: 'FF은 D 위해 새 strip3을 만들어야 함');
      expect(bfd.sheets.first.cutSequence!.strips.length, 2,
          reason: 'BFD는 D를 strip1에 끼워 넣어 strip 수 절약');
      expect(
        bfd.sheets.first.cutSequence!.strips.length,
        lessThan(ff.sheets.first.cutSequence!.strips.length),
      );
    });
  });

  group('StripCutSolver — minimizeWaste toggle', () {
    test('minimizeWaste=false: post-processing skipped — unplaced stays unplaced', () {
      // 시트 1000x500. preferSameWidth=false, minimizeCuts=false.
      // 부품 A 1000x400, B 1000x150 (정렬 후 입력 순서대로 동률).
      // 메인 루프:
      //   A → strip1 width 1000, currentY 400, leftover 100.
      //   B primary 1000 fit. 150 > 100 → no fit in strip1.
      //        새 strip 시도: offset 1000+0=1000, end 2000>1000 → 못 만듦. → unplaced.
      // minimizeWaste=false → post-process 안 함. unplaced=[B] 유지.
      // (post-process 자체도 strip1 leftover 100 < 150 라 차이 없지만,
      //  본 테스트는 OFF baseline 회귀 방어용.)
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 1000, width: 400, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 1000, width: 150, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.sheets.length, 1);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.unplaced.length, 1);
      expect(plan.unplaced.first.id, 'b');
    });

    test('minimizeWaste=true: ON never increases unplaced count vs OFF (property)', () {
      // 동일 입력에 대해 minimizeWaste 토글만 다르게 두 번 풀고,
      // ON의 unplaced 수가 OFF보다 절대 많지 않음을 보장 (no regression).
      // 1-pass post-processing은 항상 strict subset 시도이므로 fail-safe해야 함.
      final stocks = [
        const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
      ];
      final parts = [
        const CutPart(id: 'a', length: 1000, width: 400, qty: 1, label: 'A'),
        const CutPart(id: 'b', length: 1000, width: 150, qty: 1, label: 'B'),
      ];
      final off = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      final on = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(on.unplaced.length, lessThanOrEqualTo(off.unplaced.length),
          reason: 'minimizeWaste=true는 unplaced를 절대 늘리지 않아야 한다.');
      // efficiency 도 같은 이유로 ON ≥ OFF.
      expect(on.efficiencyPercent, greaterThanOrEqualTo(off.efficiencyPercent),
          reason: 'minimizeWaste=true는 효율을 절대 떨어뜨리지 않아야 한다.');
    });

    test('minimizeWaste=true: post-processing pass runs and produces a valid plan (sanity)', () {
      // 시트 1000x500. 부품 A 1000x400, B 1000x100. 모두 strip1에 fit.
      //   A → strip1 currentY=400, leftover 100.
      //   B → strip1 fit (100 ≤ 100, boundary). currentY=500, leftover=0.
      //   메인 루프 자체로 unplaced=[]. post-processing은 호출되지만 할 일 없음.
      //   → ON/OFF 모두 동일한 valid plan 보장.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 1000, width: 400, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 1000, width: 100, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(plan.sheets.length, 1);
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.placed.length, 2);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
      expect(plan.efficiencyPercent, greaterThan(0));
    });
  });

  group('StripCutSolver — maxStages=2 exact mode', () {
    test('maxStages=2 forces exact-match: width-mismatched part is unplaced', () {
      // 시트 1000x500. 부품 A 400x200, B 300x200. preferSameWidth=false (의미 없음, 강제 true).
      // maxStages=2: A → strip1 (width 400). B primary 300 != 400 → 새 strip2 (width 300).
      //   strip1 ends 400, strip2 ends 400+0+300=700. 700 ≤ 1000 ✓.
      //   Both placed.
      // 즉, 단순히 "width 다른 부품 → 별도 strip" 동작이 강제됨.
      // unplaced 발생 시나리오: 새 strip이 시트에 fit 안 하는 경우.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 600, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 2,
        preferSameWidth: false, // 무시됨 (2-stage forces exact)
        minimizeCuts: false,
        minimizeWaste: false,
      );
      // strip1 width 400 ends at 400. strip2 width 300 starts at 400, ends 700 > 600 → can't open.
      // → A placed, B unplaced.
      expect(plan.unplaced.length, 1);
      expect(plan.unplaced.first.id, 'b');
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
    });

    test('maxStages=3 with preferSameWidth=false: same input places B (widest-fit)', () {
      // Same inputs as above but maxStages=3 + preferSameWidth=false → widest-fit allowed.
      // A → strip1 width 400. B primary 300 ≤ 400 → fit, trim 100.
      // → B placed in same strip with trim.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 600, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      // B's segment has trim = 100
      final segments = plan.sheets.first.cutSequence!.strips.first.segments;
      expect(segments[1].trim, 100);
    });

    test('maxStages=2 with all same-width parts: trim is always 0', () {
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 2,
        preferSameWidth: false, // 무시됨
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced, isEmpty);
      for (final strip in plan.sheets.first.cutSequence!.strips) {
        for (final seg in strip.segments) {
          expect(seg.trim, 0);
        }
      }
    });

    test('maxStages=2 horizontal-first: width-mismatched part is unplaced', () {
      // Vertical-first의 미러: 시트 500x600. 부품 A 200x400 + B 200x300.
      // horizontalFirst → strip 폭 = 부품 width.
      // 2-stage 강제 exact-match: A → strip width 400, B primary 300 != 400 → 새 strip width 300.
      // strip1 ends at Y=400. strip2 starts Y=400, ends 700 > 600 → unplaced.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 500, width: 600, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 200, width: 400, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 200, width: 300, qty: 1, label: 'B'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.horizontalFirst,
        maxStages: 2,
        preferSameWidth: false,  // 무시됨 (2-stage forces exact)
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced.length, 1);
      expect(plan.unplaced.first.id, 'b');
      expect(plan.sheets.first.cutSequence!.strips.length, 1);
      expect(plan.sheets.first.cutSequence!.verticalFirst, false);
    });
  });

  group('StripCutSolver — maxStages=4 nested trim', () {
    test('maxStages=4 + minimizeWaste: small part rescued into segment trim',
        () {
      // 시트 550x500. 부품 A 500x300, B 300x200, C 100x100.
      // primary desc 정렬: A(500) → B(300) → C(100).
      //
      // 메인 fill (verticalFirst, preferSameWidth=false):
      //   A → strip1 offset=0 width=500. seg1 (trim 0). currentY=300, leftover 200.
      //   B primary=300 ≤ 500 ✓, sec=200 ≤ 200 ✓ → strip1.
      //     seg2 trim = 500-300 = 200. currentY=500, leftover 0.
      //   C primary=100 ≤ 500 ✓, sec=100 > 0 → strip1 안 들어감.
      //     New strip offset 500, ends 600 > 550 → 새 strip 못 만듦 → unplaced.
      //
      // maxStages=3 + minimizeWaste post-pass(strip leftover):
      //   strip1 leftover=0, 다른 strip 없음 → C 여전히 unplaced.
      //
      // maxStages=4 + minimizeWaste post-pass(segment trim rescue):
      //   B의 seg2 trim=200, C primary=100 ≤ 200 ✓, C sec=100 ≤ 200 (seg.length) ✓.
      //   → C rescue! placed.
      final stage3 = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 550, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 500, width: 300, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
          const CutPart(id: 'c', length: 100, width: 100, qty: 1, label: 'C'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(stage3.unplaced.length, 1, reason: 'C는 3-stage에서 rescue 불가');
      expect(stage3.unplaced.first.id, 'c');

      final stage4 = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 550, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 500, width: 300, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
          const CutPart(id: 'c', length: 100, width: 100, qty: 1, label: 'C'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 4,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(stage4.unplaced, isEmpty,
          reason: 'C는 B의 segment trim 으로 rescue 되어야 함');
      expect(stage4.sheets.first.placed.length, 3);

      // C 는 B의 segment trim 안에 들어가야 함:
      //   B는 strip1 (offset 0, width 500), seg2 (offset 300, length 200).
      //   메인부품(B) primary=300, kerf=0 → C 의 x = 0 + 300 + 0 = 300.
      //   C 의 y = seg2.offset = 300.
      final c = stage4.sheets.first.placed.firstWhere((pp) => pp.part.id == 'c');
      expect(c.x, 300);
      expect(c.y, 300);

      // CutSequence 에서도 stage-4 nesting 이 보여야 함:
      //   strip1.segments[1] (B의 segment) 에 parts 길이 2 (B + C), trim 100.
      final strip1 = stage4.sheets.first.cutSequence!.strips.first;
      final bSeg = strip1.segments[1];
      expect(bSeg.parts.length, 2);
      expect(bSeg.parts.last.part.id, 'c');
      expect(bSeg.trim, 100); // 200 - 100 - kerf(0)
    });

    test('maxStages=4 + minimizeWaste=false: rescue not triggered', () {
      // 같은 fixture 인데 minimizeWaste=false 면 rescue 안 일어남.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 550, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 500, width: 300, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 300, width: 200, qty: 1, label: 'B'),
          const CutPart(id: 'c', length: 100, width: 100, qty: 1, label: 'C'),
        ],
        kerf: 0,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 4,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: false,
      );
      expect(plan.unplaced.length, 1);
      expect(plan.unplaced.first.id, 'c');
    });

    test('maxStages=4 with kerf>0: kerf consumed from trim space', () {
      // kerf=10. 시트 550x500. A 500x300, B 280x200 (trim=500-280=220), C 100x100.
      // A → strip1 width 500, seg1 trim 0, currentY=300.
      // B primary=280 ≤ 500 ✓, sec=200 ≤ leftover 200 - kerf=190? Wait segOffset
      //   = currentY + kerf = 310. 310 + 200 = 510 > 500 → strip1 fit 아님.
      //   New strip offset = 500 + 10 = 510, ends 510+280=790 > 550 → 안 됨.
      //   → B unplaced.
      // 그러면 fixture 바뀜. kerf=10 케이스는 다르게 짜야 함.
      //
      // 더 간단히: 시트 510x500. A 500x300, B 280x190, C 100x100. kerf=10.
      //   A → strip1 width 500, seg1 trim 0, currentY=300.
      //   B primary=280 ≤ 500 ✓. segOffset = 300+10 = 310. 310+190 = 500 ≤ 500 ✓.
      //     seg2 trim = 500-280 = 220. currentY = 500.
      //   C primary=100 ≤ 500. sec=100 → segOffset 510 > 500 fail.
      //     New strip offset 510, ends 510+100=610 > 510 → unplaced.
      //   maxStages=4 rescue: B의 seg2 trim=220, usable = 220-10 = 210 ≥ 100 ✓,
      //     sec 100 ≤ 190 (seg.length) ✓.
      //     C 의 x = 0 + 280 + 10 = 290. y = seg2.offset = 310.
      final plan = StripCutSolver().solve(
        stocks: [
          const StockSheet(id: 's', length: 510, width: 500, qty: 1, label: ''),
        ],
        parts: [
          const CutPart(id: 'a', length: 500, width: 300, qty: 1, label: 'A'),
          const CutPart(id: 'b', length: 280, width: 190, qty: 1, label: 'B'),
          const CutPart(id: 'c', length: 100, width: 100, qty: 1, label: 'C'),
        ],
        kerf: 10,
        grainLocked: true,
        direction: StripDirection.verticalFirst,
        maxStages: 4,
        preferSameWidth: false,
        minimizeCuts: false,
        minimizeWaste: true,
      );
      expect(plan.unplaced, isEmpty);
      final c = plan.sheets.first.placed.firstWhere((pp) => pp.part.id == 'c');
      expect(c.x, 290);
      expect(c.y, 310);
    });
  });
}
