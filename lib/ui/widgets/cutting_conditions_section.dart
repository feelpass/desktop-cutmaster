import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'cut_options_section.dart';

/// 재단 조건 섹션 — 톱날 두께, 헤드컷(상/하/좌/우 십자 배치), 절단 옵션.
class CuttingConditionsSection extends ConsumerStatefulWidget {
  const CuttingConditionsSection({super.key});

  @override
  ConsumerState<CuttingConditionsSection> createState() =>
      _CuttingConditionsSectionState();
}

class _CuttingConditionsSectionState
    extends ConsumerState<CuttingConditionsSection> {
  late final TextEditingController _kerfCtrl;
  late final TextEditingController _topCtrl;
  late final TextEditingController _bottomCtrl;
  late final TextEditingController _leftCtrl;
  late final TextEditingController _rightCtrl;
  String? _boundTabId;

  @override
  void initState() {
    super.initState();
    final p = ref.read(tabsProvider).active?.project;
    _kerfCtrl =
        TextEditingController(text: p?.kerf.toStringAsFixed(1) ?? '3.0');
    _topCtrl = TextEditingController(text: _fmt(p?.headcutTop ?? 0));
    _bottomCtrl = TextEditingController(text: _fmt(p?.headcutBottom ?? 0));
    _leftCtrl = TextEditingController(text: _fmt(p?.headcutLeft ?? 0));
    _rightCtrl = TextEditingController(text: _fmt(p?.headcutRight ?? 0));
    _boundTabId = ref.read(tabsProvider).activeId;
  }

  @override
  void dispose() {
    _kerfCtrl.dispose();
    _topCtrl.dispose();
    _bottomCtrl.dispose();
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _maybeRebind() {
    final notifier = ref.read(tabsProvider);
    final id = notifier.activeId;
    if (id == _boundTabId) return;
    final p = notifier.active?.project;
    _kerfCtrl.text = p?.kerf.toStringAsFixed(1) ?? '3.0';
    _topCtrl.text = _fmt(p?.headcutTop ?? 0);
    _bottomCtrl.text = _fmt(p?.headcutBottom ?? 0);
    _leftCtrl.text = _fmt(p?.headcutLeft ?? 0);
    _rightCtrl.text = _fmt(p?.headcutRight ?? 0);
    _boundTabId = id;
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(activeProjectProvider);
    final notifier = ref.read(tabsProvider);
    final activeId = notifier.activeId;
    if (p == null || activeId == null) return const SizedBox.shrink();
    _maybeRebind();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 톱날 두께
        Row(
          children: [
            const SizedBox(
              width: 80,
              child: Text('톱날 두께', style: AppTextStyles.body),
            ),
            _NumberStepper(
              controller: _kerfCtrl,
              width: 96,
              step: 0.5,
              min: 0,
              max: 20,
              onCommit: (v) => notifier.updateKerf(activeId, v),
            ),
            const SizedBox(width: 6),
            Text('mm',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),

        // 헤드컷 — 상/하/좌/우 4행 표 (외곽 보더 + 행 구분선).
        const Text('헤드컷 (상/하/좌/우)', style: AppTextStyles.body),
        const SizedBox(height: 6),
        _HeadcutTable(
          top: _topCtrl,
          bottom: _bottomCtrl,
          left: _leftCtrl,
          right: _rightCtrl,
          onTop: (v) => notifier.updateHeadcut(activeId, top: v),
          onBottom: (v) => notifier.updateHeadcut(activeId, bottom: v),
          onLeft: (v) => notifier.updateHeadcut(activeId, left: v),
          onRight: (v) => notifier.updateHeadcut(activeId, right: v),
        ),

        const SizedBox(height: 12),
        const CutOptionsSection(),
      ],
    );
  }
}

/// 헤드컷 4행 표 — 행마다 [방향 라벨 | - 입력 + | mm].
/// 외곽 1px 보더 + 8px radius, 행 사이 1px 보더 (DESIGN.md §5).
class _HeadcutTable extends StatelessWidget {
  const _HeadcutTable({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
    required this.onTop,
    required this.onBottom,
    required this.onLeft,
    required this.onRight,
  });

  final TextEditingController top;
  final TextEditingController bottom;
  final TextEditingController left;
  final TextEditingController right;
  final ValueChanged<double> onTop;
  final ValueChanged<double> onBottom;
  final ValueChanged<double> onLeft;
  final ValueChanged<double> onRight;

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: pal.background,
          border: Border.all(color: pal.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeadcutRow(
                label: '↑ 상', controller: top, onCommit: onTop),
            _HeadcutRow(
                label: '↓ 하', controller: bottom, onCommit: onBottom),
            _HeadcutRow(
                label: '← 좌', controller: left, onCommit: onLeft),
            _HeadcutRow(
                label: '→ 우',
                controller: right,
                onCommit: onRight,
                isLast: true),
          ],
        ),
      ),
    );
  }
}

class _HeadcutRow extends StatelessWidget {
  const _HeadcutRow({
    required this.label,
    required this.controller,
    required this.onCommit,
    this.isLast = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<double> onCommit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: pal.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: pal.textPrimary),
            ),
          ),
          _NumberStepper(
            controller: controller,
            width: 110,
            step: 1,
            min: 0,
            max: 200,
            onCommit: onCommit,
          ),
          const SizedBox(width: 6),
          Text(
            'mm',
            style: TextStyle(fontSize: 12, color: pal.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// [-] [숫자 입력] [+] 컴팩트 스테퍼. 텍스트 직접 입력도 가능.
class _NumberStepper extends StatefulWidget {
  const _NumberStepper({
    required this.controller,
    required this.width,
    required this.onCommit,
    this.step = 1,
    this.min = 0,
    this.max = 1000,
  });

  final TextEditingController controller;
  final double width;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onCommit;

  @override
  State<_NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<_NumberStepper> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // 포커스를 잃을 때(다른 위젯 클릭/unfocus 포함) 현재 값을 커밋.
    // Enter/Tab 없이 바로 "최적화 실행"을 눌러도 입력 값이 반영되도록 함.
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      widget.onCommit(double.tryParse(widget.controller.text) ?? 0);
    }
  }

  void _bump(double delta) {
    final cur = double.tryParse(widget.controller.text) ?? 0;
    var next = cur + delta;
    if (next < widget.min) next = widget.min;
    if (next > widget.max) next = widget.max;
    final str = next == next.toInt()
        ? next.toInt().toString()
        : next.toStringAsFixed(1);
    widget.controller.text = str;
    widget.onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 30,
      child: Row(
        children: [
          _StepBtn(
            icon: Icons.remove,
            onPressed: () => _bump(-widget.step),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppTextStyles.tableCell,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onSubmitted: (v) =>
                  widget.onCommit(double.tryParse(v) ?? 0),
              onEditingComplete: () => widget
                  .onCommit(double.tryParse(widget.controller.text) ?? 0),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onPressed: () => _bump(widget.step),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 28,
      height: 30,
      child: Material(
        color: c.sectionHeaderBg,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: c.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: c.textPrimary),
          ),
        ),
      ),
    );
  }
}
