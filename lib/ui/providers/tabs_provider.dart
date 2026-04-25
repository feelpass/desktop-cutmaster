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

/// 외부 mtime 충돌로 인해 분기 저장된 사실을 UI 측에 알리기 위한 메시지.
/// Task 19에서 SnackBar 등으로 surface 된다.
@immutable
class ConflictNotice {
  final String tabId;
  final String originalPath;
  final String forkPath;
  const ConflictNotice({
    required this.tabId,
    required this.originalPath,
    required this.forkPath,
  });
}

@immutable
class TabState {
  final String id;
  final String? filePath;
  final Project project;
  final bool isDirty;

  /// 마지막으로 read/write 한 시점에 기록된 디스크 mtime.
  /// 외부 편집기(Dropbox/iCloud)가 사이에 파일을 수정했는지를
  /// [_persist]에서 판정하는 데 쓰인다.
  final DateTime? mtime;
  const TabState({
    required this.id,
    required this.filePath,
    required this.project,
    required this.isDirty,
    this.mtime,
  });
  TabState copyWith({
    String? filePath,
    Project? project,
    bool? isDirty,
    DateTime? mtime,
    bool clearMtime = false,
  }) =>
      TabState(
        id: id,
        filePath: filePath ?? this.filePath,
        project: project ?? this.project,
        isDirty: isDirty ?? this.isDirty,
        mtime: clearMtime ? null : (mtime ?? this.mtime),
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

  /// 가장 최근에 발생한 외부 충돌 분기 알림 — Task 19에서 SnackBar로 surface.
  ConflictNotice? _lastConflict;
  ConflictNotice? get lastConflict => _lastConflict;
  void clearLastConflict() {
    _lastConflict = null;
  }

  final StreamController<String> _noticesCtrl =
      StreamController<String>.broadcast();

  /// 사용자에게 알릴 메시지 (SnackBar 등에 띄움).
  Stream<String> get notices => _noticesCtrl.stream;

  void _notify(String msg) {
    if (_disposed) return;
    if (!_noticesCtrl.isClosed) _noticesCtrl.add(msg);
  }

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
    final res = await files.readWithMtime(path);
    if (_disposed) return;
    final id = _newTabId();
    _tabs = [
      ..._tabs,
      TabState(
        id: id,
        filePath: path,
        project: res.project,
        isDirty: false,
        mtime: res.mtime,
      ),
    ];
    _activeId = id;
    await workspace.touchRecentFile(path, res.project.name);
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
      final newMtime = await files.overwrite(
        tab.filePath!,
        tab.project,
        expectedMtime: tab.mtime,
      );
      _setTab(id, (t) => t.copyWith(isDirty: false, mtime: newMtime));
      return tab.filePath;
    }

    final baseName = overrideName ?? tab.project.name;
    final path = await files.writeNew(
      folder: defaultProjectsDir,
      baseName: baseName,
      project: tab.project,
    );
    final mtime = await File(path).lastModified();

    final autosaveFile = File(p.join(autosaveDir, '${tab.id}.cutmaster'));
    if (autosaveFile.existsSync()) await autosaveFile.delete();

