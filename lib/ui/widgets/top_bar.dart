import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/solver_provider.dart';
import '../providers/tabs_provider.dart';
import '../providers/theme_mode_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'result_dialog.dart';
import 'shortcuts_cheatsheet_dialog.dart';
import 'tab_bar.dart';

/// 상단 헤더 — 라이트/다크 모드 모두 대응. 헤더는 `context.colors.header` 위에
/// 1px 보더를 깔고, 텍스트/아이콘은 `textOnHeader`로 통일.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalculating = ref.watch(isCalculatingProvider);
    final c = context.colors;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: c.header,
        border: Border(
          bottom: BorderSide(color: c.headerBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.content_cut, color: c.textOnHeader, size: 18),
          const SizedBox(width: 8),
          Text('재단 최적화 시스템', style: AppTextStyles.topBarTitle(context)),
          const SizedBox(width: 16),
          const _StepIndicator(currentStep: 1),
          const SizedBox(width: 16),
          const Expanded(child: CutmasterTabBar()),
          _HeaderGhostButton(
            icon: Icons.folder_open,
            label: '불러오기',
            onPressed: () => _onOpenPressed(context, ref),
          ),
          const SizedBox(width: 8),
          _SaveButtonGroup(
            onSave: () => _onSavePressed(context, ref),
            onSaveAs: () => _onSaveAsPressed(context, ref),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isCalculating
                ? null
                : () => _onCalculatePressed(context, ref),
            icon: isCalculating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: const Text('최적화 실행'),
          ),
          const SizedBox(width: 8),
          _ThemeToggleButton(),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('help-button'),
            onPressed: () => showShortcutsCheatsheet(context),
            icon: Icon(Icons.help_outline, color: c.textOnHeader, size: 20),
            tooltip: '단축키 도움말',
          ),
        ],
      ),
    );
  }

  Future<void> _onCalculatePressed(
      BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    await runCalculate(ref);
    if (!context.mounted) return;
    await showResultDialog(context);
  }

  Future<void> _onOpenPressed(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cutmaster'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;
    try {
      await ref.read(tabsProvider).openFile(result.files.single.path!);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('열 수 없습니다: $e')));
      }
    }
  }

  Future<void> _onSavePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(tabsProvider);
    final tab = notifier.active;
    if (tab == null) return;

    if (tab.filePath != null) {
      try {
        await notifier.saveAs(tab.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
        }
      }
      return;
    }

    final defaultName = tab.project.name.trim().isEmpty
        ? '새 프로젝트'
        : tab.project.name;
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: '저장할 위치 선택',
      fileName: '$defaultName.cutmaster',
      type: FileType.custom,
      allowedExtensions: const ['cutmaster'],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    try {
      await notifier.saveToPath(tab.id, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }

  /// 다른 이름으로 저장 — 항상 file picker로 새 경로 받음.
  /// 이미 저장된 탭이라도 원본 파일은 그대로 두고 새 위치에 사본 생성.
  Future<void> _onSaveAsPressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(tabsProvider);
    final tab = notifier.active;
    if (tab == null) return;

    final defaultName = tab.project.name.trim().isEmpty
        ? '새 프로젝트'
        : tab.project.name;
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: '다른 이름으로 저장',
      fileName: '$defaultName.cutmaster',
      type: FileType.custom,
      allowedExtensions: const ['cutmaster'],
    );
    if (picked == null) return;
    if (!context.mounted) return;
    try {
      await notifier.saveToPath(tab.id, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }
}

/// 저장 split-button — 메인 [저장] + 옆에 ▾ 드롭다운으로 [다른 이름으로 저장...].
/// 두 버튼을 시각적으로 인접한 그룹으로 묶기 위해 양쪽 모서리만 둥글게.
class _SaveButtonGroup extends StatelessWidget {
  const _SaveButtonGroup({required this.onSave, required this.onSaveAs});

  final VoidCallback onSave;
  final VoidCallback onSaveAs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final borderSide = BorderSide(color: c.headerBorder);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onSave,
          icon: Icon(Icons.save_outlined, size: 16, color: c.textOnHeader),
          label: const Text('저장'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textOnHeader,
            side: borderSide,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
          ),
        ),
        // 1px gap 없이 바로 붙도록 negative margin 대신 inkwell+container 직접.
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('save-as-dropdown'),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
            onTap: () => _showMenu(context),
            child: Container(
              height: 36,
              width: 24,
              decoration: BoxDecoration(
                border: Border(
                  top: borderSide,
                  right: borderSide,
                  bottom: borderSide,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Icon(Icons.expand_more, size: 16, color: c.textOnHeader),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: 'save-as',
          child: Row(
            children: [
              Icon(Icons.save_as_outlined, size: 16),
              SizedBox(width: 8),
              Text('다른 이름으로 저장...'),
              Spacer(),
              SizedBox(width: 12),
              Text('⇧⌘S',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
    if (action == 'save-as') onSaveAs();
  }
}

/// 헤더 위 ghost 버튼 — 헤더 톤에 맞춰 텍스트/보더 색이 자동 결정.
class _HeaderGhostButton extends StatelessWidget {
  const _HeaderGhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textOnHeader,
        side: BorderSide(color: c.headerBorder),
        backgroundColor: Colors.transparent,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: c.textOnHeader),
      label: Text(label),
    );
  }
}

/// 라이트 ↔ 다크 토글. system 모드면 platform brightness 기준으로 다음 모드 선택.
class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mode = ref.watch(themeModeProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return IconButton(
      key: const ValueKey('theme-toggle'),
      onPressed: () {
        ref
            .read(themeModeProvider.notifier)
            .toggle(MediaQuery.platformBrightnessOf(context));
      },
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: c.textOnHeader,
        size: 18,
      ),
      tooltip: switch (mode) {
        ThemeMode.system => '테마: 시스템',
        ThemeMode.light => '테마: 라이트',
        ThemeMode.dark => '테마: 다크',
      },
    );
  }
}

/// 상단 단계 인디케이터: ① 입력 → ② 결과
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        _StepDot(num: 1, label: '입력', active: currentStep == 1),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward, size: 14, color: c.textOnHeader),
        const SizedBox(width: 8),
        _StepDot(num: 2, label: '결과', active: currentStep == 2),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.num, required this.label, required this.active});

  final int num;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = Theme.of(context).colorScheme.primary;
    final inactive = c.textOnHeader.withValues(alpha: 0.5);
    final color = active ? accent : inactive;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$num',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? c.textOnHeader : color,
            letterSpacing: -0.13,
          ),
        ),
      ],
    );
  }
}
