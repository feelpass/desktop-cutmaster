import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/solver_provider.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'save_as_dialog.dart';
import 'shortcuts_cheatsheet_dialog.dart';
import 'tab_bar.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final isCalculating = ref.watch(isCalculatingProvider);
    // 단축키 힌트 토글이 켜진 경우에만 Save 버튼 tooltip에 (⌘S)를 덧붙인다.
    // 그 외에는 라벨을 그대로 둬 — golden / 라벨 매칭 테스트가 깨지지 않도록.
    final showHints =
        ref.watch(activeProjectProvider)?.showShortcutHints ?? true;
    final saveTooltip = showHints ? '${t.save} (⌘S)' : t.save;

    return Container(
      height: 48,
      color: AppColors.header,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 로고 + 앱 이름
          const Icon(Icons.crop, color: AppColors.textOnHeader, size: 20),
          const SizedBox(width: 8),
          Text(t.appTitle, style: AppTextStyles.topBarTitle),

          const SizedBox(width: 24),

          // 탭 영역
          const Expanded(child: CutmasterTabBar()),

          // 우측 액션들
          ElevatedButton.icon(
            onPressed: isCalculating
                ? null
                : () {
                    // 활성 TextField commit 강제 (onEditingComplete 트리거)
                    FocusManager.instance.primaryFocus?.unfocus();
                    // 1 frame 기다려서 commit 반영 후 계산
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      runCalculate(ref);
                    });
                  },
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
            label: Text(t.calculate),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _onSavePressed(context, ref),
            icon: const Icon(Icons.save, color: AppColors.textOnHeader, size: 20),
            tooltip: saveTooltip,
          ),
          IconButton(
            key: const ValueKey('help-button'),
            onPressed: () => showShortcutsCheatsheet(context),
            icon: const Icon(Icons.help_outline,
                color: AppColors.textOnHeader, size: 20),
            tooltip: '단축키 도움말 (?)',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings,
                color: AppColors.textOnHeader, size: 20),
            tooltip: t.settings,
          ),
        ],
      ),
    );
  }

  Future<void> _onSavePressed(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(tabsProvider);
    final tab = notifier.active;
    if (tab == null) return;

    if (tab.filePath != null) {
      // 이미 저장된 탭 — 즉시 flush
      await notifier.saveAs(tab.id);
      return;
    }

    // Untitled — 다이얼로그
    final name = await showSaveAsDialog(context, initialName: tab.project.name);
    if (name == null) return;
    try {
      await notifier.saveAs(tab.id, overrideName: name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    }
  }
}
