import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tabs_provider.dart';
import '../theme/app_text_styles.dart';

class OrderInfoSection extends ConsumerStatefulWidget {
  const OrderInfoSection({super.key});

  @override
  ConsumerState<OrderInfoSection> createState() => _OrderInfoSectionState();
}

class _OrderInfoSectionState extends ConsumerState<OrderInfoSection> {
  late final TextEditingController _orderCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _memoCtrl;
  String? _boundTabId;

  @override
  void initState() {
    super.initState();
    final p = ref.read(tabsProvider).active?.project;
    _orderCtrl = TextEditingController(text: p?.orderNumber ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _memoCtrl = TextEditingController(text: p?.memo ?? '');
    _boundTabId = ref.read(tabsProvider).activeId;
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _maybeRebindControllers() {
    final notifier = ref.read(tabsProvider);
    final id = notifier.activeId;
    if (id == _boundTabId) return;
    final p = notifier.active?.project;
    _orderCtrl.text = p?.orderNumber ?? '';
    _nameCtrl.text = p?.name ?? '';
    _memoCtrl.text = p?.memo ?? '';
    _boundTabId = id;
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(activeProjectProvider);
    final notifier = ref.read(tabsProvider);
    final activeId = notifier.activeId;
    if (p == null || activeId == null) return const SizedBox.shrink();
    _maybeRebindControllers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          label: '주문번호',
          required: true,
          controller: _orderCtrl,
          hint: 'ORD-2024-0508-001',
          onCommit: (v) => notifier.updateOrderNumber(activeId, v),
        ),
        _Field(
          label: '프로젝트명',
          required: true,
          controller: _nameCtrl,
          hint: '프로젝트명',
          onCommit: (v) => notifier.updateName(activeId, v),
        ),
        _DateField(
          label: '납기일',
          required: true,
          value: p.dueDate,
          onChanged: (v) => notifier.updateDueDate(activeId, v),
        ),
        _Field(
          label: '메모',
          controller: _memoCtrl,
          hint: '메모를 입력하세요.',
          maxLines: 3,
          onCommit: (v) => notifier.updateMemo(activeId, v),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onCommit,
    this.hint,
    this.required = false,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onCommit;
  final String? hint;
  final bool required;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelLine(label: label, required: required),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: AppTextStyles.tableCell,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: const OutlineInputBorder(),
            ),
            onChanged: onCommit,
            onEditingComplete: () => onCommit(controller.text),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelLine(label: label, required: required),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) onChanged(picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
                suffixIcon:
                    Icon(Icons.calendar_today_outlined, size: 16),
              ),
              child: Text(
                text.isEmpty ? '날짜 선택' : text,
                style: AppTextStyles.tableCell,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelLine extends StatelessWidget {
  const _LabelLine({required this.label, required this.required});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.body),
        if (required) ...[
          const SizedBox(width: 2),
          const Text('*', style: TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}
