import 'package:flutter/foundation.dart';

import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/stock_sheet.dart';
import 'ffd_solver.dart';

/// Isolate에서 솔버 실행. UI 쓰레드 freeze 방지.
/// Flutter의 compute()로 background isolate에 작업 위임.
Future<CuttingPlan> solveInIsolate({
  required List<StockSheet> stocks,
  required List<CutPart> parts,
  required double kerf,
  required bool grainLocked,
}) {
  return compute(
    _solveSync,
    _SolverInput(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
    ),
  );
}

CuttingPlan _solveSync(_SolverInput input) {
  return FFDSolver().solve(
    stocks: input.stocks,
    parts: input.parts,
    kerf: input.kerf,
    grainLocked: input.grainLocked,
  );
}

class _SolverInput {
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf;
  final bool grainLocked;

  const _SolverInput({
    required this.stocks,
    required this.parts,
    required this.kerf,
    required this.grainLocked,
  });
}
