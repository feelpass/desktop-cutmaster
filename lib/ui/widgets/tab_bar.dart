import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import 'plus_button.dart';
import 'tab_item.dart';

/// 멀티 탭 워크스페이스 헤더. 가로 스크롤 + 끝에 [PlusButton].
///
/// TODO(task-12): 드래그-정렬 지원. ReorderableListView를 시도했으나
/// `ReorderableDragStartListener`가 자식의 tap (close 버튼 포함)을
/// intercept해서 tap 콜백이 작동하지 않는 이슈가 있어 우선 ListView로
/// 폴백. 향후 long-press only listener + 별도 InkWell 조합으로 재구현 예정.
class CutmasterTabBar extends ConsumerWidget {
  const CutmasterTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(tabsProvider);
    final tabs = notifier.tabs;
    final activeId = notifier.activeId;

    return Container(
      color: AppColors.header,
      child: Row(
        children: [
          Expanded(
            // 데스크탑에서 가로 스크롤 영역에 자동으로 붙는 스크롤바가
            // 탭 영역을 가리지 않도록 비활성화한다.
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                itemBuilder: (ctx, i) {
                  final tab = tabs[i];
                  return TabItem(
                    key: ValueKey(tab.id),
                    displayName: tab.project.name,
                    isActive: tab.id == activeId,
                    isDirty: tab.isDirty,
                    isUntitled: tab.filePath == null,
                    onTap: () => notifier.setActive(tab.id),
                    onClose: () => notifier.closeTab(tab.id),
                    onRenameSubmit: (name) =>
                        notifier.updateName(tab.id, name),
                  );
                },
              ),
            ),
          ),
          PlusButton(onPressed: notifier.newUntitled),
        ],
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
