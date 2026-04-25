import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/solver/solver_isolate.dart';
import 'current_project_provider.dart';

/// 마지막 계산 결과. null = 아직 계산 안 함 (EmptyResultPane 표시).
final cuttingPlanProvider = StateProvider<CuttingPlan?>((ref) => null);

/// 솔버 실행 중 여부 (UI loading 표시용).
final isCalculatingProvider = StateProvider<bool>((ref) => false);

/// 솔버 실행 함수. ▶ 계산 버튼이 호출.
Future<void> runCalculate(WidgetRef ref) async {
  final project = ref.read(currentProjectProvider);
  ref.read(isCalculatingProvider.notifier).state = true;
  try {
    final plan = await solveInIsolate(
      stocks: project.stocks,
      parts: project.parts,
      kerf: project.kerf,
      grainLocked: project.grainLocked,
    );
    ref.read(cuttingPlanProvider.notifier).state = plan;
  } finally {
    ref.read(isCalculatingProvider.notifier).state = false;
  }
}
