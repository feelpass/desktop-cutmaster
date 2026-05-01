import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/plan_summary.dart';
import '../../l10n/app_localizations.dart';
import '../providers/preset_provider.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/pdf_export.dart';
import '../utils/png_export.dart';

/// 결과 다이얼로그 좌측 통계 패널.
/// KPI 5개 + 자재 목록 + 부품 그룹 + 하단 PNG/PDF 내보내기.
class ResultSummaryPanel extends ConsumerWidget {
  const ResultSummaryPanel({super.key, required this.plan});

  final CuttingPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    final presets = ref.watch(presetsProvider);
    final project = ref.watch(activeProjectProvider);

    final summary = PlanSummary.fromPlan(
      plan,
      colorName: (id) => presets.colorById(id)?.name,
    );

    final showLabels = project?.showPartLabels ?? true;
    final cutsLabel = summary.cutsAreEstimated
        ? '≈ ${summary.totalCuts}'
        : '${summary.totalCuts}';

    return Container(
      width: 300,
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI 블록
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${plan.efficiencyPercent.toStringAsFixed(1)}%',
                      style: AppTextStyles.efficiencyNumber,
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        t.summaryEfficiency,
                        style: AppTextStyles.body
                            .copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _kpiRow(
                  c,
                  label: t.summarySheetsLabel,
                  value: t.summarySheetUnit(summary.totalSheets),
                ),
                _kpiRow(
                  c,
                  label: t.summaryPartsLabel,
                  value: t.partsCount(summary.totalPlacedParts),
                ),
                _kpiRow(
                  c,
                  label: t.summaryCutsLabel,
                  value: cutsLabel,
                  tooltip: summary.cutsAreEstimated
                      ? t.summaryCutsEstimatedTooltip
                      : null,
                ),
                _kpiRow(
                  c,
                  label: t.summaryAreaLabel,
                  value: t.summaryAreaM2(_areaM2(summary.totalUsedAreaMm2)),
                ),
                if (plan.unplaced.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _kpiRow(
                      c,
                      label: t.summaryUnplacedLabel,
                      value: '${plan.unplaced.length}',
                      valueColor: AppColors.warning,
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),

          // 재료 목록 + 부품 그룹 (스크롤) — 엑셀 테이블 스타일
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (summary.materialUsages.isNotEmpty) ...[
                  _sectionHeader(
                    c,
                    t.summaryMaterials(summary.materialUsages.length),
                  ),
                  _materialTable(c, summary.materialUsages),
                  const SizedBox(height: 16),
                ],
                if (summary.partGroups.isNotEmpty) ...[
                  _sectionHeader(
                    c,
                    t.summaryPartGroups(summary.partGroups.length),
                  ),
                  _partTable(c, summary.partGroups),
                ],
              ],
            ),
          ),

          // 하단 Export 버튼
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: plan.sheets.isEmpty
                        ? null
                        : () => exportSheetsToPng(
                              context,
                              plan,
                              ref
                                  .read(tabsProvider)
                                  .active!
                                  .project
                                  .derivedStocks(),
                              showLabels,
                              colorLookup: (id) => id == null
                                  ? null
                                  : presets.colorById(id)?.argb,
                            ),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(t.exportPng),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: plan.sheets.isEmpty
                        ? null
                        : () => exportSheetsToPdf(
                              context,
                              plan,
                              ref
                                  .read(tabsProvider)
                                  .active!
                                  .project
                                  .derivedStocks(),
                              showLabels,
                              colorLookup: (id) => id == null
                                  ? null
                                  : presets.colorById(id)?.argb,
                            ),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: Text(t.exportPdf),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(
    AppPalette c, {
    required String label,
    required String value,
    String? tooltip,
    Color? valueColor,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: c.textSecondary),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: valueColor ?? c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return row;
    return Tooltip(message: tooltip, child: row);
  }

  Widget _sectionHeader(AppPalette c, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: AppTextStyles.sectionHeader.copyWith(color: c.textSecondary),
      ),
    );
  }

  // 자재 표 — 자재명 (Expanded) | 매수 (40px) | 면적 m² (64px)
  Widget _materialTable(AppPalette c, List<MaterialUsage> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: c.background,
      ),
      child: Column(
        children: [
          _tableHeaderRow(c, const [
            _Col(label: '자재', flex: true),
            _Col(label: '매수', width: 40, align: TextAlign.right),
            _Col(label: 'm²', width: 56, align: TextAlign.right),
          ]),
          for (var i = 0; i < items.length; i++)
            _tableBodyRow(
              c,
              isLast: i == items.length - 1,
              cells: [
                _Cell(text: items[i].name),
                _Cell(
                  text: '${items[i].sheetCount}',
                  width: 40,
                  align: TextAlign.right,
                ),
                _Cell(
                  text: _areaM2(items[i].usedAreaMm2),
                  width: 56,
                  align: TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 부품 표 — 부품 (Expanded) | 자재 (72px) | 사이즈 (76px) | 수량 (36px)
  Widget _partTable(AppPalette c, List<PartGroup> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: c.background,
      ),
      child: Column(
        children: [
          _tableHeaderRow(c, const [
            _Col(label: '부품', flex: true),
            _Col(label: '자재', width: 64),
            _Col(label: '사이즈', width: 76, align: TextAlign.right),
            _Col(label: '수량', width: 36, align: TextAlign.right),
          ]),
          for (var i = 0; i < items.length; i++)
            _tableBodyRow(
              c,
              isLast: i == items.length - 1,
              cells: [
                _Cell(text: items[i].label.isEmpty ? '—' : items[i].label),
                _Cell(text: items[i].materialName, width: 64, muted: true),
                _Cell(
                  text:
                      '${items[i].length.toStringAsFixed(0)}×${items[i].width.toStringAsFixed(0)}',
                  width: 76,
                  align: TextAlign.right,
                ),
                _Cell(
                  text: '${items[i].qty}',
                  width: 36,
                  align: TextAlign.right,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeaderRow(AppPalette c, List<_Col> cols) {
    return Container(
      decoration: BoxDecoration(
        color: c.sectionHeaderBg,
        border: Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final col in cols)
            col.flex
                ? Expanded(
                    child: Text(col.label,
                        style: AppTextStyles.tableHeader
                            .copyWith(color: c.tableHeaderText),
                        textAlign: col.align),
                  )
                : SizedBox(
                    width: col.width,
                    child: Text(col.label,
                        style: AppTextStyles.tableHeader
                            .copyWith(color: c.tableHeaderText),
                        textAlign: col.align),
                  ),
        ],
      ),
    );
  }

  Widget _tableBodyRow(
    AppPalette c, {
    required List<_Cell> cells,
    required bool isLast,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: c.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final cell in cells)
            cell.width == null
                ? Expanded(child: _cellText(c, cell))
                : SizedBox(width: cell.width, child: _cellText(c, cell)),
        ],
      ),
    );
  }

  Widget _cellText(AppPalette c, _Cell cell) {
    return Text(
      cell.text,
      style: AppTextStyles.tableCell.copyWith(
        color: cell.muted ? c.textMuted : c.textPrimary,
      ),
      textAlign: cell.align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static String _areaM2(double mm2) => (mm2 / 1000000).toStringAsFixed(2);
}

class _Col {
  final String label;
  final double width;
  final bool flex;
  final TextAlign align;
  const _Col({
    required this.label,
    this.width = 0,
    this.flex = false,
    this.align = TextAlign.left,
  });
}

class _Cell {
  final String text;
  final double? width;
  final TextAlign align;
  final bool muted;
  const _Cell({
    required this.text,
    this.width,
    this.align = TextAlign.left,
    this.muted = false,
  });
}
