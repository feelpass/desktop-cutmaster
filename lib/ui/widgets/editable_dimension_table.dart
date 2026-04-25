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
///  - 1줄(편집 가능): [swatch] [length] × [width] [QtyStepper] [✕]
///  - 메타 줄: [색상 이름] · [결방향 아이콘] · [라벨 (인라인 편집)]
class EditableDimensionTable extends StatelessWidget {
  const EditableDimensionTable({
    super.key,
    required this.rows,
    required this.onChanged,
    required this.newId,
    this.addRowTooltip = '',
    this.deleteRowTooltip = '',
    this.leadingBuilder,
  });

  final List<EditableRow> rows;
  final ValueChanged<List<EditableRow>> onChanged;
  final String Function() newId;
  final String addRowTooltip;
  final String deleteRowTooltip;

  /// 행 앞쪽에 표시할 선택적 위젯 (예: 부품 색상 swatch).
  /// null이면 leading 영역이 아예 없음 (stocks 같은 경우).
  final Widget Function(BuildContext context, int index)? leadingBuilder;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final hasLeading = leadingBuilder != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header — 길이 / 폭 / 수량 (label은 메타줄로 이동)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              if (hasLeading) const SizedBox(width: 28),
              Expanded(
                  flex: 2,
                  child: Text(t.length, style: AppTextStyles.tableHeader)),
              const SizedBox(width: 4),
              const SizedBox(width: 12), // × 기호 자리
              const SizedBox(width: 4),
              Expanded(
                  flex: 2,
                  child: Text(t.width, style: AppTextStyles.tableHeader)),
              const SizedBox(width: 6),
              SizedBox(
                  width: 80,
                  child: Text(t.qty, style: AppTextStyles.tableHeader)),
              const SizedBox(width: 4),
              const SizedBox(width: 28), // delete button 자리
            ],
          ),
        ),
        // rows
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
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
          );
        }),
        // add row
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            onPressed: () {
              final next = [
                ...rows,
                EditableRow(
                  id: newId(),
                  length: 0,
                  width: 0,
                  qty: 1,
                  label: '',
                  colorPresetId: null,
                  grainDirection: GrainDirection.none,
                ),
              ];
              onChanged(next);
            },
            icon: const Icon(Icons.add, size: 14),
            label: Text(addRowTooltip),
          ),
        ),
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
  });

  final EditableRow row;
  final ValueChanged<EditableRow> onChanged;
  final VoidCallback onDelete;
  final String deleteTooltip;
  final Widget? leading;

  @override
  State<_RowField> createState() => _RowFieldState();
}

class _RowFieldState extends State<_RowField> {
  late final TextEditingController _lenCtrl;
  late final TextEditingController _widCtrl;
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _lenCtrl = TextEditingController(
        text: widget.row.length == 0 ? '' : widget.row.length.toStringAsFixed(0));
    _widCtrl = TextEditingController(
        text: widget.row.width == 0 ? '' : widget.row.width.toStringAsFixed(0));
    _labelCtrl = TextEditingController(text: widget.row.label);
  }

  @override
  void dispose() {
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _labelCtrl.dispose();
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
              if (widget.leading != null) ...[
                SizedBox(width: 24, child: widget.leading),
                const SizedBox(width: 4),
              ],
              Expanded(flex: 2, child: _cell(_lenCtrl, true)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text('×',
                    style: TextStyle(color: AppColors.textSecondary)),
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
                icon: const Icon(Icons.close, size: 14),
                tooltip: widget.deleteTooltip,
                onPressed: widget.onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        // 메타 줄
        _MetaLine(
          colorPresetId: widget.row.colorPresetId,
          grainDirection: widget.row.grainDirection,
          labelCtrl: _labelCtrl,
          hasLeading: widget.leading != null,
          onLabelChanged: () =>
              widget.onChanged(widget.row.copyWith(label: _labelCtrl.text)),
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
        textAlign: numeric ? TextAlign.right : TextAlign.left,
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

/// 행의 메타 줄 — 색상 이름, 결방향, 라벨(인라인 편집).
class _MetaLine extends ConsumerStatefulWidget {
  const _MetaLine({
    required this.colorPresetId,
    required this.grainDirection,
    required this.labelCtrl,
    required this.hasLeading,
    required this.onLabelChanged,
  });
  final String? colorPresetId;
  final GrainDirection grainDirection;
  final TextEditingController labelCtrl;
  final bool hasLeading;
  final VoidCallback onLabelChanged;

  @override
  ConsumerState<_MetaLine> createState() => _MetaLineState();
}

class _MetaLineState extends ConsumerState<_MetaLine> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final preset = widget.colorPresetId == null
        ? null
        : ref.watch(presetsProvider).colorById(widget.colorPresetId);

    final colorText = preset?.name ?? '자동';
    final colorStyle = preset != null
        ? const TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          )
        : const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          );

    final grainIcon = switch (widget.grainDirection) {
      GrainDirection.lengthwise =>
        const Icon(Icons.swap_horiz, size: 12, color: AppColors.textSecondary),
      GrainDirection.widthwise =>
        const Icon(Icons.swap_vert, size: 12, color: AppColors.textSecondary),
      GrainDirection.none => null,
    };

    // leading swatch가 있는 경우 (parts) 들여쓰기로 정렬, 없으면(stocks) 0.
    final leftPad = widget.hasLeading ? 32.0 : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPad, top: 1, bottom: 4),
      child: Row(
        children: [
          Text(colorText, style: colorStyle),
          const SizedBox(width: 6),
          if (grainIcon != null) ...[
            grainIcon,
            const SizedBox(width: 4),
          ],
          const Text('·',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: _editing
                ? SizedBox(
                    height: 22,
                    child: TextField(
                      controller: widget.labelCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        widget.onLabelChanged();
                        if (mounted) setState(() => _editing = false);
                      },
                      onEditingComplete: () {
                        widget.onLabelChanged();
                        if (mounted) setState(() => _editing = false);
                      },
                    ),
                  )
                : InkWell(
                    onTap: () => setState(() => _editing = true),
                    child: Text(
                      widget.labelCtrl.text.isEmpty
                          ? '라벨 추가...'
                          : widget.labelCtrl.text,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.labelCtrl.text.isEmpty
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontStyle: widget.labelCtrl.text.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
