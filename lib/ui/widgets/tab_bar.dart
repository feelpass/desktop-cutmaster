import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import 'plus_button.dart';
import 'tab_item.dart';

/// 멀티 탭 워크스페이스 헤더. 가로 스크롤 + 끝에 [PlusButton].
///
/// long-press로 드래그-정렬 가능. 짧은 tap은 그대로 자식([TabItem])에
/// 전달되어 탭 활성화/닫기/이름 변경 등이 정상 동작한다
/// ([ReorderableDelayedDragStartListener]가 long-press 이전까지 gesture
/// arena claim을 미루기 때문).
class CutmasterTabBar extends ConsumerWidget {
  const CutmasterTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // listen for any tab change; callbacks use the same instance
    final notifier = ref.watch(tabsProvider);
    final tabs = notifier.tabs;
    final activeId = notifier.activeId;
    // perf TODO: 탭이 매우 많아지면 (e.g. 50+) per-tab family provider로 분리

    return Container(
      color: AppColors.header,
      child: Row(
        children: [
          Expanded(
            // 데스크탑에서 가로 스크롤 영역에 자동으로 붙는 스크롤바가
            // 탭 영역을 가리지 않도록 비활성화한다.
            child: ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                onReorder: notifier.reorder,
                itemCount: tabs.length,
                itemBuilder: (ctx, i) {
                  final tab = tabs[i];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(tab.id),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      child: TabItem(
                        displayName: tab.project.name,
                        isActive: tab.id == activeId,
                        isDirty: tab.isDirty,
                        isUntitled: tab.filePath == null,
                        onTap: () => notifier.setActive(tab.id),
                        onClose: () => notifier.closeTab(tab.id),
                        // untitled은 in-memory 이름, saved 탭은 파일까지 rename
                        onRenameSubmit: (name) =>
                            notifier.renameSavedFile(tab.id, name),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const PlusButton(),
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