    await workspace.touchRecentFile(path, tab.project.name);
    _setTab(id,
        (t) => t.copyWith(filePath: path, isDirty: false, mtime: mtime));
    return path;
  }

  /// 현재 탭의 프로젝트를 복제하고 같은 폴더에 새 파일을 만들어 새 탭으로 연다.
  /// untitled 탭은 메모리 상에서만 복제 (untitled 새 탭).
  Future<String?> duplicateTab(String id) async {
    if (_disposed) return null;
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return null;

    if (tab.filePath == null) {
      // untitled — 메모리 복제
      final newProject = Project(
        id: _newProjectId(),
        name: '${tab.project.name} 사본',
        stocks: tab.project.stocks,
        parts: tab.project.parts,
        kerf: tab.project.kerf,
        grainLocked: tab.project.grainLocked,
        showPartLabels: tab.project.showPartLabels,
        useSingleSheet: tab.project.useSingleSheet,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tabId = _newTabId();
      _tabs = [
        ..._tabs,
        TabState(id: tabId, filePath: null, project: newProject, isDirty: true),
      ];
      _activeId = tabId;
      notifyListeners();
      _scheduleSave(tabId);
      return null;
    }

    // 저장된 탭 — 같은 폴더에 새 파일
    final folder = p.dirname(tab.filePath!);
    final newProject = Project(
      id: _newProjectId(),
      name: '${tab.project.name} 사본',
      stocks: tab.project.stocks,
      parts: tab.project.parts,
      kerf: tab.project.kerf,
      grainLocked: tab.project.grainLocked,
      showPartLabels: tab.project.showPartLabels,
      useSingleSheet: tab.project.useSingleSheet,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final newPath = await files.writeNew(
      folder: folder,
      baseName: '${tab.project.name} 사본',
      project: newProject,
    );
    final newMtime = await File(newPath).lastModified();
    if (_disposed) return newPath;
    final tabId = _newTabId();
    _tabs = [
      ..._tabs,
      TabState(
        id: tabId,
        filePath: newPath,
        project: newProject,
        isDirty: false,
        mtime: newMtime,
      ),
    ];
    _activeId = tabId;
    await workspace.touchRecentFile(newPath, newProject.name);
    if (_disposed) return newPath;
    notifyListeners();
    return newPath;
  }

  /// "다른 이름으로 저장..." — 현재 탭과는 별개로 새 파일을 만들고 그 파일을 새 탭으로 연다.
  Future<String?> saveAsCopy(String id, String newName) async {
    if (_disposed) return null;
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return null;

    final folder = tab.filePath != null
        ? p.dirname(tab.filePath!)
        : defaultProjectsDir;
    final newPath = await files.writeNew(
      folder: folder,
      baseName: newName,
      project: tab.project,
    );
    final newMtime = await File(newPath).lastModified();
    if (_disposed) return newPath;
    final tabId = _newTabId();
    _tabs = [
      ..._tabs,
      TabState(
        id: tabId,
        filePath: newPath,
        project: tab.project,
        isDirty: false,
        mtime: newMtime,
      ),
    ];
    _activeId = tabId;
    await workspace.touchRecentFile(newPath, tab.project.name);
    if (_disposed) return newPath;
    notifyListeners();
    return newPath;
  }

  /// 지정 id 외 모든 탭 닫기.
  Future<void> closeOthers(String keepId) async {
    if (_disposed) return;
    final ids = _tabs.where((t) => t.id != keepId).map((t) => t.id).toList();
    for (final id in ids) {
      await closeTab(id);
      if (_disposed) return;
    }
  }

  /// 탭의 이름 + (저장된 탭이면) 파일도 같이 rename.
  /// untitled 탭은 메모리 이름만 변경되고 [null]을 반환.
  /// 저장된 탭은 파일을 같은 폴더 내에서 rename + workspace recent 갱신, 새 경로를 반환.
  Future<String?> renameSavedFile(String id, String newName) async {
    if (_disposed) return null;
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null) return null;

    if (newName.trim().isEmpty) return null;
    final cleanName = ProjectFileService.sanitizeBaseName(newName);
    if (cleanName.isEmpty) return null;

    if (tab.filePath == null) {
      // untitled — 메모리만
      _setTab(id, (t) => t.copyWith(
            project: t.project.copyWith(name: cleanName),
            isDirty: true,
          ));
      _scheduleSave(id);
      return null;
    }

    // 저장된 탭
    final newPath = await files.rename(tab.filePath!, cleanName);
    final newMtime = await File(newPath).lastModified();
    if (_disposed) return newPath;
    _setTab(id, (t) => t.copyWith(
          filePath: newPath,
          project: t.project.copyWith(name: cleanName),
          isDirty: false,
          mtime: newMtime,
        ));
    await workspace.touchRecentFile(newPath, cleanName);
    if (tab.filePath != newPath) {
      // 옛 path가 recent에 남아있으면 정리
      await workspace.removeRecentFile(tab.filePath!);
    }
    return newPath;
  }

  void _scheduleSave(String id) {
    _saveTimers.remove(id)?.cancel();
    _saveTimers[id] = Timer(saveDebounce, () => _persist(id));
  }

  Future<void> _persist(String id) async {
    final tab = _tabs.firstWhereOrNull((t) => t.id == id);
    if (tab == null || !tab.isDirty) return;
    if (tab.filePath != null) {
      try {
        final newMtime = await files.overwrite(
          tab.filePath!,
          tab.project,
          expectedMtime: tab.mtime,
        );
        if (_disposed) return;
        _setTab(id, (t) => t.copyWith(isDirty: false, mtime: newMtime));
      } on ConflictException catch (e) {
        // 외부 편집기가 사이에 파일을 수정함 — 분기 저장 (fork)
        await _forkOnConflict(id, tab, e);
      }
    } else {
      await Directory(autosaveDir).create(recursive: true);
      // autosave 파일은 외부 편집 케어 대상이 아님 → mtime 검사 X
      await files.overwrite(
        p.join(autosaveDir, '${tab.id}.cutmaster'),
        tab.project,
      );
      if (_disposed) return;
      _setTab(id, (t) => t.copyWith(isDirty: false));
    }
  }

  Future<void> _forkOnConflict(
    String id,
    TabState tab,
    ConflictException e,
  ) async {
    final originalPath = tab.filePath!;
    final folder = p.dirname(originalPath);
    final currentBase = p.basenameWithoutExtension(originalPath);
    final forkBase = '$currentBase (충돌 사본)';
    try {
      final forkPath = await files.writeNew(
        folder: folder,
        baseName: forkBase,
        project: tab.project,
      );
      final forkMtime = await File(forkPath).lastModified();
      if (_disposed) return;
      _setTab(
        id,
        (t) => t.copyWith(
          filePath: forkPath,
          isDirty: false,
          mtime: forkMtime,
        ),
      );
      await workspace.touchRecentFile(forkPath, tab.project.name);
      _lastConflict = ConflictNotice(
        tabId: id,
        originalPath: originalPath,
        forkPath: forkPath,
      );
      debugPrint(
        'tab "$id" forked due to mtime conflict: $originalPath '
        '(expected ${e.expected}, found ${e.found}) -> $forkPath',
      );
      _notify('${tab.project.name}이 외부에서 변경되어 "충돌 사본"으로 분기 저장됨');
      notifyListeners();
    } catch (err) {
      debugPrint('fork-on-conflict failed for tab "$id": $err');
    }
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
        DateTime? mtime;
        if (r.filePath != null && File(r.filePath!).existsSync()) {
          final res = await files.readWithMtime(r.filePath!);
          pr = res.project;
          mtime = res.mtime;
        } else {
          final autosavePath = p.join(autosaveDir, '${r.id}.cutmaster');
          if (!File(autosavePath).existsSync()) {
            _notify('${r.displayName}을 찾을 수 없어요');
            continue; // 고아 — 스킵
          }
          // autosave는 충돌 검사 대상이 아니므로 mtime은 보관하지 않는다.
          pr = await files.read(autosavePath);
        }
        loaded.add(TabState(
          id: r.id,
          filePath: r.filePath,
          project: pr,
          isDirty: false,
          mtime: mtime,
        ));
        if (r.isActive) activeId = r.id;
      } catch (e) {
        // 손상 / 권한 — 그 탭만 스킵
        _notify('${r.displayName}을 열 수 없어요: $e');
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
    try {
      await workspace.replaceAllTabs(rows);
    } catch (e) {
      debugPrint('saveSession failed: $e');
    }
  }

  /// 가장 최근에 닫힌 탭을 다시 연다. 파일이면 그 경로로, untitled이면
  /// autosave 파일에서 복원. 복원 후 closed_tab row는 제거된 상태.
  Future<bool> reopenLastClosed() async {
    if (_disposed) return false;
    final row = await workspace.popLastClosedTab();
    if (row == null) return false;

    try {
      if (row.filePath != null && File(row.filePath!).existsSync()) {
        await openFile(row.filePath!);
        return true;
      }
      if (row.autosavePath != null && File(row.autosavePath!).existsSync()) {
        final project = await files.read(row.autosavePath!);
        if (_disposed) return true;
        final id = _newTabId();
        _tabs = [
          ..._tabs,
          TabState(id: id, filePath: null, project: project, isDirty: true),
        ];
        _activeId = id;
        notifyListeners();
        _scheduleSave(id);
        return true;
      }
    } catch (_) {
      // 손상 / 권한 — 그냥 무시
    }
    return false;
  }

  void cycleNext() {
    if (_disposed || _tabs.isEmpty) return;
    final idx = _tabs.indexWhere((t) => t.id == _activeId);
    final next = (idx + 1) % _tabs.length;
    _activeId = _tabs[next].id;
    notifyListeners();
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
    _noticesCtrl.close();
    super.dispose();
  }
}

// === Riverpod providers ===

/// 앱 라이프사이클에 1회 생성된 [TabsNotifier].
///
/// `main.dart`의 `ProviderScope` `overrides`에서 반드시 주입되어야 한다 —
/// 그렇지 않으면 첫 사용 시 [UnimplementedError]가 던져진다.
final tabsProvider = ChangeNotifierProvider<TabsNotifier>(
  (ref) => throw UnimplementedError(
      'tabsProvider must be overridden in main.dart ProviderScope'),
);

final activeTabIdProvider = Provider<String?>(
  (ref) => ref.watch(tabsProvider).activeId,
);

final activeProjectProvider = Provider<Project?>(
  (ref) => ref.watch(tabsProvider).active?.project,
);
