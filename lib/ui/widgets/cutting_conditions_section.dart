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

        // 헤드컷 (상/하/좌/우 십자 배치)
        const Text('헤드컷 (상/하/좌/우)', style: AppTextStyles.body),
        const SizedBox(height: 6),
        Center(
          child: SizedBox(
            width: 380,
            height: 200,
            child: _HeadcutCross(
              top: _topCtrl,
              bottom: _bottomCtrl,
              left: _leftCtrl,
              right: _rightCtrl,
              onTop: (v) => notifier.updateHeadcut(activeId, top: v),
              onBottom: (v) =>
                  notifier.updateHeadcut(activeId, bottom: v),
              onLeft: (v) => notifier.updateHeadcut(activeId, left: v),
              onRight: (v) =>
                  notifier.updateHeadcut(activeId, right: v),
            ),
          ),
        ),

        const SizedBox(height: 12),
        const CutOptionsSection(),
      ],
    );
  }
}

/// 자재 사각형을 가운데 두고 사방에 입력칸을 배치 — 시각적으로 어느 변에
/// 헤드컷이 적용되는지 즉시 인식 가능.
class _HeadcutCross extends StatelessWidget {
  const _HeadcutCross({
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
    return Column(
      children: [
        // 상
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LabeledStepper(
                label: '↑ 상', controller: top, onCommit: onTop),
          ],
        ),
        const SizedBox(height: 6),
        // 좌 + 사각형 + 우
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _LabeledStepper(
                label: '← 좌',
                controller: left,
                onCommit: onLeft,
                rotated: true),
            const SizedBox(width: 8),
            Builder(builder: (context) {
              final c = context.colors;
              return Container(
                width: 80,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  border: Border.all(color: c.border, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '자재',
                  style:
                      TextStyle(fontSize: 11, color: c.textSecondary),
                ),
              );
            }),
            const SizedBox(width: 8),
            _LabeledStepper(
                label: '우 →',
                controller: right,
                onCommit: onRight,
                rotated: true),
          ],
        ),
        const SizedBox(height: 6),
        // 하
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LabeledStepper(
                label: '↓ 하',
                controller: bottom,
                onCommit: onBottom),
          ],
        ),
      ],
    );
  }
}

/// 라벨 + - / 값 / + 형태의 컴팩트 스테퍼.
/// [rotated]는 시각적 의미만 가짐 — 좌/우 측 cell이 stack 형태로 보이도록
/// 라벨을 위쪽에 두는 layout flag.
class _LabeledStepper extends StatelessWidget {
  const _LabeledStepper({
    required this.label,
    required this.controller,
    required this.onCommit,
    this.rotated = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<double> onCommit;
  final bool rotated;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: context.colors.textSecondary)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NumberStepper(
              controller: controller,
              width: 100,
              step: 1,
              min: 0,
              max: 200,
              onCommit: onCommit,
            ),
            const SizedBox(width: 4),
            Text(
              'mm',
              style: TextStyle(
                  fontSize: 11, color: context.colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// [-] [숫자 입력] [+] 컴팩트 스테퍼. 텍스트 직접 입력도 가능.
class _NumberStepper extends StatelessWidget {
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

  void _bump(double delta) {
    final cur = double.tryParse(controller.text) ?? 0;
    var next = cur + delta;
    if (next < min) next = min;
    if (next > max) next = max;
    final str =
        next == next.toInt() ? next.toInt().toString() : next.toStringAsFixed(1);
    controller.text = str;
    onCommit(next);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 30,
      child: Row(
        children: [
          _StepBtn(
            icon: Icons.remove,
            onPressed: () => _bump(-step),
          ),
          Expanded(
            child: TextField(
              controller: controller,
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
              onSubmitted: (v) => onCommit(double.tryParse(v) ?? 0),
              onEditingComplete: () =>
                  onCommit(double.tryParse(controller.text) ?? 0),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onPressed: () => _bump(step),
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
