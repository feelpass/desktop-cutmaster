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
        // header — 가로 / 세로 / 수량 (모두 가운데 정렬)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              if (hasReorder) const SizedBox(width: 24),
              if (hasLeading) const SizedBox(width: 28),
              Expanded(
                  flex: 2,
                  child: Text(t.length,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              const SizedBox(width: 4),
              const SizedBox(width: 12), // × 기호 자리
              const SizedBox(width: 4),
              Expanded(
                  flex: 2,
                  child: Text(t.width,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              const SizedBox(width: 6),
              SizedBox(
                  width: 80,
                  child: Text(t.qty,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.tableHeader)),
              const SizedBox(width: 4),
              const SizedBox(width: 28), // 회전 버튼 자리
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

  const EditableRow({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    required this.label,
    this.colorPresetId,
    this.grainDirection = GrainDirection.none,
  });

  EditableRow copyWith({
    double? length,
    double? width,
    int? qty,
    String? label,
    String? colorPresetId,
    GrainDirection? grainDirection,
  }) =>
      EditableRow(
        id: id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        colorPresetId: colorPresetId ?? this.colorPresetId,
        grainDirection: grainDirection ?? this.grainDirection,
      );
}

class _RowField extends StatefulWidget {
  const _RowField({
    super.key,
    required this.row,
    required this.onChanged,
    required this.onDelete,
    required this.deleteTooltip,
    this.leading,
    this.reorderIndex,
  });

  final EditableRow row;
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

  @override
  void initState() {
    super.initState();
    _lenCtrl = TextEditingController(
        text: widget.row.length == 0 ? '' : widget.row.length.toStringAsFixed(0));
    _widCtrl = TextEditingController(
        text: widget.row.width == 0 ? '' : widget.row.width.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _lenCtrl.dispose();
    _widCtrl.dispose();
    super.dispose();
  }

  void _commitDims() {
    final next = widget.row.copyWith(
      length: double.tryParse(_lenCtrl.text) ?? 0,
      width: double.tryParse(_widCtrl.text) ?? 0,
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1줄: 편집 가능
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.reorderIndex != null) ...[
                SizedBox(
                  width: 24,
                  child: ReorderableDragStartListener(
                    index: widget.reorderIndex!,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Icon(
                        Icons.drag_indicator,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.leading != null) ...[
                SizedBox(width: 24, child: widget.leading),
                const SizedBox(width: 4),
              ],
              Expanded(flex: 2, child: _cell(_lenCtrl, true)),
              const SizedBox(width: 4),
              const SizedBox(
                width: 12,
                child: Center(
                  child: Text('×',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(flex: 2, child: _cell(_widCtrl, true)),
              const SizedBox(width: 6),
              QtyStepper(
                value: widget.row.qty,
                onChanged: (n) =>
                    widget.onChanged(widget.row.copyWith(qty: n)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.rotate_90_degrees_cw, size: 18),
                tooltip: '가로/세로 바꾸기',
                onPressed: () {
                  final r = widget.row;
                  final swapped = r.copyWith(length: r.width, width: r.length);
                  // 컨트롤러도 즉시 갱신해 화면에 새 값이 보이도록
                  _lenCtrl.text = swapped.length == 0
                      ? ''
                      : swapped.length.toStringAsFixed(0);
                  _widCtrl.text = swapped.width == 0
                      ? ''
                      : swapped.width.toStringAsFixed(0);
                  widget.onChanged(swapped);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                color: AppColors.textSecondary,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: widget.deleteTooltip,
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        // 메타 줄 (라벨은 read-only — 편집은 프리셋에서만)
        _MetaLine(
          colorPresetId: widget.row.colorPresetId,
          grainDirection: widget.row.grainDirection,
          label: widget.row.label,
          hasLeading: widget.leading != null,
          hasReorderHandle: widget.reorderIndex != null,
        ),
      ],
    );
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
        // 매 입력마다 commit (provider의 debounced auto-save가 무거운 작업 흡수)
        onChanged: (_) => _commitDims(),
        onEditingComplete: _commitDims,
        onSubmitted: (_) => _commitDims(),
      ),
    );
  }
}

/// 행의 메타 줄 — 색상 이름, 결방향, 라벨 (읽기 전용).
/// 라벨은 프리셋에서만 편집할 수 있고 행에서는 표시만 한다.
class _MetaLine extends ConsumerWidget {
  const _MetaLine({
    required this.colorPresetId,
    required this.grainDirection,
    required this.label,
    required this.hasLeading,
    required this.hasReorderHandle,
  });
  final String? colorPresetId;
  final GrainDirection grainDirection;
  final String label;
  final bool hasLeading;
  final bool hasReorderHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = colorPresetId == null
        ? null
        : ref.watch(presetsProvider).colorById(colorPresetId);

    final colorText = preset?.name ?? '자동';
    final colorStyle = preset != null
        ? const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          )
        : const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          );

    final grainIcon = switch (grainDirection) {
      GrainDirection.lengthwise =>
        const Icon(Icons.swap_horiz, size: 14, color: AppColors.textSecondary),
      GrainDirection.widthwise =>
        const Icon(Icons.swap_vert, size: 14, color: AppColors.textSecondary),
      GrainDirection.none => null,
    };

    // 1줄과 동일한 prefix 폭으로 들여쓰기를 맞춰 length 컬럼 시작점에 정렬한다.
    //   drag handle: 24, leading swatch: 28(24 + 4 gap)
    final reorderPad = hasReorderHandle ? 24.0 : 0.0;
    final leadingPad = hasLeading ? 32.0 : 0.0;
    final leftPad = reorderPad + leadingPad;

    return Padding(
      padding: EdgeInsets.only(left: leftPad, top: 1, bottom: 4),
      child: Row(
        children: [
          Text(colorText, style: colorStyle),
          const SizedBox(width: 6),
          const Text('·',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.isEmpty ? '—' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: label.isEmpty
                    ? FontWeight.normal
                    : FontWeight.w500,
                color: label.isEmpty
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontStyle:
                    label.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (grainIcon != null) ...[
            const SizedBox(width: 4),
            grainIcon,
          ],
        ],
      ),
    );
  }
}
