import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/solver_mode.dart';
import '../models/stock_sheet.dart';
import 'strip_cut_solver.dart';

/// [AutoRecommend.solve] 결과. winner의 plan과 함께 진 쪽(runner-up) 정보를
/// 동봉하므로 UI는 두 방향 모두를 비교 표시할 수 있다.
class AutoRecommendResult {
  /// 우승한 방향의 cutting plan.
  final CuttingPlan plan;

  /// 우승한 방향 (verticalFirst 또는 horizontalFirst).
  final StripDirection winner;

  /// 진 쪽 cutting plan.
  final CuttingPlan runnerUp;

  /// 진 쪽 방향.
  final StripDirection runnerUpDirection;

  const AutoRecommendResult({
    required this.plan,
    required this.winner,
    required this.runnerUp,
    required this.runnerUpDirection,
  });
}

/// [StripDirection.auto] 처리를 위한 wrapper. 두 방향 (verticalFirst,
/// horizontalFirst) 각각에 대해 [StripCutSolver]를 실행하고 사용자의 토글
/// 설정에 따라 우승자를 선택한다.
///
/// **Tie-break 우선순위 (사용자 토글 기준):**
/// 1. `minimizeWaste` ON → unplaced 면적이 적은 쪽.
/// 2. `minimizeCuts` ON → 절단 수(strip + segment)가 적은 쪽.
/// 3. 기본 → `efficiencyPercent` 높은 쪽.
/// 4. 모든 지표가 같으면 → vertical 우선 (deterministic).
///
/// 솔버 자체는 [StripDirection.auto]를 거부(assert)하므로 auto 분기는
/// 반드시 이 wrapper를 거쳐야 한다.
class AutoRecommend {
  /// 두 방향을 모두 풀고 비교하여 우승자/runner-up을 반환.
  ///
  /// 입력 시그너처는 [StripCutSolver.solve]와 동일하되 `direction`만 빠짐 —
  /// 이 wrapper가 verticalFirst/horizontalFirst 두 호출을 책임진다.
  AutoRecommendResult solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
    required int maxStages,
    required bool preferSameWidth,
    required bool minimizeCuts,
    required bool minimizeWaste,
  }) {
    // Short-circuit: empty input → empty result without invoking solver.
    // StripCutSolver itself short-circuits, but skipping two no-op calls saves
    // overhead and matches the solver's own contract.
    if (stocks.isEmpty || parts.isEmpty) {
      const empty = CuttingPlan(sheets: [], unplaced: [], efficiencyPercent: 0);
      return const AutoRecommendResult(
        plan: empty,
        winner: StripDirection.verticalFirst,
        runnerUp: empty,
        runnerUpDirection: StripDirection.horizontalFirst,
      );
    }

    final solver = StripCutSolver();
    final v = solver.solve(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
      direction: StripDirection.verticalFirst,
      maxStages: maxStages,
      preferSameWidth: preferSameWidth,
      minimizeCuts: minimizeCuts,
      minimizeWaste: minimizeWaste,
    );
    final h = solver.solve(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
      direction: StripDirection.horizontalFirst,
      maxStages: maxStages,
      preferSameWidth: preferSameWidth,
      minimizeCuts: minimizeCuts,
      minimizeWaste: minimizeWaste,
    );

    final pickV = _pickV(
      v,
      h,
      minimizeCuts: minimizeCuts,
      minimizeWaste: minimizeWaste,
    );

    return pickV
        ? AutoRecommendResult(
            plan: v,
            winner: StripDirection.verticalFirst,
            runnerUp: h,
            runnerUpDirection: StripDirection.horizontalFirst,
          )
        : AutoRecommendResult(
            plan: h,
            winner: StripDirection.horizontalFirst,
            runnerUp: v,
            runnerUpDirection: StripDirection.verticalFirst,
          );
  }

  /// vertical을 선택해야 하면 true. tie인 경우 vertical 우선 (deterministic).
  ///
  /// 비교 순서:
  /// 1. minimizeWaste 켜져 있으면 → unplaced 면적 작은 쪽 우선.
  /// 2. minimizeCuts 켜져 있으면 → cut 수 적은 쪽 우선.
  /// 3. 그 외 → efficiencyPercent 높은 쪽.
  /// 4. 모두 같으면 → vertical (true).
  bool _pickV(
    CuttingPlan v,
    CuttingPlan h, {
    required bool minimizeCuts,
    required bool minimizeWaste,
  }) {
    if (minimizeWaste) {
      final vWaste = _unplacedArea(v);
      final hWaste = _unplacedArea(h);
      if (vWaste != hWaste) return vWaste < hWaste;
    }
    if (minimizeCuts) {
      final vCuts = _countCuts(v);
      final hCuts = _countCuts(h);
      if (vCuts != hCuts) return vCuts < hCuts;
    }
    if (v.efficiencyPercent != h.efficiencyPercent) {
      return v.efficiencyPercent > h.efficiencyPercent;
    }
    // tie → vertical 우선.
    return true;
  }

  /// unplaced 부품들의 총 면적 (qty 반영).
  double _unplacedArea(CuttingPlan p) {
    return p.unplaced
        .fold<double>(0, (acc, part) => acc + part.length * part.width * part.qty);
  }

  /// 시트별 strip 수 + segment 수의 총합. cutSequence가 null인 시트는 0으로 처리.
  int _countCuts(CuttingPlan p) {
    int cuts = 0;
    for (final s in p.sheets) {
      final seq = s.cutSequence;
      if (seq == null) continue;
      cuts += seq.strips.length;
      for (final strip in seq.strips) {
        cuts += strip.segments.length;
      }
    }
    return cuts;
  }
}
