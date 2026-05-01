import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'cutting_conditions_section.dart';
import 'order_info_section.dart';
import 'parts_table.dart';
import 'preset_management_dialog.dart';

/// 입력 화면 — 상단 가로 split (주문정보 | 재단조건) + 하단 (부품 목록 입력 풀너비).
/// 상단은 자연 높이로 줄여 화면 자원을 부품 목록에 양보.
class LeftPane extends ConsumerWidget {
  const LeftPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Container(
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단: 주문 정보 (좌) + 재단 조건 (우) — 고정 높이로 부품 목록 영역에 화면 양보.
          SizedBox(
            height: 540,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: LeftPaneSection(
                    title: '1. 주문 정보',
                    icon: Icons.receipt_long_outlined,
                    child: OrderInfoSection(),
                  ),
                ),
                VerticalDivider(width: 1, color: c.border),
                const Expanded(
                  child: LeftPaneSection(
                    title: '2. 재단 조건',
                    icon: Icons.tune,
                    child: CuttingConditionsSection(),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // 하단: 부품 목록 입력 (남은 영역 전체)
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
  });

  final String title;
  final IconData icon;
  final Widget child;

  /// 헤더 우측 ⚙️ 버튼 콜백. null이면 버튼이 렌더되지 않는다.
  final VoidCallback? onSettings;

  @override
  State<LeftPaneSection> createState() => _LeftPaneSectionState();
}

class _LeftPaneSectionState extends State<LeftPaneSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.sectionHeaderBg,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
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
