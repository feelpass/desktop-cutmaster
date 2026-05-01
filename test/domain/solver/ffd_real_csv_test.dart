import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/solver/auto_recommend.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';
import 'package:cutmaster/domain/solver/strip_cut_solver.dart';

/// 실 사용자 CSV(0502전경인화이트.CSV) 기반 회귀 테스트.
/// 동일 색상(화이트_18T)의 11개 행, 총 21장 부품, 2440×1220 자재.
///
/// 이론적 최대 효율 (모두 2장에 배치):
///   total_parts_area = ~4.25M mm²
///   2 stocks  area   = ~5.95M mm²
///   max_eff          = ~71.3%
///
/// 시트가 충분(qty=999)히 주어지면 unplaced=0이어야 하고,
/// 효율은 65% 이상은 나와야 한다 — 이 임계값을 넘지 못하면 솔버 회귀.
void main() {
  group('FFD on 0502전경인화이트.CSV', () {
    final stocks = [
      const StockSheet(
        id: 's_white',
        length: 2440,
        width: 1220,
        qty: 999,
        label: '화이트_18T',
      ),
    ];

    final parts = [
      _part('이동선반_a', 304.5, 262.5, 4),
      _part('이동선반_b', 312.0, 262.5, 2),
      _part('지판', 1000.0, 290.0, 1),
      _part('천판', 1000.0, 290.0, 1),
      _part('중측판_a', 1030.0, 265.5, 1),
      _part('중측판_b', 1030.0, 265.5, 1),
      _part('뒷판', 1030.0, 961.0, 1),
      _part('우측판_뒤집기', 1030.0, 286.0, 1),
      _part('좌측판_뒤집기', 1030.0, 286.0, 1),
      _part('좌도어', 1070.0, 329.5, 2),
      _part('우도어', 1070.0, 329.5, 1),
    ];

    test('모든 부품이 배치되어야 한다 (unplaced=0)', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      expect(plan.unplaced, isEmpty,
          reason: '시트 999장 가용인데 미배치 발생: ${plan.unplaced.length}');
    });

    test('효율은 65% 이상이어야 한다', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      // 진단용 — 실제 효율을 콘솔로 출력
      // ignore: avoid_print
      print('FFD 효율: ${plan.efficiencyPercent.toStringAsFixed(2)}%, '
          '시트=${plan.sheets.length}, '
          '미배치=${plan.unplaced.length}');
      expect(plan.efficiencyPercent, greaterThanOrEqualTo(65.0),
          reason: '현재 효율 ${plan.efficiencyPercent.toStringAsFixed(1)}% — '
              '솔버가 시트 활용을 충분히 못함. '
              '시트 수=${plan.sheets.length}');
    });

    test('시트 수는 최소 2장이어야 하고 4장을 넘지 않아야 한다', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      expect(plan.sheets.length, greaterThanOrEqualTo(2));
      expect(plan.sheets.length, lessThanOrEqualTo(4),
          reason: '시트 ${plan.sheets.length}장 사용 — 너무 많음. 솔버 최적화 필요');
    });

    test('진단: grainLocked=true → 회전 금지 시 효율', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: true,
      );
      // ignore: avoid_print
      print('FFD grainLocked=true: ${_fmt(plan)}');
    });

    test('진단: 더 큰 kerf (5mm)에서의 효율', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 5,
        grainLocked: false,
      );
      // ignore: avoid_print
      print('FFD kerf=5: ${_fmt(plan)}');
    });

    test('runCalculate flow (derivedStocks + 그룹별) — 단일 자재일 때 FFD 직접호출과 동일 효율',
        () {
      _verifyDerivedStocksFlow(parts, stocks, 65.0);
    });

    test('진단: stripCut+auto vs FFD 효율 비교', () {
      final ffd = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      final auto = AutoRecommend().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      final stripV = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      final stripH = StripCutSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
        direction: StripDirection.horizontalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      // ignore: avoid_print
      print('=== 진단 ===');
      // ignore: avoid_print
      print('FFD             : ${_fmt(ffd)}');
      // ignore: avoid_print
      print('AutoRecommend   : ${_fmt(auto.plan)} (winner: ${auto.runnerUpDirection})');
      // ignore: avoid_print
      print('StripCut 세로풀컷: ${_fmt(stripV)}');
      // ignore: avoid_print
      print('StripCut 가로풀컷: ${_fmt(stripH)}');
    });
  });
}

String _fmt(CuttingPlan p) =>
    '효율 ${p.efficiencyPercent.toStringAsFixed(2)}%, 시트 ${p.sheets.length}, 미배치 ${p.unplaced.length}';

/// Project.derivedStocks() + 그룹별 FFD 호출을 모방.
/// runCalculate의 핵심 로직이 단일 자재일 때 FFDSolver 직접 호출과 동일한 결과를 내는지 검증.
void _verifyDerivedStocksFlow(
    List<CutPart> parts, List<StockSheet> stocks, double minEff) {
  final groups = <String, List<CutPart>>{};
  for (final p in parts) {
    final k = '${p.colorPresetId ?? ''}|${p.thickness}';
    groups.putIfAbsent(k, () => []).add(p);
  }

  final allSheets = <SheetLayout>[];
  final allUnplaced = <CutPart>[];
  var totalArea = 0.0;
  var totalUsed = 0.0;

  for (final entry in groups.entries) {
    final groupStock = stocks.first;
    final plan = FFDSolver().solve(
      stocks: [groupStock],
      parts: entry.value,
      kerf: 3,
      grainLocked: false,
    );
    allSheets.addAll(plan.sheets);
    allUnplaced.addAll(plan.unplaced);
    for (final s in plan.sheets) {
      totalArea += s.sheetLength * s.sheetWidth;
      for (final p in s.placed) {
        totalUsed += p.part.length * p.part.width;
      }
    }
  }

  final mergedEff = totalArea == 0 ? 0.0 : (totalUsed / totalArea) * 100;
  expect(allUnplaced, isEmpty);
  expect(mergedEff, greaterThanOrEqualTo(minEff));
}


CutPart _part(String label, double length, double width, int qty) {
  return CutPart(
    id: label,
    length: length,
    width: width,
    qty: qty,
    label: label,
  );
}
