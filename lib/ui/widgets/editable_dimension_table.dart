import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../../l10n/app_localizations.dart';
import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'qty_stepper.dart';

/// 부품/자재 공통 inline editable table.
///
/// 각 행은 두 줄로 구성된다:
///  - 1줄(편집 가능): [drag?] [swatch] [length] × [width] [QtyStepper] [✕]
///  - 메타 줄: [색상 이름] · [결방향 아이콘] · [라벨 (인라인 편집)]
///
/// [onReorder] 가 제공되면 행 앞에 drag handle 이 노출되고,
/// `ReorderableListView` 로 렌더링되어 사용자가 행을 끌어 순서를 바꿀 수 있다.
/// `onReorder` 가 null 이면 기존처럼 `Column[...rows]` 로 그려져 동작이 동일하다.
class EditableDimensionTable extends StatelessWidget {
  const EditableDimensionTable({
    super.key,
    required this.rows,
    required this.onChanged,
    required this.newId,
    this.addRowTooltip = '',
    this.deleteRowTooltip = '',
    this.leadingBuilder,
    this.onReorder,
  });

  final List<EditableRow> rows;
  final ValueChanged<List<EditableRow>> onChanged;
  final String Function() newId;
  final String addRowTooltip;
  final String deleteRowTooltip;

  /// 행 앞쪽에 표시할 선택적 위젯 (예: 부품 색상 swatch).
  /// null이면 leading 영역이 아예 없음 (stocks 같은 경우).
  final Widget Function(BuildContext context, int index)? leadingBuilder;

  /// 사용자가 행을 끌어 순서를 변경했을 때 호출. null 이면 reorder 비활성화.
  final ValueChanged<List<EditableRow>>? onReorder;

  bool get _reorderEnabled => onReorder != null;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasLeading = leadingBuilder != null;
    final hasReorder = _reorderEnabled;

    Widget buildRow(int i) {
      final r = rows[i];
      return _RowField(
        key: ValueKey(r.id),
        row: r,
        rowNumber: i + 1,
        onChanged: (updated) {
          final next = [...rows];
          next[i] = updated;
          onChanged(next);
        },
        onDelete: () {
          final next = [...rows]..removeAt(i);
          onChanged(next);
        },
        deleteTooltip: deleteRowTooltip,
        leading: hasLeading ? leadingBuilder!(context, i) : null,
        reorderIndex: hasReorder ? i : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header — 넘버 / 부품명 / 가로(mm) / 세로(mm) / 두께(mm) / 자재 / 수량 / 메모
        // SpaceBetween: 부모 폭이 합계보다 클 때 칼럼 사이 간격이 균등하게 분배.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (hasReorder) const SizedBox(width: 24),
              const SizedBox(
                width: 28,
                child: Text('#',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.tableHeader),
              ),
              if (hasLeading) const SizedBox(width: 30),
              const SizedBox(
                width: 220,
                child: Text('부품명', style: AppTextStyles.tableHeader),
              ),
              SizedBox(
                  width: 60,
                  child: Text('가로(mm)',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              SizedBox(
                  width: 60,
                  child: Text('세로(mm)',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              SizedBox(
                  width: 60,
                  child: Text('두께(mm)',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              SizedBox(
                  width: 96,
                  child: Text('자재',
                      textAlign: TextAlign.left,
                      style: AppTextStyles.tableHeader)),
              SizedBox(
                  width: 80,
                  child: Text(t.qty,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              const SizedBox(
                width: 260,
                child: Text('메모', style: AppTextStyles.tableHeader),
              ),
              const SizedBox(width: 28), // 삭제 버튼 자리
            ],
          ),
        ),
        // rows
        if (hasReorder)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            itemBuilder: (ctx, i) => buildRow(i),
            onReorder: (oldIndex, newIndex) {
              var newIdx = newIndex;
              if (newIdx > oldIndex) newIdx--;
              final next = [...rows];
              final item = next.removeAt(oldIndex);
              next.insert(newIdx, item);
              onReorder!(next);
            },
          )
        else
          ...List.generate(rows.length, buildRow),
      ],
    );
  }
}

class EditableRow {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final String? colorPresetId;
  final GrainDirection grainDirection;

  /// 부품 행에서만 의미 있음 — 자재(stocks)에는 두께 개념이 없어서 null.
  /// 자재 자동 도출은 (color, thickness) 키로 그룹핑된다.
  final double? thickness;

  /// CSV 임포트 시 채워지는 부가 정보 — 행 메타 줄에 보조 표시용.
  final String fileName;
  final List<String> edges;

  /// 사용자 메모 — 행 우측 칼럼에 직접 편집.
  final String memo;

  const EditableRow({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    required this.label,
    this.colorPresetId,
    this.grainDirection = GrainDirection.none,
    this.thickness,
    this.fileName = '',
    this.edges = const ['', '', '', ''],
    this.memo = '',
  });

  EditableRow copyWith({
    double? length,
    double? width,
    int? qty,
    String? label,
    String? colorPresetId,
    GrainDirection? grainDirection,
    double? thickness,
    String? fileName,
    List<String>? edges,
    String? memo,
  }) =>
      EditableRow(
        id: id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        colorPresetId: colorPresetId ?? this.colorPresetId,
        grainDirection: grainDirection ?? this.grainDirection,
        thickness: thickness ?? this.thickness,
        fileName: fileName ?? this.fileName,
        edges: edges ?? this.edges,
        memo: memo ?? this.memo,
      );
}

class _RowField extends StatefulWidget {
  const _RowField({
    super.key,
    required this.row,
    required this.rowNumber,
    required this.onChanged,
    required this.onDelete,
    required this.deleteTooltip,
    this.leading,
    this.reorderIndex,
  });

  final EditableRow row;
  final int rowNumber;
  final ValueChanged<EditableRow> onChanged;
  final VoidCallback onDelete;
  final String deleteTooltip;
  final Widget? leading;

  /// `ReorderableListView` 안에서 이 행의 인덱스. null 이면 drag handle 미노출.
  final int? reorderIndex;

  @override
  State<_RowField> createState() => _RowFieldState();
}

class _RowFieldState extends State<_RowField> {
  late final TextEditingController _lenCtrl;
  late final TextEditingController _widCtrl;
  late final TextEditingController _thickCtrl;
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    _lenCtrl = TextEditingController(
        text: widget.row.length == 0 ? '' : widget.row.length.toStringAsFixed(0));
    _widCtrl = TextEditingController(
        text: widget.row.width == 0 ? '' : widget.row.width.toStringAsFixed(0));
    _thickCtrl = TextEditingController(text: _fmtT(widget.row.thickness));
    _memoCtrl = TextEditingController(text: widget.row.memo);
  }

  @override
  void dispose() {
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _thickCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  static String _fmtT(double? t) {
    if (t == null || t == 0) return '';
    return t == t.toInt() ? t.toInt().toString() : t.toStringAsFixed(1);
  }

  void _commitDims() {
    final next = widget.row.copyWith(
      length: double.tryParse(_lenCtrl.text) ?? 0,
      width: double.tryParse(_widCtrl.text) ?? 0,
      thickness: double.tryParse(_thickCtrl.text),
    );
    widget.onChanged(next);
  }

  void _commitMemo() {
    widget.onChanged(widget.row.copyWith(memo: _memoCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    final tooltipMsg = _buildTooltipMessage();
    final pal = context.colors;
    final mainRow = SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.reorderIndex != null)
              SizedBox(
                width: 24,
                child: ReorderableDragStartListener(
                  index: widget.reorderIndex!,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: pal.textSecondary,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 28,
              child: Text(
                '${widget.rowNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: pal.textSecondary,
                ),
              ),
            ),
            if (widget.leading != null)
              SizedBox(width: 24, child: widget.leading),
            SizedBox(
              width: 220,
              child: Text(
                widget.row.label.isEmpty ? '—' : widget.row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.row.label.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w500,
                  color: widget.row.label.isEmpty
                      ? pal.textSecondary
                      : pal.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 60, child: _cell(_lenCtrl, true)),
            SizedBox(width: 60, child: _cell(_widCtrl, true)),
            SizedBox(width: 60, child: _cell(_thickCtrl, true)),
            SizedBox(
              width: 96,
              child: _MaterialBadge(
                colorPresetId: widget.row.colorPresetId,
                thickness: widget.row.thickness,
              ),
            ),
            SizedBox(
              width: 80,
              child: QtyStepper(
                value: widget.row.qty,
                onChanged: (n) =>
                    widget.onChanged(widget.row.copyWith(qty: n)),
              ),
            ),
            SizedBox(width: 260, child: _memoCell()),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: widget.deleteTooltip,
              onPressed: widget.onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
              color: pal.textSecondary,
            ),
          ],
        ),
      ),
    );

    return tooltipMsg == null
        ? mainRow
        : Tooltip(message: tooltipMsg, child: mainRow);
  }

