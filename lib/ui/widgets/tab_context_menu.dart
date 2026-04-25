import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tabs_provider.dart';
import 'save_as_dialog.dart';

enum _MenuKind { rename, duplicate, revealInFinder, saveAsCopy, close, closeOthers }

/// [tabId] 탭의 우클릭 컨텍스트 메뉴를 [position]에 띄운다.
/// [onRename]은 인라인 편집을 시작하는 콜백 (TabItem 외부에서 트리거하기 어려워 위임).
Future<void> showTabContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String tabId,
  required Offset position,
  required VoidCallback onRename,
}) async {
  final notifier = ref.read(tabsProvider);
  final tab = notifier.tabs.firstWhere((t) => t.id == tabId);
  final isSaved = tab.filePath != null;

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;

  final result = await showMenu<_MenuKind>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    ),
    items: [
      const PopupMenuItem(value: _MenuKind.rename, child: Text('이름 변경')),
      const PopupMenuItem(value: _MenuKind.duplicate, child: Text('복사본 만들기')),
      PopupMenuItem(
        value: _MenuKind.revealInFinder,
        enabled: isSaved,
        child: Text(Platform.isMacOS ? 'Finder에서 보기' : '탐색기에서 보기'),
      ),
      const PopupMenuItem(value: _MenuKind.saveAsCopy, child: Text('다른 이름으로 저장...')),
      const PopupMenuDivider(),
      const PopupMenuItem(value: _MenuKind.close, child: Text('닫기')),
      const PopupMenuItem(value: _MenuKind.closeOthers, child: Text('다른 탭 모두 닫기')),
    ],
  );
  if (result == null || !context.mounted) return;

  switch (result) {
    case _MenuKind.rename:
      onRename();
      break;
    case _MenuKind.duplicate:
      try {
        await notifier.duplicateTab(tabId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('복제 실패: $e')));
        }
      }
      break;
    case _MenuKind.revealInFinder:
      if (tab.filePath != null) {
        try {
          if (Platform.isMacOS) {
            await Process.run('open', ['-R', tab.filePath!]);
          } else if (Platform.isWindows) {
            await Process.run('explorer.exe', ['/select,', tab.filePath!]);
          } else {
            await Process.run('xdg-open', [File(tab.filePath!).parent.path]);
          }
        } catch (_) {}
      }
      break;
    case _MenuKind.saveAsCopy:
      if (!context.mounted) return;
      final name = await showSaveAsDialog(context, initialName: '${tab.project.name} 사본');
      if (name == null) return;
      try {
        await notifier.saveAsCopy(tabId, name);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('저장 실패: $e')));
        }
      }
      break;
    case _MenuKind.close:
      await notifier.closeTab(tabId);
      break;
    case _MenuKind.closeOthers:
      await notifier.closeOthers(tabId);
      break;
  }
}

/// "이름 변경" 메뉴용 다이얼로그 진입점.
///
/// pragma: 진정한 inline 편집을 메뉴에서 트리거하려면 [TabItem]을
/// StatefulWidget 외부 핸들로 노출하는 리팩터가 필요하다. 1차 단순화로
/// SaveAsDialog 형식의 이름 입력 다이얼로그를 띄우고
/// [TabsNotifier.renameSavedFile]을 호출한다.
Future<void> showRenameDialog(
  BuildContext context,
  WidgetRef ref,
  String tabId,
  String currentName,
) async {
  final newName = await showSaveAsDialog(context, initialName: currentName);
  if (newName == null || !context.mounted) return;
  await ref.read(tabsProvider).renameSavedFile(tabId, newName);
}
