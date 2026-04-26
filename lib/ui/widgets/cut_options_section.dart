import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/solver_mode.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_text_styles.dart';

/// 좌측 패널의 "절단 옵션" 섹션.
///
/// Tasks 17, 18, 19 — 솔버 모드 (FFD/Strip-cut) 라디오, strip-cut 한정
/// 방향/단계 컨트롤, 우선순위 토글들을 한 곳에 모은 collapsible widget.
class CutOptionsSection extends ConsumerWidget {
  const CutOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(activeProjectProvider);
    final notifier = ref.read(tabsProvider);
    final activeId = notifier.activeId;
    if (p == null || activeId == null) return const SizedBox.shrink();

    final isStripCut = p.solverMode == SolverMode.stripCut;

    return ExpansionTile(
      title: const Text('절단 옵션', style: AppTextStyles.body),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        // === 솔버 모드 ===
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('솔버 모드', style: AppTextStyles.body),
          ),
        ),
        RadioListTile<SolverMode>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('FFD (자유 배치 — 최대 효율)',
              style: AppTextStyles.body),
          value: SolverMode.ffd,
          groupValue: p.solverMode,
          onChanged: (v) {
            if (v != null) notifier.updateSolverMode(activeId, v);
          },
        ),
        RadioListTile<SolverMode>(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Strip-cut (panel saw — 실제 작업 가능)',
              style: AppTextStyles.body),
          value: SolverMode.stripCut,
          groupValue: p.solverMode,
          onChanged: (v) {
            if (v != null) notifier.updateSolverMode(activeId, v);
          },
        ),

        // === Strip-cut 한정 옵션 ===
        if (isStripCut) ...[
          const Divider(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('절단 방식', style: AppTextStyles.body),
            ),
          ),
          RadioListTile<StripDirection>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('세로 풀컷 → 가로 분할',
                style: AppTextStyles.body),
            value: StripDirection.verticalFirst,
            groupValue: p.stripDirection,
            onChanged: (v) {
              if (v != null) notifier.updateStripDirection(activeId, v);
            },
          ),
          RadioListTile<StripDirection>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('가로 풀컷 → 세로 분할',
                style: AppTextStyles.body),
            value: StripDirection.horizontalFirst,
            groupValue: p.stripDirection,
            onChanged: (v) {
              if (v != null) notifier.updateStripDirection(activeId, v);
            },
          ),
          RadioListTile<StripDirection>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 추천', style: AppTextStyles.body),
            value: StripDirection.auto,
            groupValue: p.stripDirection,
            onChanged: (v) {
              if (v != null) notifier.updateStripDirection(activeId, v);
            },
          ),

          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('최대 절단 단계', style: AppTextStyles.body),
              ),
              DropdownButton<int>(
                value: p.maxStages,
                items: const [
                  DropdownMenuItem(value: 2, child: Text('2')),
                  DropdownMenuItem(value: 3, child: Text('3')),
                  DropdownMenuItem(value: 4, child: Text('4')),
                ],
                onChanged: (v) {
                  if (v != null) notifier.updateMaxStages(activeId, v);
                },
              ),
            ],
          ),

          // === 우선순위 토글들 ===
          const SizedBox(height: 4),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('동일 폭 우선', style: AppTextStyles.body),
            // maxStages == 2일 때는 동일 폭이 강제되므로 disabled.
            value: p.maxStages == 2 ? true : p.preferSameWidth,
            onChanged: p.maxStages == 2
                ? null
                : (v) =>
                    notifier.updatePreferSameWidth(activeId, v ?? true),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('절단 횟수 최소', style: AppTextStyles.body),
            value: p.minimizeCuts,
            onChanged: (v) =>
                notifier.updateMinimizeCuts(activeId, v ?? true),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('손실률 최소', style: AppTextStyles.body),
            value: p.minimizeWaste,
            onChanged: (v) =>
                notifier.updateMinimizeWaste(activeId, v ?? true),
          ),
        ],
      ],
    );
  }
}
