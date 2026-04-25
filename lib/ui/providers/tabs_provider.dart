import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/file/project_file.dart';
import '../../data/local/workspace_db.dart';
import '../../domain/models/cut_part.dart';
import '../../domain/models/project.dart';
import '../../domain/models/stock_sheet.dart';

@immutable
class TabState {
  final String id;
  final String? filePath;
  final Project project;
  final bool isDirty;
  const TabState({
    required this.id,
    required this.filePath,
    required this.project,
    required this.isDirty,
  });
  TabState copyWith({String? filePath, Project? project, bool? isDirty}) =>
      TabState(
        id: id,
        filePath: filePath ?? this.filePath,
        project: project ?? this.project,
        isDirty: isDirty ?? this.isDirty,
      );
}

class TabsNotifier extends ChangeNotifier {
  TabsNotifier({
    required this.workspace,
    required this.files,
    required this.autosaveDir,
    required this.defaultProjectsDir,
    this.saveDebounce = const Duration(milliseconds: 500),
  });

  final WorkspaceDb workspace;
  final ProjectFileService files;
  final String autosaveDir;
  final String defaultProjectsDir;
  final Duration saveDebounce;

  List<TabState> _tabs = [];
  String? _activeId;
  final Map<String, Timer> _saveTimers = {};
  final Map<String, Future<String?>> _saveAsInFlight = {};
  int _idCounter = 0;
  bool _disposed = false;

  List<TabState> get tabs => List.unmodifiable(_tabs);
  String? get activeId => _activeId;
  TabState? get active =>
      _tabs.firstWhereOrNull((t) => t.id == _activeId);

  // === Tab lifecycle ===

  void newUntitled() {
    if (_disposed) return;
    final tabId = _newTabId();
    final p0 = Project.create(id: _newProjectId(), name: '새 프로젝트');
    _tabs = [
      ..._tabs,
      TabState(id: tabId, filePath: null, project: p0, isDirty: false),
    ];
    _activeId = tabId;
    notifyListeners();
  }

  Future<void> openFile(String path) async {
    if (_disposed) return;
    final existing = _tabs.firstWhereOrNull((t) => t.filePath == path);
    if (existing != null) {
      _activeId = existing.id;
      notifyListeners();
      return;
    }
    final project = await files.read(path);
    if (_disposed) return;
    final id = _newTabId();
    _tabs = [
      ..._tabs,
      TabState(id: id, filePath: path, project: project, isDirty: false),
    ];
    _activeId = id;
    await workspace.touchRecentFile(path, project.name);
    if (_disposed) return;
    notifyListeners();
  }

  void setActive(String id) {
    if (_disposed) return;
    if (_tabs.any((t) => t.id == id)) {
      _activeId = id;
      notifyListeners();
    }
  }

  Future<void> closeTab(String id) async {
    if (_disposed) return;
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return;
    _saveTimers.remove(id)?.cancel();

    String? autosavePath;
    if (tab.filePath == null) {
      autosavePath = p.join(autosaveDir, '${tab.id}.cutmaster');
    }
    await workspace.pushClosedTab(ClosedTabRow(
      tabId: tab.id,
      filePath: tab.filePath,
      autosavePath: autosavePath,
      displayName: tab.project.name,
      closedAt: DateTime.now(),
    ));
    if (_disposed) return;

    _tabs = _tabs.where((t) => t.id != id).toList();
    if (_activeId == id) {
      _activeId = _tabs.isNotEmpty ? _tabs.last.id : null;
    }
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (_disposed) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [..._tabs];
    final t = list.removeAt(oldIndex);
    list.insert(newIndex, t);
    _tabs = list;
    notifyListeners();
  }

  // === Project edits ===

  void updateName(String id, String name) =>
      _patch(id, (t) => t.copyWith(project: t.project.copyWith(name: name)));

  void updateStocks(String id, List<StockSheet> stocks) =>
      _patch(id, (t) => t.copyWith(project: t.project.copyWith(stocks: stocks)));

  void updateParts(String id, List<CutPart> parts) =>
      _patch(id, (t) => t.copyWith(project: t.project.copyWith(parts: parts)));

  void updateKerf(String id, double kerf) =>
      _patch(id, (t) => t.copyWith(project: t.project.copyWith(kerf: kerf)));

  void updateGrainLocked(String id, bool v) => _patch(
      id, (t) => t.copyWith(project: t.project.copyWith(grainLocked: v)));

  void updateShowPartLabels(String id, bool v) => _patch(
      id, (t) => t.copyWith(project: t.project.copyWith(showPartLabels: v)));

  void updateUseSingleSheet(String id, bool v) => _patch(
      id, (t) => t.copyWith(project: t.project.copyWith(useSingleSheet: v)));

