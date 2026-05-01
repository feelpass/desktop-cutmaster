import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';

/// 0502전경인화이트.CSV 데이터셋의 효율 한계를 수학적으로 증명하고,
/// 현재 FFD 솔버가 그 한계에 도달하는지 검증.
///
/// 결론 (수학):
///   부품 총 면적 = 4,247,140 mm²
///   1장(2440×1220) 면적 = 2,976,800 mm²
///   필요 시트 = ceil(4,247,140 / 2,976,800) = 2장 (1장엔 면적상 불가능)
///   2장 사용 시 이론 최대 효율 = 4,247,140 / 5,953,600 = **71.34%**
///
/// 즉 71.34%가 절대 상한이며, 더 높이려면 부품 합계 면적을 줄이거나
/// 2440×1220 외의 자재를 도입해야 함.
void main() {
  final stocks = [
    const StockSheet(
        id: 's_white', length: 2440, width: 1220, qty: 999, label: '화이트_18T'),
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

  group('효율 한계 분석', () {
    test('부품 총 면적 / 시트 면적 / 필요 시트 수 / 이론 최대치 출력', () {
      final partsArea = _totalPartsArea(parts);
      final stockArea = stocks.first.length * stocks.first.width;
      final minSheets = (partsArea / stockArea).ceil();
      final theoreticalMax = partsArea / (minSheets * stockArea) * 100;

      // ignore: avoid_print
      print('--- 효율 한계 분석 ---');
      // ignore: avoid_print
      print('부품 총 면적     : ${partsArea.toStringAsFixed(0)} mm²');
      // ignore: avoid_print
      print('1장 면적         : ${stockArea.toStringAsFixed(0)} mm²');
      // ignore: avoid_print
      print('필요 최소 시트   : $minSheets 장');
      // ignore: avoid_print
      print('이론 최대 효율   : ${theoreticalMax.toStringAsFixed(2)}%');

      expect(minSheets, 2);
      expect(theoreticalMax, closeTo(71.34, 0.01));
    });

    test('FFD가 이론 최대 71.34%에 도달해야 한다 (오차 1%)', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );

      final partsArea = _totalPartsArea(parts);
      final stockArea = stocks.first.length * stocks.first.width;
      final minSheets = (partsArea / stockArea).ceil();
      final theoreticalMax = partsArea / (minSheets * stockArea) * 100;

      // ignore: avoid_print
      print('--- FFD 결과 ---');
      // ignore: avoid_print
      print('  효율          : ${plan.efficiencyPercent.toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  이론 최대     : ${theoreticalMax.toStringAsFixed(2)}%');
      // ignore: avoid_print
      print(
          '  gap           : ${(theoreticalMax - plan.efficiencyPercent).toStringAsFixed(2)}%');
      // ignore: avoid_print
      print('  시트 사용     : ${plan.sheets.length}/$minSheets');
      // ignore: avoid_print
      print('  미배치        : ${plan.unplaced.length}');

      expect(plan.unplaced, isEmpty,
          reason: '시트 999장 가용인데 미배치가 발생 — 솔버 버그');
      expect(plan.sheets.length, minSheets,
          reason: '${plan.sheets.length}장 사용 — 최소 $minSheets장으로 줄여야 함');
      expect(plan.efficiencyPercent, greaterThanOrEqualTo(theoreticalMax - 1.0),
          reason:
              'FFD가 이론치 ${theoreticalMax.toStringAsFixed(2)}%에 1% 이내로 도달해야 함');
    });

    test('각 시트별 면적 사용률 — 어느 시트에 빈 공간이 몰리는지 진단', () {
      final plan = FFDSolver().solve(
        stocks: stocks,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      // ignore: avoid_print
      print('--- 시트별 사용률 ---');
      for (var i = 0; i < plan.sheets.length; i++) {
        final s = plan.sheets[i];
        // ignore: avoid_print
        print('  시트 ${i + 1}: ${s.usedPercent.toStringAsFixed(1)}% '
            '(${s.placed.length} 부품)');
      }
    });

    test('이론치 초과 불가능 증명 — 1장에 모든 부품 배치 시도', () {
      // 시트 1장만 줘서 모두 못 들어가는지 확인 (면적 부족 증명).
      final singleSheetStock = [
        const StockSheet(
            id: 's_one', length: 2440, width: 1220, qty: 1, label: '단일'),
      ];
      final plan = FFDSolver().solve(
        stocks: singleSheetStock,
        parts: parts,
        kerf: 3,
        grainLocked: false,
      );
      // ignore: avoid_print
      print('--- 1장만 사용 시 ---');
      // ignore: avoid_print
      print('  미배치: ${plan.unplaced.length}개 → 1장에 다 들어갈 수 없음 증명');

      expect(plan.unplaced, isNotEmpty,
          reason:
              '면적 4.25M mm² > 2.97M mm² 이므로 1장에 다 들어갈 수 없음 (수학적 사실)');
    });
  });
}

CutPart _part(String label, double length, double width, int qty) =>
    CutPart(id: label, length: length, width: width, qty: qty, label: label);

double _totalPartsArea(List<CutPart> parts) =>
    parts.fold<double>(0, (acc, p) => acc + p.length * p.width * p.qty);

// ignore: unused_element
double _planEfficiency(CuttingPlan p) => p.efficiencyPercent;
