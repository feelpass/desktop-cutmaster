import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/workspace_db.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';

/// 탭바 끝 + 버튼. 크롬 스타일로 마지막 탭 바로 옆에 탭 모양 버튼.
/// 클릭 시 popup 메뉴: 새 프로젝트 / 파일에서 열기 / 최근 N개.
class PlusButton extends ConsumerWidget {
  const PlusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TabItem과 동일한 외곽 패딩/높이/모서리로 탭 외관을 흉내낸다.
    final showHints =
        ref.watch(activeProjectProvider)?.showShortcutHints ?? true;
    final inkWell = InkWell(
      key: const ValueKey('plus-button'),
      onTap: () => _showMenu(context, ref),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Icon(Icons.add, size: 18, color: AppColors.textOnHeader),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Material(
        color: Colors.white24,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        child: showHints
            ? Tooltip(
                message: '새 프로젝트 (⌘N) / 파일 열기 (⌘O)',
                child: inkWell,
              )
            : inkWell,
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(tabsProvider);
    // 메뉴 위치 계산용 RenderBox는 await 전에 캡처해 BuildContext를 async-gap
    // 너머로 들고 가지 않는다 (use_build_context_synchronously 회피).
    final box = context.findRenderObject() as RenderBox?;
    final overlayCtx = Overlay.of(context).context;
    final overlay = overlayCtx.findRenderObject() as RenderBox?;

    final recent = await notifier.workspace.listRecentFiles();
    if (!context.mounted) return;
    final position = (box != null && overlay != null)
        ? RelativeRect.fromRect(
            Rect.fromPoints(
              box.localToGlobal(box.size.bottomLeft(Offset.zero),
                  ancestor: overlay),
              box.localToGlobal(box.size.bottomRight(Offset.zero),
                  ancestor: overlay),
            ),
            Offset.zero & overlay.size,
          )
        : const RelativeRect.fromLTRB(0, 0, 0, 0);

    final action = await showMenu<_PlusAction>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: _PlusAction.newProject,
          child: Row(children: [
            Icon(Icons.add, size: 16),
            SizedBox(width: 8),
            Text('새 프로젝트'),
          ]),
        ),
        const PopupMenuItem(
          value: _PlusAction.openFile,
          child: Row(children: [
            Icon(Icons.folder_open, size: 16),
            SizedBox(width: 8),
            Text('파일에서 열기...'),
          ]),
        ),
        if (recent.isNotEmpty) const PopupMenuDivider(),
        if (recent.isNotEmpty)
          const PopupMenuItem(
            value: _PlusAction.recentLabel,
            enabled: false,
            child: Text('최근',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ...recent.take(10).map((r) => PopupMenuItem(
              value: _PlusAction.openRecent(r),
              child: Tooltip(
                message: r.filePath,
                child: Text(r.displayName, overflow: TextOverflow.ellipsis),
              ),
            )),
      ],
    );

    if (action == null || !context.mounted) return;
    if (action.kind == _PlusKind.newProject) {
      notifier.newUntitled();
    } else if (action.kind == _PlusKind.openFile) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cutmaster'],
      );
      if (result == null || result.files.single.path == null) return;
      try {
        await notifier.openFile(result.files.single.path!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('열 수 없습니다: $e')));
        }
      }
    } else if (action.kind == _PlusKind.openRecent) {
      final path = action.recent!.filePath;
      if (!File(path).existsSync()) {
        await notifier.workspace.removeRecentFile(path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('파일을 찾을 수 없어요: $path')));
        }
        return;
      }
      try {
        await notifier.openFile(path);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('열 수 없습니다: $e')));
        }
      }
    }
  }
}

enum _PlusKind { newProject, openFile, recentLabel, openRecent }

class _PlusAction {
  final _PlusKind kind;
  final RecentFileRow? recent;
  const _PlusAction._(this.kind, this.recent);
  static const newProject = _PlusAction._(_PlusKind.newProject, null);
  static const openFile = _PlusAction._(_PlusKind.openFile, null);
  static const recentLabel = _PlusAction._(_PlusKind.recentLabel, null);
  static _PlusAction openRecent(RecentFileRow r) =>
      _PlusAction._(_PlusKind.openRecent, r);
}
