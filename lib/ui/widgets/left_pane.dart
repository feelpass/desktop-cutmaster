import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'options_section.dart';
import 'parts_table.dart';
import 'preset_management_dialog.dart';
import 'stocks_table.dart';

class LeftPane extends ConsumerWidget {
  const LeftPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Container(
      color: AppColors.surface,
      child: ListView(
        children: [
          LeftPaneSection(
            title: t.parts,
            icon: Icons.inventory_2_outlined,
            onSettings: () =>
                showPresetManagementDialog(context, PresetKind.part),
            child: const PartsTable(),
          ),
          LeftPaneSection(
            title: t.stockSheets,
            icon: Icons.layers_outlined,
            onSettings: () =>
                showPresetManagementDialog(context, PresetKind.stock),
            child: const StocksTable(),
          ),
          LeftPaneSection(
            title: t.options,
            icon: Icons.tune,
            child: const OptionsSection(),
          ),
        ],
      ),
    );
  }
}

/// 좌측 패널의 접이식 섹션 — 헤더 [arrow][icon][title]에 더해
/// [onSettings]가 주어지면 우측 끝에 ⚙️ 버튼이 노출된다.
///
/// ⚙️ 탭은 헤더의 expand/collapse 토글과 분리되어야 한다.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.sectionHeaderBg,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(_expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                      size: 18, color: AppColors.tableHeaderText),
                  const SizedBox(width: 4),
                  Icon(widget.icon, size: 14, color: AppColors.tableHeaderText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(widget.title, style: AppTextStyles.sectionHeader),
                  ),
                  if (widget.onSettings != null)
                    // 외부 InkWell의 expand/collapse 토글이 ⚙️ 탭에서
                    // 발화되지 않도록 GestureDetector(opaque)로 감싼다 —
                    // GestureDetector가 hit을 흡수하면 부모 InkWell.onTap은
                    // 호출되지 않는다.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSettings,
                      child: const Tooltip(
                        message: '프리셋 관리',
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.settings,
                            size: 14,
                            color: AppColors.tableHeaderText,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: widget.child,
          ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
