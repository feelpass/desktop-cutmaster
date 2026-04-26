import 'package:flutter/foundation.dart';

import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/solver_mode.dart';
import '../models/stock_sheet.dart';
import 'auto_recommend.dart';
import 'ffd_solver.dart';
import 'strip_cut_solver.dart';

/// Isolate에서 솔버 실행. UI 쓰레드 freeze 방지.
/// Flutter의 compute()로 background isolate에 작업 위임.
///
/// dispatch 규칙:
/// - [SolverMode.ffd] → [FFDSolver].
/// - [SolverMode.stripCut] + non-auto direction → [StripCutSolver].
/// - [SolverMode.stripCut] + [StripDirection.auto] → [AutoRecommend]
///   (winner의 plan에 runnerUp/runnerUpDirection이 채워져 반환).
Future<CuttingPlan> solveInIsolate({
  required List<StockSheet> stocks,
  required List<CutPart> parts,
  required double kerf,
  required bool grainLocked,
  required SolverMode solverMode,
  required StripDirection stripDirection,
  required int maxStages,
  required bool preferSameWidth,
  required bool minimizeCuts,
  required bool minimizeWaste,
}) {
  return compute(
    _solveSync,
    _SolverInput(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
      solverMode: solverMode,
      stripDirection: stripDirection,
      maxStages: maxStages,
      preferSameWidth: preferSameWidth,
      minimizeCuts: minimizeCuts,
      minimizeWaste: minimizeWaste,
    ),
  );
}

CuttingPlan _solveSync(_SolverInput input) {
  if (input.solverMode == SolverMode.ffd) {
    return FFDSolver().solve(
      stocks: input.stocks,
      parts: input.parts,
      kerf: input.kerf,
      grainLocked: input.grainLocked,
    );
  }

  // SolverMode.stripCut
  if (input.stripDirection == StripDirection.auto) {
    final auto = AutoRecommend().solve(
      stocks: input.stocks,
      parts: input.parts,
      kerf: input.kerf,
      grainLocked: input.grainLocked,
      maxStages: input.maxStages,
      preferSameWidth: input.preferSameWidth,
      minimizeCuts: input.minimizeCuts,
      minimizeWaste: input.minimizeWaste,
    );
    // winner의 plan을 그대로 사용하되, runnerUp 정보를 동봉해 반환.
    return CuttingPlan(
      sheets: auto.plan.sheets,
      unplaced: auto.plan.unplaced,
      efficiencyPercent: auto.plan.efficiencyPercent,
      runnerUp: auto.runnerUp,
      runnerUpDirection: auto.runnerUpDirection,
    );
  }

  // verticalFirst or horizontalFirst.
  return StripCutSolver().solve(
    stocks: input.stocks,
    parts: input.parts,
    kerf: input.kerf,
    grainLocked: input.grainLocked,
    direction: input.stripDirection,
    maxStages: input.maxStages,
    preferSameWidth: input.preferSameWidth,
    minimizeCuts: input.minimizeCuts,
    minimizeWaste: input.minimizeWaste,
  );
}

class _SolverInput {
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf;
  final bool grainLocked;
  final SolverMode solverMode;
  final StripDirection stripDirection;
  final int maxStages;
  final bool preferSameWidth;
  final bool minimizeCuts;
  final bool minimizeWaste;

  const _SolverInput({
    required this.stocks,
    required this.parts,
    required this.kerf,
    required this.grainLocked,
    required this.solverMode,
    required this.stripDirection,
    required this.maxStages,
    required this.preferSameWidth,
    required this.minimizeCuts,
    required this.minimizeWaste,
  });
}
