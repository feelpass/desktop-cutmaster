import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cut_part.dart';
import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import '../../domain/solver/solver_isolate.dart';
import 'tabs_provider.dart';

/// 마지막 계산 결과. null = 아직 계산 안 함 (EmptyResultPane 표시).
final cuttingPlanProvider = StateProvider<CuttingPlan?>((ref) => null);

/// 솔버 실행 중 여부 (UI loading 표시용).
final isCalculatingProvider = StateProvider<bool>((ref) => false);

/// 자동 추천 모드에서 winner/runner-up 토글. 기본 false (winner 표시).
final showRunnerUpProvider = StateProvider<bool>((ref) => false);

/// 표시 대상 plan (winner 또는 runner-up). null이면 아직 계산 안 됨.
final displayedPlanProvider = Provider<CuttingPlan?>((ref) {
  final plan = ref.watch(cuttingPlanProvider);
  if (plan == null) return null;
  final showRunner = ref.watch(showRunnerUpProvider);
  if (showRunner && plan.runnerUp != null) {
    return plan.runnerUp;
  }
  return plan;
});

/// 솔버 실행 함수. ▶ 계산 버튼이 호출.
///
/// 자재(color+두께)별로 부품을 그룹핑해 각 그룹마다 솔버를 별도 실행한다.
/// 헤드컷이 설정되어 있으면 자재의 유효 영역(가로-좌-우, 세로-상-하)을 줄여
/// 솔버에 전달하고, 결과 부품 좌표는 헤드컷 오프셋만큼 이동시켜 원본 시트
/// 좌표계에 매핑한다.
Future<void> runCalculate(WidgetRef ref) async {
  final project = ref.read(activeProjectProvider);
  if (project == null) return;
  ref.read(isCalculatingProvider.notifier).state = true;
  try {
    final allStocks = project.derivedStocks();
    final groups = _groupPartsByMaterial(project.parts);
    final hcLeft = project.headcutLeft;
    final hcTop = project.headcutTop;
    final hcRight = project.headcutRight;
    final hcBottom = project.headcutBottom;
    final hcH = hcLeft + hcRight;
    final hcV = hcTop + hcBottom;

    final allSheets = <SheetLayout>[];
    final allUnplaced = <CutPart>[];
    var totalUsed = 0.0;
    var totalArea = 0.0;

    for (final entry in groups.entries) {
      final key = entry.key;
      final groupParts = entry.value;
      final groupStock = allStocks.firstWhere(
        (s) => _stockKey(s) == key,
        orElse: () => allStocks.first,
      );

      // 헤드컷 적용 — 솔버에는 줄어든 유효 영역만 보여줌.
      final effLength = (groupStock.length - hcH).clamp(0, double.infinity);
      final effWidth = (groupStock.width - hcV).clamp(0, double.infinity);
      final effectiveStock = StockSheet(
        id: groupStock.id,
        length: effLength.toDouble(),
        width: effWidth.toDouble(),
        qty: groupStock.qty,
        label: groupStock.label,
        grainDirection: groupStock.grainDirection,
        colorPresetId: groupStock.colorPresetId,
      );

      final plan = await solveInIsolate(
        stocks: [effectiveStock],
        parts: groupParts,
        kerf: project.kerf,
        grainLocked: project.grainLocked,
        solverMode: project.solverMode,
        stripDirection: project.stripDirection,
        maxStages: project.maxStages,
        preferSameWidth: project.preferSameWidth,
        minimizeCuts: project.minimizeCuts,
        minimizeWaste: project.minimizeWaste,
      );

      // 좌표를 원본 시트 기준으로 오프셋해 시각화 + 실제 절단 좌표 일치.
      for (final s in plan.sheets) {
        final offsetPlaced = s.placed
            .map((p) => PlacedPart(
                  part: p.part,
                  x: p.x + hcLeft,
                  y: p.y + hcTop,
                  rotated: p.rotated,
                ))
            .toList();
        final offsetLeftovers = s.leftovers
            .map((r) => LeftoverRect(
                  x: r.x + hcLeft,
                  y: r.y + hcTop,
                  width: r.width,
                  height: r.height,
                ))
            .toList();
        allSheets.add(SheetLayout(
          stockSheetId: s.stockSheetId,
          placed: offsetPlaced,
          // 시트 차원은 원본(2440×1220) 유지 — 사용자가 헤드컷 음영 영역 시각 인식.
          sheetLength: groupStock.length,
          sheetWidth: groupStock.width,
          cutSequence: s.cutSequence,
          leftovers: offsetLeftovers,
        ));

        // 효율: 유효 영역(헤드컷 제외) 기준으로 계산 — 헤드컷 손실은 솔버 책임 아님.
        totalArea += effLength * effWidth;
        for (final p in s.placed) {
          totalUsed += p.part.length * p.part.width;
        }
      }
      allUnplaced.addAll(plan.unplaced);
    }

    final eff = totalArea == 0 ? 0.0 : (totalUsed / totalArea) * 100;
    final mergedPlan = CuttingPlan(
      sheets: allSheets,
      unplaced: allUnplaced,
      efficiencyPercent: eff,
    );

    ref.read(cuttingPlanProvider.notifier).state = mergedPlan;
    ref.read(showRunnerUpProvider.notifier).state = false;
  } finally {
    ref.read(isCalculatingProvider.notifier).state = false;
  }
}

/// (colorPresetId, thickness) 키별로 부품 그룹핑.
Map<String, List<CutPart>> _groupPartsByMaterial(List<CutPart> parts) {
  final out = <String, List<CutPart>>{};
  for (final p in parts) {
    final k = '${p.colorPresetId ?? ''}|${p.thickness}';
    out.putIfAbsent(k, () => <CutPart>[]).add(p);
  }
  return out;
}

/// derivedStocks가 만든 stock id (`auto_<color>|<thickness>`)에서 키 추출.
String _stockKey(StockSheet s) {
  final id = s.id;
  if (id.startsWith('auto_')) return id.substring(5);
  return '${s.colorPresetId ?? ''}|';
}
