import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/left_pane_split_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'cutting_conditions_section.dart';
import 'order_info_section.dart';
import 'parts_table.dart';
import 'preset_management_dialog.dart';

/// 입력 화면 — 상단 가로 split (주문정보 | 재단조건) + 하단 (부품 목록 입력 풀너비).
/// 상단/하단 경계는 드래그로 조절 가능 (높이는 WorkspaceDb에 영속).
class LeftPane extends ConsumerStatefulWidget {
  const LeftPane({super.key});

  @override
  ConsumerState<LeftPane> createState() => _LeftPaneState();
}

class _LeftPaneState extends ConsumerState<LeftPane> {
  // 드래그 중에는 로컬 상태로 즉시 반영, 종료 시 영속 저장.
  double? _dragHeight;
  bool _orderExpanded = true;
  bool _conditionsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final persistedHeight = ref.watch(leftPaneSplitProvider);
    final topAnyExpanded = _orderExpanded || _conditionsExpanded;

    return LayoutBuilder(builder: (context, constraints) {
      const bottomMin = 160.0;
      final available = constraints.maxHeight;
      final maxTop = (available - bottomMin)
          .clamp(kLeftPaneTopHeightMin, kLeftPaneTopHeightMax);
      final rawHeight = _dragHeight ?? persistedHeight;
      final topHeight =
          rawHeight.clamp(kLeftPaneTopHeightMin, maxTop).toDouble();

      final topRow = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LeftPaneSection(
              title: '1. 주문 정보',
              icon: Icons.receipt_long_outlined,
              expanded: _orderExpanded,
              onExpandedChanged: (v) => setState(() => _orderExpanded = v),
              child: const OrderInfoSection(),
            ),
          ),
          VerticalDivider(width: 1, color: c.border),
          Expanded(
            child: LeftPaneSection(
              title: '2. 재단 조건',
              icon: Icons.tune,
              expanded: _conditionsExpanded,
              onExpandedChanged: (v) =>
                  setState(() => _conditionsExpanded = v),
              child: const CuttingConditionsSection(),
            ),
          ),
        ],
      );

      return Container(
        color: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 둘 다 접히면 자연 높이(헤더만), 하나라도 펼쳐지면 드래그 가능한 고정 높이.
            // unbounded height context에서 Row+VerticalDivider+stretch가 무너지므로
            // 접힘 상태에서는 IntrinsicHeight로 헤더 높이를 측정.
            if (topAnyExpanded)
              SizedBox(height: topHeight, child: topRow)
            else
              IntrinsicHeight(child: topRow),
            // 드래그 핸들은 상단이 펼쳐져 있을 때만 노출.
            if (topAnyExpanded)
              _SplitHandle(
                onDragUpdate: (dy) {
                  setState(() {
                    _dragHeight = (_dragHeight ?? persistedHeight) + dy;
                  });
                },
                onDragEnd: () {
                  final d = _dragHeight;
                  _dragHeight = null;
                  if (d != null) {
                    ref
                        .read(leftPaneSplitProvider.notifier)
                        .setHeight(d.clamp(kLeftPaneTopHeightMin, maxTop));
                  }
                },
              )
            else
              Divider(height: 1, color: c.border),
            Expanded(
              child: LeftPaneSection(
                title: '3. 부품 목록 입력',
                icon: Icons.inventory_2_outlined,
                onSettings: () =>
                    showPresetManagementDialog(context, PresetKind.part),
                child: const PartsTable(),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// 좌측 패널 상/하단 경계 드래그 핸들 — 위아래 리사이즈 커서.
class _SplitHandle extends StatelessWidget {
  const _SplitHandle({required this.onDragUpdate, required this.onDragEnd});

  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
        onVerticalDragEnd: (_) => onDragEnd(),
        onVerticalDragCancel: onDragEnd,
        child: Container(
          height: 6,
          alignment: Alignment.center,
          child: Container(height: 1, color: c.border),
        ),
      ),
    );
  }
}

/// 접이식 섹션 — 헤더 [arrow][icon][title]에 더해
/// [onSettings]가 주어지면 우측 끝에 ⚙️ 버튼이 노출된다.
@visibleForTesting
class LeftPaneSection extends StatefulWidget {
  const LeftPaneSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onSettings,
    this.expanded,
    this.onExpandedChanged,
  });

  final String title;
  final IconData icon;
  final Widget child;

  /// 헤더 우측 ⚙️ 버튼 콜백. null이면 버튼이 렌더되지 않는다.
  final VoidCallback? onSettings;

  /// controlled 모드: null이면 내부 상태로 동작, 값이 있으면 부모가 제어.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<LeftPaneSection> createState() => _LeftPaneSectionState();
}

class _LeftPaneSectionState extends State<LeftPaneSection> {
  bool _internalExpanded = true;

  bool get _expanded => widget.expanded ?? _internalExpanded;

  void _toggle() {
    final next = !_expanded;
    if (widget.onExpandedChanged != null) {
      widget.onExpandedChanged!(next);
    } else {
      setState(() => _internalExpanded = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.sectionHeaderBg,
          child: InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18,
                      color: c.tableHeaderText),
                  const SizedBox(width: 4),
                  Icon(widget.icon, size: 14, color: c.tableHeaderText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.title,
                        style: AppTextStyles.sectionHeader
                            .copyWith(color: c.tableHeaderText)),
                  ),
                  if (widget.onSettings != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSettings,
                      child: Tooltip(
                        message: '프리셋 관리',
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.settings,
                            size: 14,
                            color: c.tableHeaderText,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: widget.child,
            ),
          ),
      ],
    );
  }
}
