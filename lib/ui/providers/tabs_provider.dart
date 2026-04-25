import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  List<TabState> get state => List.unmodifiable(_tabs);
  String? get activeId => _activeId;
  TabState? get active =>
      _tabs.firstWhereOrNull((t) => t.id == _activeId);

  // === Tab lifecycle ===

  void newUntitled() {
    final id = _uuid();
    final p0 = Project.create(id: id, name: '새 프로젝트');
    _tabs = [..._tabs, TabState(id: id, filePath: null, project: p0, isDirty: false)];
    _activeId = id;
    notifyListeners();
  }

  Future<void> openFile(String path) async {
    final existing = _tabs.firstWhereOrNull((t) => t.filePath == path);
    if (existing != null) {
      _activeId = existing.id;
      notifyListeners();
      return;
    }
    final project = await files.read(path);
    final id = _uuid();
    _tabs = [
      ..._tabs,
      TabState(id: id, filePath: path, project: project, isDirty: false),
    ];
    _activeId = id;
    await workspace.touchRecentFile(path, project.name);
    notifyListeners();
  }

  void setActive(String id) {
    if (_tabs.any((t) => t.id == id)) {
      _activeId = id;
      notifyListeners();
    }
  }

  Future<void> closeTab(String id) async {
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

    _tabs = _tabs.where((t) => t.id != id).toList();
    if (_activeId == id) {
      _activeId = _tabs.isNotEmpty ? _tabs.last.id : null;
    }
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
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
    _tabs = _tabs.map((t) {
      if (t.id != id) return t;
      return f(t).copyWith(isDirty: true);
    }).toList();
    notifyListeners();
    _scheduleSave(id);
  }

  // === Persistence ===

  Future<String?> saveAs(String id, {String? overrideName}) async {
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return null;
    _saveTimers.remove(id)?.cancel();

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
    _setTab(id, (t) => t.copyWith(isDirty: false));
  }

  Future<void> flushAll() async {
    for (final id in _saveTimers.keys.toList()) {
      _saveTimers.remove(id)?.cancel();
      await _persist(id);
    }
  }

  void _setTab(String id, TabState Function(TabState) f) {
    _tabs = _tabs.map((t) => t.id == id ? f(t) : t).toList();
    notifyListeners();
  }

  String _uuid() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_tabs.length}';

  @override
  void dispose() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    _saveTimers.clear();
    super.dispose();
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