  void _patch(String id, TabState Function(TabState) f) {
    if (_disposed) return;
    _tabs = _tabs.map((t) {
      if (t.id != id) return t;
      return f(t).copyWith(isDirty: true);
    }).toList();
    notifyListeners();
    _scheduleSave(id);
  }

  // === Persistence ===

  Future<String?> saveAs(String id, {String? overrideName}) {
    final existing = _saveAsInFlight[id];
    if (existing != null) return existing;
    final future = _doSaveAs(id, overrideName: overrideName);
    _saveAsInFlight[id] = future;
    future.whenComplete(() => _saveAsInFlight.remove(id));
    return future;
  }

  Future<String?> _doSaveAs(String id, {String? overrideName}) async {
    _saveTimers.remove(id)?.cancel();
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return null;

    if (tab.filePath != null) {
      await files.overwrite(tab.filePath!, tab.project);
      _setTab(id, (t) => t.copyWith(isDirty: false));
      return tab.filePath;
    }

    final baseName = overrideName ?? tab.project.name;
    final path = await files.writeNew(
      folder: defaultProjectsDir,
      baseName: baseName,
      project: tab.project,
    );

    final autosaveFile = File(p.join(autosaveDir, '${tab.id}.cutmaster'));
    if (autosaveFile.existsSync()) await autosaveFile.delete();

    await workspace.touchRecentFile(path, tab.project.name);
    _setTab(id, (t) => t.copyWith(filePath: path, isDirty: false));
    return path;
  }

  void _scheduleSave(String id) {
    _saveTimers.remove(id)?.cancel();
    _saveTimers[id] = Timer(saveDebounce, () => _persist(id));
  }

  Future<void> _persist(String id) async {
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null || !tab.isDirty) return;
    if (tab.filePath != null) {
      await files.overwrite(tab.filePath!, tab.project);
    } else {
      await Directory(autosaveDir).create(recursive: true);
      await files.overwrite(
        p.join(autosaveDir, '${tab.id}.cutmaster'),
        tab.project,
      );
    }
    if (_disposed) return;
    _setTab(id, (t) => t.copyWith(isDirty: false));
  }

  Future<void> flushAll() async {
    for (final id in _saveTimers.keys.toList()) {
      _saveTimers.remove(id)?.cancel();
      await _persist(id);
    }
  }

  // === Session restore / save ===

  Future<void> restoreSession() async {
    if (_disposed) return;
    final rows = await workspace.listTabs();
    if (_disposed) return;
    final loaded = <TabState>[];
    String? activeId;
    for (final r in rows) {
      try {
        final Project pr;
        if (r.filePath != null && File(r.filePath!).existsSync()) {
          pr = await files.read(r.filePath!);
        } else {
          final autosavePath = p.join(autosaveDir, '${r.id}.cutmaster');
          if (!File(autosavePath).existsSync()) continue; // 고아 — 스킵
          pr = await files.read(autosavePath);
        }
        loaded.add(TabState(
          id: r.id,
          filePath: r.filePath,
          project: pr,
          isDirty: false,
        ));
        if (r.isActive) activeId = r.id;
      } catch (_) {
        // 손상 / 권한 — 그 탭만 스킵
      }
    }
    if (_disposed) return;
    _tabs = loaded;
    _activeId = activeId ?? (loaded.isNotEmpty ? loaded.first.id : null);
    notifyListeners();
  }

  Future<void> saveSession() async {
    final rows = <TabRow>[];
    for (var i = 0; i < _tabs.length; i++) {
      final t = _tabs[i];
      rows.add(TabRow(
        id: t.id,
        filePath: t.filePath,
        displayName: t.project.name,
        position: i,
        isActive: t.id == _activeId,
      ));
    }
    await workspace.replaceAllTabs(rows);
  }

  void _setTab(String id, TabState Function(TabState) f) {
    if (_disposed) return;
    _tabs = _tabs.map((t) => t.id == id ? f(t) : t).toList();
    notifyListeners();
  }

  String _newTabId() =>
      't_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  String _newProjectId() =>
      'p_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  @override
  void dispose() {
    _disposed = true;
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    _saveTimers.clear();
    super.dispose();
  }
}

// === Riverpod providers ===

final tabsProvider =
    ChangeNotifierProvider<TabsNotifier>((ref) => throw UnimplementedError(
        '`tabsProvider`는 main.dart의 ProviderScope overrides에서 주입됩니다.'));

final activeTabIdProvider = Provider<String?>(
  (ref) => ref.watch(tabsProvider).activeId,
);

final activeProjectProvider = Provider<Project?>(
  (ref) => ref.watch(tabsProvider).active?.project,
);