  /// CSV 임포트 정보(파일명, 엣지) 가 있으면 행에 hover tooltip으로 표시.
  String? _buildTooltipMessage() {
    final parts = <String>[];
    if (widget.row.fileName.isNotEmpty) {
      parts.add('도면: ${widget.row.fileName}');
    }
    final labels = ['상', '하', '좌', '우'];
    for (var i = 0; i < widget.row.edges.length && i < 4; i++) {
      if (widget.row.edges[i].isNotEmpty) {
        parts.add('${labels[i]} 엣지: ${widget.row.edges[i]}');
      }
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  Widget _cell(TextEditingController ctrl, bool numeric) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: numeric ? TextAlign.center : TextAlign.left,
        style: AppTextStyles.tableCell,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => _commitDims(),
        onEditingComplete: _commitDims,
        onSubmitted: (_) => _commitDims(),
      ),
    );
  }

  Widget _memoCell() {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _memoCtrl,
        style: AppTextStyles.tableCell,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          border: OutlineInputBorder(),
          hintText: '',
        ),
        onChanged: (_) => _commitMemo(),
        onEditingComplete: _commitMemo,
        onSubmitted: (_) => _commitMemo(),
      ),
    );
  }
}

/// 행 메인 줄에 표시되는 자재 배지 — `{색상}_{두께}T` 형식.
/// 자동 색상이면 "자동" 표시 + italic 회색.
class _MaterialBadge extends ConsumerWidget {
  const _MaterialBadge({
    required this.colorPresetId,
    required this.thickness,
  });

  final String? colorPresetId;
  final double? thickness;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = colorPresetId == null
        ? null
        : ref.watch(presetsProvider).colorById(colorPresetId);
    final baseName = preset?.name ?? '자동';
    final t = thickness;
    final text = t != null && t > 0
        ? '${baseName}_${t == t.toInt() ? t.toInt() : t.toStringAsFixed(1)}T'
        : baseName;
    final pal = context.colors;
    final style = preset != null
        ? TextStyle(
            fontSize: 12,
            color: pal.textPrimary,
            fontWeight: FontWeight.w500,
          )
        : TextStyle(
            fontSize: 12,
            color: pal.textSecondary,
            fontStyle: FontStyle.italic,
          );
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
