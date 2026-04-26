import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/solver/solver_isolate.dart';
import 'providers/solver_provider.dart';
import 'providers/tabs_provider.dart';
import 'theme/app_colors.dart';
import 'widgets/left_pane.dart';
import 'widgets/right_pane.dart';
import 'widgets/save_as_dialog.dart';
import 'widgets/shortcuts_cheatsheet_dialog.dart';
import 'widgets/top_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  StreamSubscription<String>? _noticesSub;

  /// 자동 계산용 디바운스 타이머 — 사용자가 부품/자재/옵션을 바꿀 때마다
  /// notifyListeners 가 발생하므로, 마지막 변경 후 500ms 무변경이면 솔버 호출.
  Timer? _autoCalcTimer;

  /// 가장 최신 자동 계산 호출만 결과로 반영하기 위한 세션 카운터.
  /// 빠른 변경으로 동시 두 번 솔버가 돌면 stale 결과가 cuttingPlanProvider 를
  /// 덮어쓰는 race 를 방지한다.
  int _calcSession = 0;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(tabsProvider);
    _noticesSub = notifier.notices.listen(_showNotice);
    // 부팅 직후 활성 프로젝트가 이미 있으면 즉시 한 번 계산해서 결과를 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runAutoCalc();
    });
  }

  @override
  void dispose() {
    _noticesSub?.cancel();
    _autoCalcTimer?.cancel();
    super.dispose();
  }

  void _showNotice(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  void _scheduleAutoCalc() {
    _autoCalcTimer?.cancel();
    _autoCalcTimer = Timer(const Duration(milliseconds: 500), _runAutoCalc);
  }

  Future<void> _runAutoCalc() async {
    if (!mounted) return;
    final session = ++_calcSession;
    final project = ref.read(activeProjectProvider);
    if (project == null) return;
    if (project.parts.isEmpty || project.stocks.isEmpty) {
      // 부품 또는 자재가 비어있으면 결과 비움 (EmptyResultPane 표시).
      ref.read(cuttingPlanProvider.notifier).state = null;
      return;
    }
    ref.read(isCalculatingProvider.notifier).state = true;
    try {
      final plan = await solveInIsolate(
        stocks: project.stocks,
        parts: project.parts,
        kerf: project.kerf,
        grainLocked: project.grainLocked,
        solverMode: project.solverMode,
        stripDirection: project.stripDirection,
        maxStages: project.maxStages,
        preferSameWidth: project.preferSameWidth,
        minimizeCuts: project.minimizeCuts,
        minimizeWaste: project.minimizeWaste,
      );
      // 더 새로운 _calcSession 이 시작됐으면 이 결과는 stale — 무시.
      if (session != _calcSession || !mounted) return;
      ref.read(cuttingPlanProvider.notifier).state = plan;
    } finally {
      if (session == _calcSession && mounted) {
        ref.read(isCalculatingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 활성 프로젝트의 부품/자재/옵션이 바뀔 때마다 자동 계산 디바운스 타이머 reset.
    ref.listen(activeProjectProvider, (prev, next) {
      _scheduleAutoCalc();
    });

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
        SingleActivator(LogicalKeyboardKey.tab, meta: true): _NextTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true):
            _NextTabIntent(),
        // `?` is shift-`/` on most US/KR layouts; also accept the bare key
        // for layouts that emit it directly.
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
          child: const Scaffold(
            body: Column(
              children: [
                TopBar(),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 380, child: LeftPane()),
                      VerticalDivider(width: 1, color: AppColors.border),
                      Expanded(child: RightPane()),
                    ],
                  ),
                ),
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
      await n.saveAs(tab.id);
      return;
    }
    final name = await showSaveAsDialog(context, initialName: tab.project.name);
    if (name == null) return;
    try {
      await n.saveAs(tab.id, overrideName: name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: $e')));
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

class _NextTabIntent extends Intent {
  const _NextTabIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}
