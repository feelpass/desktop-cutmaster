import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/png_export.dart';
import 'cutting_canvas.dart';

class CuttingResultPane extends ConsumerWidget {
  const CuttingResultPane({super.key, required this.plan});

  final CuttingPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final showLabels = ref.watch(currentProjectProvider).showPartLabels;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 효율 + 요약 + export
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${plan.efficiencyPercent.toStringAsFixed(1)}%',
                style: AppTextStyles.efficiencyNumber,
              ),
              const SizedBox(width: 8),
              Text(t.efficiency, style: AppTextStyles.body),
              const SizedBox(width: 24),
              Text(t.sheetUsed(plan.sheets.length),
                  style: AppTextStyles.body),
              const SizedBox(width: 12),
              Text(t.partsCount(_totalPlaced(plan)),
                  style: AppTextStyles.body),
              if (plan.unplaced.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  t.unplacedCount(plan.unplaced.length),
                  style: AppTextStyles.body
                      .copyWith(color: Colors.orange.shade800),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: plan.sheets.isEmpty
                    ? null
                    : () => exportSheetsToPng(
                          context,
                          plan,
                          ref.read(currentProjectProvider).stocks,
                          showLabels,
                        ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(t.exportPng),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          // 시트별 도면 stack
          Expanded(
            child: ListView.separated(
              itemCount: plan.sheets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 24),
              itemBuilder: (_, i) {
                final s = plan.sheets[i];
                final stock = ref
                    .read(currentProjectProvider)
                    .stocks
                    .where((st) => st.id == s.stockSheetId)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '시트 ${i + 1}  •  ${s.sheetLength.toStringAsFixed(0)} × ${s.sheetWidth.toStringAsFixed(0)} mm  •  ${s.usedPercent.toStringAsFixed(1)}%${stock.isNotEmpty && stock.first.label.isNotEmpty ? "  •  ${stock.first.label}" : ""}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CuttingCanvas(
                      sheet: s,
                      stock: stock.isNotEmpty ? stock.first : null,
                      showLabels: showLabels,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _totalPlaced(CuttingPlan plan) =>
      plan.sheets.fold<int>(0, (acc, s) => acc + s.placed.length);
}
