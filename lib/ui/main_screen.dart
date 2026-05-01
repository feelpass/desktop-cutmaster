import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/tabs_provider.dart';
import 'theme/app_colors.dart';
import 'widgets/left_pane.dart';
import 'widgets/shortcuts_cheatsheet_dialog.dart';
import 'widgets/top_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  StreamSubscription<String>? _noticesSub;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(tabsProvider);
    _noticesSub = notifier.notices.listen(_showNotice);
  }

  @override
  void dispose() {
    _noticesSub?.cancel();
    super.dispose();
  }

  void _showNotice(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): _NewIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): _NewIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, meta: true): _OpenIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true): _OpenIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true): _CloseIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: true): _CloseIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true):
            _ReopenIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true):
            _ReopenIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
            _SaveAsIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            _SaveAsIntent(),
        SingleActivator(LogicalKeyboardKey.tab, meta: true): _NextTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true):
            _NextTabIntent(),
        SingleActivator(LogicalKeyboardKey.slash, shift: true): _HelpIntent(),
        SingleActivator(LogicalKeyboardKey.question): _HelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewIntent: CallbackAction<_NewIntent>(
            onInvoke: (_) {
              ref.read(tabsProvider).newUntitled();
              return null;
            },
          ),
          _OpenIntent: CallbackAction<_OpenIntent>(
            onInvoke: (_) {
              _openViaPicker(context, ref);
              return null;
            },
          ),
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              final n = ref.read(tabsProvider);
              final id = n.activeId;
              if (id != null) n.closeTab(id);
              return null;
            },
          ),
          _ReopenIntent: CallbackAction<_ReopenIntent>(
            onInvoke: (_) {
              ref.read(tabsProvider).reopenLastClosed();
              return null;
            },
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              _saveActive(context, ref);
              return null;
            },
          ),
          _SaveAsIntent: CallbackAction<_SaveAsIntent>(
            onInvoke: (_) {
              _saveAsActive(context, ref);
              return null;
            },
          ),
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) {
              ref.read(tabsProvider).cycleNext();
              return null;
            },
          ),
          _HelpIntent: CallbackAction<_HelpIntent>(
            onInvoke: (_) {
              showShortcutsCheatsheet(context);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: context.colors.background,
            body: const Column(
              children: [
                TopBar(),
                Expanded(child: LeftPane()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openViaPicker(BuildContext context, WidgetRef ref) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('열 수 없습니다: $e')));
      }
    }
  }

  Future<void> _saveActive(BuildContext context, WidgetRef ref) async {
    final n = ref.read(tabsProvider);
    final tab = n.active;
    if (tab == null) return;
    if (tab.filePath != null) {
      try {
        await n.saveAs(tab.id);
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
      await n.saveToPath(tab.id, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  /// 다른 이름으로 저장 — 현재 탭에 파일 경로가 있어도 항상 picker 노출.
  Future<void> _saveAsActive(BuildContext context, WidgetRef ref) async {
    final n = ref.read(tabsProvider);
    final tab = n.active;
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
      await n.saveToPath(tab.id, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }
}

class _NewIntent extends Intent {
  const _NewIntent();
}

class _OpenIntent extends Intent {
  const _OpenIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _ReopenIntent extends Intent {
  const _ReopenIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SaveAsIntent extends Intent {
  const _SaveAsIntent();
}

class _NextTabIntent extends Intent {
  const _NextTabIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}
