import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 부품/자재 공통 inline editable table (가로/세로/수량/라벨).
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
        // header
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              if (hasLeading) const SizedBox(width: 28),
              Expanded(child: Text(t.length, style: AppTextStyles.tableHeader)),
              Expanded(child: Text(t.width, style: AppTextStyles.tableHeader)),
              SizedBox(
                  width: 50,
                  child: Text(t.qty, style: AppTextStyles.tableHeader)),
              Expanded(
                  flex: 2,
                  child: Text(t.label, style: AppTextStyles.tableHeader)),
              const SizedBox(width: 36),
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
                EditableRow(id: newId(), length: 0, width: 0, qty: 1, label: '')
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

  const EditableRow({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    required this.label,
  });

  EditableRow copyWith({double? length, double? width, int? qty, String? label}) =>
      EditableRow(
        id: id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
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
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _lenCtrl = TextEditingController(
        text: widget.row.length == 0 ? '' : widget.row.length.toStringAsFixed(0));
    _widCtrl = TextEditingController(
        text: widget.row.width == 0 ? '' : widget.row.width.toStringAsFixed(0));
    _qtyCtrl = TextEditingController(text: widget.row.qty.toString());
    _labelCtrl = TextEditingController(text: widget.row.label);
  }

  @override
  void dispose() {
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _qtyCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final next = widget.row.copyWith(
      length: double.tryParse(_lenCtrl.text) ?? 0,
      width: double.tryParse(_widCtrl.text) ?? 0,
      qty: int.tryParse(_qtyCtrl.text) ?? 1,
      label: _labelCtrl.text,
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.leading != null) ...[
            SizedBox(width: 24, child: widget.leading),
            const SizedBox(width: 4),
          ],
          Expanded(child: _cell(_lenCtrl, true)),
          const SizedBox(width: 4),
          Expanded(child: _cell(_widCtrl, true)),
          const SizedBox(width: 4),
          SizedBox(width: 50, child: _cell(_qtyCtrl, true)),
          const SizedBox(width: 4),
          Expanded(flex: 2, child: _cell(_labelCtrl, false)),
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
        onChanged: (_) => _commit(),
        onEditingComplete: _commit,
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}
