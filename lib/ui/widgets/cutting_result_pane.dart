import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/project.dart';
import '../../domain/models/solver_mode.dart';
import '../providers/solver_provider.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'cutting_canvas.dart';

/// 결과 다이얼로그 우측 — 시트별 도면 리스트.
/// 효율·시트수·부품수·자재 통계는 좌측 ResultSummaryPanel이 담당.
class CuttingResultPane extends ConsumerWidget {
  const CuttingResultPane({super.key, required this.plan});

  final CuttingPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final project = ref.watch(activeProjectProvider);
    if (project == null) return const SizedBox.shrink();
    final showLabels = project.showPartLabels;

    // Auto-recommend chip row 데이터: 원본 winner plan은 cuttingPlanProvider에 있다.
    // (displayedPlanProvider가 runner-up을 반환할 때 그 runner-up의 runnerUp은 null이므로
    //  여기서 chip 표시 여부는 항상 winner(=cuttingPlanProvider) 기준으로 판단해야 함.)
    final basePlan = ref.watch(cuttingPlanProvider);
    final showRunner = ref.watch(showRunnerUpProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (basePlan != null && basePlan.runnerUp != null) ...[
            _AutoRecommendChips(
              winner: basePlan,
              runnerUp: basePlan.runnerUp!,
              runnerUpDirection: basePlan.runnerUpDirection!,
              showRunner: showRunner,
              onSelectWinner: () =>
                  ref.read(showRunnerUpProvider.notifier).state = false,
              onSelectRunnerUp: () =>
                  ref.read(showRunnerUpProvider.notifier).state = true,
            ),
            const SizedBox(height: 12),
          ],
          _buildWarnings(project, plan),
          Expanded(
            child: Builder(builder: (_) {
              final stocks = project.derivedStocks();
              final maxLen = plan.sheets.fold<double>(
                0,
                (acc, s) => s.sheetLength > acc ? s.sheetLength : acc,
              );
              return ListView.separated(
                itemCount: plan.sheets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 24),
                itemBuilder: (_, i) {
                  final s = plan.sheets[i];
                  final stock = stocks
                      .where((st) => st.id == s.stockSheetId)
                      .toList();
                  final leftover = s.largestLeftover;
                  final leftoverText = leftover == null || leftover.area < 1000
                      ? null
                      : '큰 자투리 ${leftover.width.toStringAsFixed(0)}×${leftover.height.toStringAsFixed(0)}';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시트 ${i + 1}  •  ${s.sheetLength.toStringAsFixed(0)} × ${s.sheetWidth.toStringAsFixed(0)} mm  •  ${s.usedPercent.toStringAsFixed(1)}%${stock.isNotEmpty && stock.first.label.isNotEmpty ? "  •  ${stock.first.label}" : ""}${leftoverText != null ? "  •  $leftoverText" : ""}',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CuttingCanvas(
                        sheet: s,
                        stock: stock.isNotEmpty ? stock.first : null,
                        showLabels: showLabels,
                        maxSheetLength: maxLen,
                        headcutTop: project.headcutTop,
                        headcutBottom: project.headcutBottom,
                        headcutLeft: project.headcutLeft,
                        headcutRight: project.headcutRight,
                      ),
                    ],
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  /// strip-cut 모드 전용 edge case 경고 배너.
  /// (1) 우선순위 토글 3개 모두 OFF — solver가 비결정적이 되므로 사용자가
  ///     최소 한 개를 켜야 의미 있는 결과가 나온다.
  /// (2) unplaced > 0 + maxStages < 4 — 단계를 늘리거나 동일 폭 우선을
  ///     끄면 더 많이 배치될 수 있다는 hint.
  Widget _buildWarnings(Project p, CuttingPlan plan) {
    if (p.solverMode != SolverMode.stripCut) return const SizedBox.shrink();

    final warnings = <Widget>[];

    if (!p.preferSameWidth && !p.minimizeCuts && !p.minimizeWaste) {
      warnings.add(_warningBanner(
        icon: Icons.info_outline,
        message: '최소 한 개 우선순위를 선택하세요',
        color: Colors.orange,
      ));
    }

    if (plan.unplaced.isNotEmpty && p.maxStages < 4) {
      warnings.add(_warningBanner(
        icon: Icons.lightbulb_outline,
        message: '최대 절단 단계를 늘리거나 동일 폭 우선을 끄면 더 많이 배치됩니다',
        color: Colors.blue,
      ));
    }

    if (warnings.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: warnings,
      ),
    );
  }

  Widget _warningBanner({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Auto-recommend 모드에서 winner / runner-up 비교 chip row.
/// runner-up chip을 클릭하면 [showRunnerUpProvider]가 true가 되어 canvas가
/// runner-up plan을 그린다. 새 계산이 실행되면 자동으로 winner로 리셋.
class _AutoRecommendChips extends StatelessWidget {
  const _AutoRecommendChips({
    required this.winner,
    required this.runnerUp,
    required this.runnerUpDirection,
    required this.showRunner,
    required this.onSelectWinner,
    required this.onSelectRunnerUp,
  });

  final CuttingPlan winner;
  final CuttingPlan runnerUp;
  final StripDirection runnerUpDirection;
  final bool showRunner;
  final VoidCallback onSelectWinner;
  final VoidCallback onSelectRunnerUp;

  @override
  Widget build(BuildContext context) {
    // runnerUpDirection은 진 쪽 방향. winner는 그 반대.
    final winnerDirection =
        runnerUpDirection == StripDirection.verticalFirst
            ? StripDirection.horizontalFirst
            : StripDirection.verticalFirst;
    final winnerLabel = _directionLabel(winnerDirection);
    final runnerUpLabel = _directionLabel(runnerUpDirection);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: Text(
            '$winnerLabel  ·  ${winner.efficiencyPercent.toStringAsFixed(1)}%  ·  ${_countCuts(winner)} cuts',
          ),
          avatar: const Icon(Icons.check_circle, size: 18),
          selected: !showRunner,
          onSelected: (_) => onSelectWinner(),
        ),
        ChoiceChip(
          label: Text(
            '$runnerUpLabel  ·  ${runnerUp.efficiencyPercent.toStringAsFixed(1)}%  ·  ${_countCuts(runnerUp)} cuts',
          ),
          selected: showRunner,
          onSelected: (_) => onSelectRunnerUp(),
        ),
      ],
    );
  }

  static String _directionLabel(StripDirection d) {
    switch (d) {
      case StripDirection.verticalFirst:
        return '세로 풀컷';
      case StripDirection.horizontalFirst:
        return '가로 풀컷';
      case StripDirection.auto:
        return '자동';
    }
  }

  /// strip-cut/FFD 공통: 시트마다 estimateGuillotineCuts를 호출해 합산.
  /// strip-cut에는 정확값, FFD에는 부품 경계 추정값.
  static int _countCuts(CuttingPlan p) {
    var n = 0;
    for (final s in p.sheets) {
      n += estimateGuillotineCuts(s);
    }
    return n;
  }
}
