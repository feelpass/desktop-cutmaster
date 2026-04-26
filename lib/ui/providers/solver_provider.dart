import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/solver/solver_isolate.dart';
import 'tabs_provider.dart';

/// 마지막 계산 결과. null = 아직 계산 안 함 (EmptyResultPane 표시).
final cuttingPlanProvider = StateProvider<CuttingPlan?>((ref) => null);

/// 솔버 실행 중 여부 (UI loading 표시용).
final isCalculatingProvider = StateProvider<bool>((ref) => false);

/// 자동 추천 모드에서 winner/runner-up 토글. 기본 false (winner 표시).
/// 새 계산이 끝나면 [runCalculate]가 false로 리셋한다.
final showRunnerUpProvider = StateProvider<bool>((ref) => false);

/// 표시 대상 plan (winner 또는 runner-up). null이면 아직 계산 안 됨.
/// canvas / 결과 위젯이 [cuttingPlanProvider] 대신 이걸 watch 한다.
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
Future<void> runCalculate(WidgetRef ref) async {
  final project = ref.read(activeProjectProvider);
  if (project == null) return;
  ref.read(isCalculatingProvider.notifier).state = true;
  try {
    final plan = await solveInIsolate(
      stocks: project.stocks,
      parts: project.parts,
      kerf: project.kerf,
      grainLocked: project.grainLocked,
      solverMode: project.solverMode,
      stripDirection: project.stripDirection,
      maxStages: project.maxStages,
      preferSameWidth: project.preferSameWidth,
      minimizeCuts: project.minimizeCuts,
      minimizeWaste: project.minimizeWaste,
    );
    ref.read(cuttingPlanProvider.notifier).state = plan;
    // 새 계산 결과로 갱신될 때 chip 토글을 winner로 리셋.
    ref.read(showRunnerUpProvider.notifier).state = false;
  } finally {
    ref.read(isCalculatingProvider.notifier).state = false;
  }
}
