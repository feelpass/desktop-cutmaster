# 멀티 탭 + 파일 기반 프로젝트 저장 — 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** cutmaster를 단일 프로젝트 dropdown UI에서 멀티 탭 + `.cutmaster` 파일 기반 저장 워크스페이스로 전환한다.

**Architecture:** 프로젝트 데이터는 `~/Documents/Cutmaster/<name>.cutmaster` JSON 파일로 저장. 탭 / 최근 파일 / 닫힌 탭 메타는 작은 SQLite (`workspace.db`)로 분리. Untitled 탭은 `~/Library/Application Support/cutmaster/autosave/<tabId>.cutmaster`에 자동 백업. 마지막 세션 복원, 닫은 탭 복원, atomic write, mtime 충돌 감지로 데이터 안전.

**Tech Stack:** Flutter 3.x / Dart 3.10+ / Riverpod 2.5 / sqflite_common_ffi 2.3 / file_picker 8 / path_provider 2

**Design doc:** `docs/plans/2026-04-25-multi-tab-projects-design.md`

---

## 일반 규칙

- TDD: 각 task는 실패 테스트 → 구현 → 통과 확인 → commit
- DRY / YAGNI / 한 task = 1 commit
- 모든 명령은 프로젝트 루트(`/Users/youngpillee/workspace/desktop/cutmaster`)에서 실행
- 테스트: `flutter test <path>` / 전체: `flutter test`
- 한국어 주석 / UI 텍스트
- 파일 IO는 모두 async. UI 차단 금지

---

## Task 1: Project 모델에 toJson/fromJson 추가

**Why:** 파일 저장은 Project를 통째로 JSON 직렬화한다. 현재는 `project_db.dart`가 인라인으로 처리. 모델에 옮겨 ProjectFile 서비스에서 재사용.

**Files:**
- Modify: `lib/domain/models/project.dart`
- Test: `test/domain/models/project_json_test.dart` (새로 생성)

**Step 1: Write failing test**

`test/domain/models/project_json_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  test('Project.toJson / fromJson roundtrip preserves all fields', () {
    final orig = Project.create(id: 'p1', name: '책장').copyWith(
      stocks: [
        const StockSheet(
          id: 's1', length: 2440, width: 1220, qty: 2,
          label: '12T', grainDirection: GrainDirection.lengthwise,
          colorArgb: 0xFF995533,
        ),
      ],
      parts: [
        const CutPart(
          id: 'pa1', length: 600, width: 400, qty: 4,
          label: '문짝', grainDirection: GrainDirection.widthwise,
        ),
      ],
      kerf: 5,
      grainLocked: true,
      showPartLabels: false,
      useSingleSheet: true,
    );

    final json = orig.toJson();
    expect(json['schemaVersion'], 1);

    final back = Project.fromJson(json);
    expect(back.id, orig.id);
    expect(back.name, orig.name);
    expect(back.stocks, orig.stocks);
    expect(back.parts, orig.parts);
    expect(back.kerf, orig.kerf);
    expect(back.grainLocked, orig.grainLocked);
    expect(back.showPartLabels, orig.showPartLabels);
    expect(back.useSingleSheet, orig.useSingleSheet);
    expect(back.createdAt, orig.createdAt);
  });

  test('fromJson rejects unknown future schemaVersion', () {
    expect(
      () => Project.fromJson({'schemaVersion': 999, 'id': 'x', 'name': 'y'}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/domain/models/project_json_test.dart`
Expected: `Project.toJson` / `Project.fromJson` not defined.

**Step 3: Implement**

`lib/domain/models/project.dart` — 클래스 끝에 추가:

```dart
  static const int schemaVersion = 1;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'kerf': kerf,
        'grainLocked': grainLocked,
        'showPartLabels': showPartLabels,
        'useSingleSheet': useSingleSheet,
        'stocks': stocks.map((s) => s.toJson()).toList(),
        'parts': parts.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> j) {
    final v = j['schemaVersion'] as int? ?? 1;
    if (v > schemaVersion) {
      throw FormatException('Unsupported schemaVersion: $v');
    }
    return Project(
      id: j['id'] as String,
      name: j['name'] as String,
      stocks: ((j['stocks'] as List?) ?? const [])
          .map((e) => StockSheet.fromJson(e as Map<String, dynamic>))
          .toList(),
      parts: ((j['parts'] as List?) ?? const [])
          .map((e) => CutPart.fromJson(e as Map<String, dynamic>))
          .toList(),
      kerf: ((j['kerf'] as num?) ?? 3).toDouble(),
      grainLocked: (j['grainLocked'] as bool?) ?? false,
      showPartLabels: (j['showPartLabels'] as bool?) ?? true,
      useSingleSheet: (j['useSingleSheet'] as bool?) ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String? ??
          DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(j['updatedAt'] as String? ??
          DateTime.now().toIso8601String()),
    );
  }
```

**Step 4: Run — expect pass**

`flutter test test/domain/models/project_json_test.dart`
Expected: 2 tests pass.

**Step 5: Commit**

```bash
git add lib/domain/models/project.dart test/domain/models/project_json_test.dart
git commit -m "feat(domain): Project.toJson/fromJson with schemaVersion"
```

---

## Task 2: ProjectFile 서비스 (atomic write + 충돌 suffix)

**Why:** 파일 IO 계층. 모든 read/write가 한 곳을 통과해 atomic + 충돌 처리 일관성.

**Files:**
- Create: `lib/data/file/project_file.dart`
- Test: `test/data/file/project_file_test.dart`

**Step 1: Write failing test**

`test/data/file/project_file_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/domain/models/project.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cutmaster_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('writeNew creates file and returns chosen path', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    expect(path, '${tmp.path}/책장.cutmaster');
    expect(File(path).existsSync(), true);

    final loaded = await svc.read(path);
    expect(loaded.name, '책장');
  });

  test('writeNew adds (2) suffix on collision', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');

    final p1 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);
    final p2 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    expect(p1, '${tmp.path}/책장.cutmaster');
    expect(p2, '${tmp.path}/책장 (2).cutmaster');
  });

  test('overwrite is atomic (no .tmp left behind)', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    final p2 = p.copyWith(kerf: 7);
    await svc.overwrite(path, p2);

    final loaded = await svc.read(path);
    expect(loaded.kerf, 7);

    final tmpFiles = tmp.listSync().where((f) => f.path.endsWith('.tmp'));
    expect(tmpFiles, isEmpty);
  });

  test('rename moves file with suffix on collision', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');
    final pathA = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);
    await svc.writeNew(folder: tmp.path, baseName: '책상', project: p);

    final newPath = await svc.rename(pathA, '책상');
    expect(newPath, '${tmp.path}/책상 (2).cutmaster');
    expect(File(pathA).existsSync(), false);
  });

  test('read throws FormatException on corrupt JSON', () async {
    final f = File('${tmp.path}/bad.cutmaster')..writeAsStringSync('not json');
    expect(
      () => ProjectFileService().read(f.path),
      throwsA(isA<FormatException>()),
    );
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/data/file/project_file_test.dart`
Expected: `ProjectFileService` not found.

**Step 3: Implement**

`lib/data/file/project_file.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/project.dart';

const _ext = '.cutmaster';
const _kForbidden = r'/\:*?"<>|';

class ProjectFileService {
  /// 같은 폴더 안에서 충돌 안 나는 경로를 만들어 [project]를 새 파일로 쓴다.
  /// 반환: 실제로 쓰인 절대 경로.
  Future<String> writeNew({
    required String folder,
    required String baseName,
    required Project project,
  }) async {
    await Directory(folder).create(recursive: true);
    final path = await _resolveCollision(folder, baseName);
    await _atomicWrite(path, project);
    return path;
  }

  /// 같은 경로에 atomic으로 덮어쓴다.
  Future<void> overwrite(String path, Project project) async {
    await _atomicWrite(path, project);
  }

  /// 파일 한 개를 같은 폴더 안에서 새 baseName으로 rename. 충돌 시 (2) suffix.
  /// 반환: 새 경로.
  Future<String> rename(String path, String newBaseName) async {
    final folder = p.dirname(path);
    final newPath = await _resolveCollision(folder, newBaseName);
    if (newPath == path) return path;
    await File(path).rename(newPath);
    return newPath;
  }

  /// 파일에서 Project 로드. JSON / schemaVersion 손상 시 FormatException.
  Future<Project> read(String path) async {
    final raw = await File(path).readAsString();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Project.fromJson(j);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid .cutmaster: $e');
    }
  }

  /// 파일명으로 안전한 형태로 [name] 정규화 (금지 문자 제거).
  static String sanitizeBaseName(String name) {
    var s = name.trim();
    for (final c in _kForbidden.split('')) {
      s = s.replaceAll(c, '');
    }
    if (s.isEmpty) s = '새 프로젝트';
    return s;
  }

  Future<String> _resolveCollision(String folder, String baseName) async {
    final clean = sanitizeBaseName(baseName);
    var path = p.join(folder, '$clean$_ext');
    if (!File(path).existsSync()) return path;
    var i = 2;
    while (true) {
      path = p.join(folder, '$clean ($i)$_ext');
      if (!File(path).existsSync()) return path;
      i++;
    }
  }

  Future<void> _atomicWrite(String path, Project project) async {
    final tmp = '$path.tmp';
    final raw = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await File(tmp).writeAsString(raw, flush: true);
    await File(tmp).rename(path);
  }
}
```

**Step 4: Run — expect pass**

`flutter test test/data/file/project_file_test.dart`
Expected: 5 tests pass.

**Step 5: Commit**

```bash
git add lib/data/file/project_file.dart test/data/file/project_file_test.dart
git commit -m "feat(data): ProjectFileService with atomic write + collision suffix"
```

---

## Task 3: WorkspaceDb 스키마 + tab CRUD

**Why:** 탭 / 최근 / 닫힌 탭 메타를 영속화. autosave는 폴더 기반이지만 메타는 SQLite가 적합 (정렬 / LRU).

**Files:**
- Create: `lib/data/local/workspace_db.dart`
- Test: `test/data/local/workspace_db_test.dart`

**Step 1: Write failing test**

`test/data/local/workspace_db_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/local/workspace_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('tab CRUD: insert, list ordered, update, delete', () async {
    final db = await WorkspaceDb.openInMemory();

    await db.upsertTab(const TabRow(
      id: 't1', filePath: '/x/a.cutmaster',
      displayName: 'a', position: 0, isActive: false,
    ));
    await db.upsertTab(const TabRow(
      id: 't2', filePath: null,
      displayName: '새 프로젝트', position: 1, isActive: true,
    ));

    final list = await db.listTabs();
    expect(list.map((t) => t.id), ['t1', 't2']);
    expect(list[1].isActive, true);

    await db.deleteTab('t1');
    expect((await db.listTabs()).length, 1);

    await db.close();
  });

  test('recent_file LRU caps at 20 most recent', () async {
    final db = await WorkspaceDb.openInMemory();
    for (var i = 0; i < 25; i++) {
      await db.touchRecentFile('/x/$i.cutmaster', 'p$i');
    }
    final list = await db.listRecentFiles();
    expect(list.length, 20);
    expect(list.first.filePath, '/x/24.cutmaster'); // 최신 먼저
    await db.close();
  });

  test('closed_tab push / pop / prune older than 30 days', () async {
    final db = await WorkspaceDb.openInMemory();
    final old = DateTime.now().subtract(const Duration(days: 31));
    await db.pushClosedTab(ClosedTabRow(
      tabId: 'old', filePath: null,
      autosavePath: '/a/old.cutmaster', displayName: '옛것', closedAt: old,
    ));
    await db.pushClosedTab(ClosedTabRow(
      tabId: 'new', filePath: '/x/n.cutmaster',
      autosavePath: null, displayName: '새것', closedAt: DateTime.now(),
    ));

    await db.pruneClosedTabs(maxAgeDays: 30, keepAtMost: 50);
    final list = await db.listClosedTabs();
    expect(list.map((t) => t.tabId), ['new']);

    final popped = await db.popLastClosedTab();
    expect(popped!.tabId, 'new');
    expect((await db.listClosedTabs()), isEmpty);

    await db.close();
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/data/local/workspace_db_test.dart`
Expected: `WorkspaceDb` not defined.

**Step 3: Implement**

`lib/data/local/workspace_db.dart`:

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TabRow {
  final String id;
  final String? filePath;
  final String displayName;
  final int position;
  final bool isActive;
  const TabRow({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.position,
    required this.isActive,
  });
}

class RecentFileRow {
  final String filePath;
  final String displayName;
  final DateTime lastOpenedAt;
  const RecentFileRow({
    required this.filePath,
    required this.displayName,
    required this.lastOpenedAt,
  });
}

class ClosedTabRow {
  final String tabId;
  final String? filePath;
  final String? autosavePath;
  final String displayName;
  final DateTime closedAt;
  const ClosedTabRow({
    required this.tabId,
    required this.filePath,
    required this.autosavePath,
    required this.displayName,
    required this.closedAt,
  });
}

/// 워크스페이스 메타 (열린 탭, 최근 파일, 닫힌 탭).
/// 프로젝트 데이터는 .cutmaster 파일에 별도 저장.
class WorkspaceDb {
  final Database _db;
  WorkspaceDb._(this._db);

  static Future<WorkspaceDb> openInMemory() => _open(inMemoryDatabasePath);
  static Future<WorkspaceDb> open(String path) => _open(path);

  static Future<WorkspaceDb> _open(String path) async {
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return WorkspaceDb._(db);
  }

  static Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE tab (
        id TEXT PRIMARY KEY,
        file_path TEXT,
        display_name TEXT NOT NULL,
        position INTEGER NOT NULL,
        is_active INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recent_file (
        file_path TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        last_opened_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE closed_tab (
        tab_id TEXT PRIMARY KEY,
        file_path TEXT,
        autosave_path TEXT,
        display_name TEXT NOT NULL,
        closed_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() => _db.close();

  // === Tabs ===

  Future<void> upsertTab(TabRow t) => _db.insert(
        'tab',
        {
          'id': t.id,
          'file_path': t.filePath,
          'display_name': t.displayName,
          'position': t.position,
          'is_active': t.isActive ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<TabRow>> listTabs() async {
    final rows = await _db.query('tab', orderBy: 'position ASC');
    return rows.map(_toTabRow).toList();
  }

  Future<void> deleteTab(String id) =>
      _db.delete('tab', where: 'id = ?', whereArgs: [id]);

  Future<void> replaceAllTabs(List<TabRow> tabs) async {
    await _db.transaction((tx) async {
      await tx.delete('tab');
      for (final t in tabs) {
        await tx.insert('tab', {
          'id': t.id,
          'file_path': t.filePath,
          'display_name': t.displayName,
          'position': t.position,
          'is_active': t.isActive ? 1 : 0,
        });
      }
    });
  }

  // === Recent files ===

  Future<void> touchRecentFile(String filePath, String displayName) async {
    await _db.insert(
      'recent_file',
      {
        'file_path': filePath,
        'display_name': displayName,
        'last_opened_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // LRU 20개 유지
    final all = await _db.query('recent_file', orderBy: 'last_opened_at DESC');
    if (all.length > 20) {
      final toDelete = all.skip(20).map((r) => r['file_path']).toList();
      for (final fp in toDelete) {
        await _db.delete('recent_file', where: 'file_path = ?', whereArgs: [fp]);
      }
    }
  }

  Future<void> removeRecentFile(String filePath) =>
      _db.delete('recent_file', where: 'file_path = ?', whereArgs: [filePath]);

  Future<List<RecentFileRow>> listRecentFiles() async {
    final rows = await _db.query('recent_file', orderBy: 'last_opened_at DESC');
    return rows.map(_toRecentRow).toList();
  }

  // === Closed tabs ===

  Future<void> pushClosedTab(ClosedTabRow c) => _db.insert(
        'closed_tab',
        {
          'tab_id': c.tabId,
          'file_path': c.filePath,
          'autosave_path': c.autosavePath,
          'display_name': c.displayName,
          'closed_at': c.closedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<ClosedTabRow?> popLastClosedTab() async {
    final rows = await _db.query('closed_tab',
        orderBy: 'closed_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    await _db.delete('closed_tab',
        where: 'tab_id = ?', whereArgs: [row['tab_id']]);
    return _toClosedRow(row);
  }

  Future<List<ClosedTabRow>> listClosedTabs() async {
    final rows = await _db.query('closed_tab', orderBy: 'closed_at DESC');
    return rows.map(_toClosedRow).toList();
  }

  Future<List<ClosedTabRow>> pruneClosedTabs({
    required int maxAgeDays,
    required int keepAtMost,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays));
    final removed = await _db.query('closed_tab',
        where: 'closed_at < ?', whereArgs: [cutoff.toIso8601String()]);
    await _db.delete('closed_tab',
        where: 'closed_at < ?', whereArgs: [cutoff.toIso8601String()]);

    final remaining = await _db.query('closed_tab', orderBy: 'closed_at DESC');
    if (remaining.length > keepAtMost) {
      final overflow = remaining.skip(keepAtMost).toList();
      for (final r in overflow) {
        removed.add(r);
        await _db.delete('closed_tab',
            where: 'tab_id = ?', whereArgs: [r['tab_id']]);
      }
    }
    return removed.map(_toClosedRow).toList();
  }

  // === mappers ===

  TabRow _toTabRow(Map<String, Object?> r) => TabRow(
        id: r['id'] as String,
        filePath: r['file_path'] as String?,
        displayName: r['display_name'] as String,
        position: r['position'] as int,
        isActive: r['is_active'] == 1,
      );

  RecentFileRow _toRecentRow(Map<String, Object?> r) => RecentFileRow(
        filePath: r['file_path'] as String,
        displayName: r['display_name'] as String,
        lastOpenedAt: DateTime.parse(r['last_opened_at'] as String),
      );

  ClosedTabRow _toClosedRow(Map<String, Object?> r) => ClosedTabRow(
        tabId: r['tab_id'] as String,
        filePath: r['file_path'] as String?,
        autosavePath: r['autosave_path'] as String?,
        displayName: r['display_name'] as String,
        closedAt: DateTime.parse(r['closed_at'] as String),
      );
}
```

**Step 4: Run — expect pass**

`flutter test test/data/local/workspace_db_test.dart`
Expected: 3 tests pass.

**Step 5: Commit**

```bash
git add lib/data/local/workspace_db.dart test/data/local/workspace_db_test.dart
git commit -m "feat(data): WorkspaceDb (tab/recent/closed_tab) v1 schema"
```

---

## Task 4: 마이그레이션 — 옛 ProjectDb → 파일들

**Why:** 기존 사용자가 갖고 있던 `cutmaster.db` 안의 모든 프로젝트를 `~/Documents/Cutmaster/`에 export하고 recent_file에 등록.

**Files:**
- Create: `lib/data/migration/legacy_to_files.dart`
- Test: `test/data/migration/legacy_to_files_test.dart`

**Step 1: Write failing test**

`test/data/migration/legacy_to_files_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/local/project_db.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/data/migration/legacy_to_files.dart';
import 'package:cutmaster/domain/models/project.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migrates each project to .cutmaster file and registers as recent', () async {
    final tmp = await Directory.systemTemp.createTemp('mig_');
    final legacy = await ProjectDb.openInMemory();
    final ws = await WorkspaceDb.openInMemory();

    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책상'));

    final result =
        await LegacyMigrator(legacy: legacy, workspace: ws, targetFolder: tmp.path)
            .run();

    expect(result.migrated, 2);
    expect(result.failed, 0);
    expect(File('${tmp.path}/책장.cutmaster').existsSync(), true);
    expect(File('${tmp.path}/책상.cutmaster').existsSync(), true);

    final recent = await ws.listRecentFiles();
    expect(recent.length, 2);

    await tmp.delete(recursive: true);
  });

  test('handles name collisions with (2) suffix', () async {
    final tmp = await Directory.systemTemp.createTemp('mig_');
    final legacy = await ProjectDb.openInMemory();
    final ws = await WorkspaceDb.openInMemory();

    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책장'));

    final result =
        await LegacyMigrator(legacy: legacy, workspace: ws, targetFolder: tmp.path)
            .run();

    expect(result.migrated, 2);
    expect(File('${tmp.path}/책장.cutmaster').existsSync(), true);
    expect(File('${tmp.path}/책장 (2).cutmaster').existsSync(), true);

    await tmp.delete(recursive: true);
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/data/migration/legacy_to_files_test.dart`
Expected: `LegacyMigrator` not found.

**Step 3: Implement**

`lib/data/migration/legacy_to_files.dart`:

```dart
import '../file/project_file.dart';
import '../local/project_db.dart';
import '../local/workspace_db.dart';

class MigrationResult {
  final int migrated;
  final int failed;
  const MigrationResult(this.migrated, this.failed);
}

/// 옛 ProjectDb의 모든 프로젝트를 [targetFolder]에 .cutmaster 파일로 export하고
/// WorkspaceDb의 recent_file에 등록한다. 옛 DB는 read-only로 두고 건드리지 않는다.
class LegacyMigrator {
  LegacyMigrator({
    required this.legacy,
    required this.workspace,
    required this.targetFolder,
    ProjectFileService? files,
  }) : files = files ?? ProjectFileService();

  final ProjectDb legacy;
  final WorkspaceDb workspace;
  final String targetFolder;
  final ProjectFileService files;

  Future<MigrationResult> run() async {
    final projects = await legacy.listProjects();
    var ok = 0, fail = 0;
    for (final p in projects) {
      try {
        final path = await files.writeNew(
          folder: targetFolder,
          baseName: p.name,
          project: p,
        );
        await workspace.touchRecentFile(path, p.name);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    return MigrationResult(ok, fail);
  }
}
```

**Step 4: Run — expect pass**

`flutter test test/data/migration/legacy_to_files_test.dart`
Expected: 2 tests pass.

**Step 5: Commit**

```bash
git add lib/data/migration/legacy_to_files.dart test/data/migration/legacy_to_files_test.dart
git commit -m "feat(migration): legacy ProjectDb -> .cutmaster files + recent registry"
```

---

## Task 5: TabState 모델 + TabsNotifier (탭 CRUD + 더티 / autosave)

**Why:** 워크스페이스의 핵심 상태. 모든 탭 변경의 진입점.

**Files:**
- Create: `lib/ui/providers/tabs_provider.dart`
- Test: `test/ui/providers/tabs_notifier_test.dart`

**Step 1: Write failing test**

`test/ui/providers/tabs_notifier_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late WorkspaceDb ws;
  late TabsNotifier notifier;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tabs_');
    ws = await WorkspaceDb.openInMemory();
    notifier = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: '${tmp.path}/autosave',
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
  });

  tearDown(() async {
    notifier.dispose();
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('newUntitled appends a tab with no filePath, isDirty=false', () {
    notifier.newUntitled();
    expect(notifier.state.length, 1);
    expect(notifier.state.first.filePath, null);
    expect(notifier.state.first.isDirty, false);
  });

  test('updateName marks dirty and updates project.name', () async {
    notifier.newUntitled();
    final id = notifier.state.first.id;
    notifier.updateName(id, '책장');
    expect(notifier.state.first.project.name, '책장');
    expect(notifier.state.first.isDirty, true);
  });

  test('saveAs writes file, clears autosave, registers recent', () async {
    notifier.newUntitled();
    final id = notifier.state.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    expect(path, '${tmp.path}/책장.cutmaster');
    expect(File(path!).existsSync(), true);

    final tab = notifier.state.first;
    expect(tab.filePath, path);
    expect(tab.isDirty, false);

    final recent = await ws.listRecentFiles();
    expect(recent.first.filePath, path);
  });

  test('openFile focuses existing tab if path already open', () async {
    notifier.newUntitled();
    final id = notifier.state.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    notifier.newUntitled(); // 탭 2개
    expect(notifier.state.length, 2);

    await notifier.openFile(path!);
    expect(notifier.state.length, 2);
    expect(notifier.activeId, id);
  });

  test('closeTab removes tab and pushes to closed_tab', () async {
    notifier.newUntitled();
    final id = notifier.state.first.id;
    await notifier.closeTab(id);
    expect(notifier.state, isEmpty);

    final closed = await ws.listClosedTabs();
    expect(closed.length, 1);
    expect(closed.first.tabId, id);
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/ui/providers/tabs_notifier_test.dart`
Expected: `TabsNotifier` not found.

**Step 3: Implement**

`lib/ui/providers/tabs_provider.dart`:

```dart
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

  // === Project edits (활성 탭 기준) ===

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
```

**Step 4: Run — expect pass**

`flutter test test/ui/providers/tabs_notifier_test.dart`
Expected: 5 tests pass.

**Step 5: Commit**

```bash
git add lib/ui/providers/tabs_provider.dart test/ui/providers/tabs_notifier_test.dart
git commit -m "feat(state): TabsNotifier with autosave + closeTab + open/save"
```

---

## Task 6: Riverpod 통합 (workspaceDbProvider, tabsProvider, activeProjectProvider)

**Why:** Notifier를 Riverpod 그래프에 연결. 위젯 layer가 의존할 진입점.

**Files:**
- Modify: `lib/ui/providers/db_provider.dart` (workspaceDbProvider 추가)
- Modify: `lib/ui/providers/tabs_provider.dart` (Riverpod provider 끝에 추가)
- Modify: `lib/main.dart` (앱 시작 시 마이그레이션 + 초기 탭 복원)

**Step 1: Add provider exports**

`lib/ui/providers/db_provider.dart` — 기존 dbProvider 아래 추가:

```dart
import '../../data/local/workspace_db.dart';

final workspaceDbProvider = FutureProvider<WorkspaceDb>((ref) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = await getApplicationSupportDirectory();
  return WorkspaceDb.open(p.join(dir.path, 'workspace.db'));
});
```

`lib/ui/providers/tabs_provider.dart` — 파일 끝에 추가:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/file/project_file.dart';
import 'db_provider.dart';

/// 앱 라이프사이클에 1회 생성. dispose는 Riverpod 자동 처리.
final tabsProvider =
    ChangeNotifierProvider<TabsNotifier>((ref) => throw UnimplementedError(
        '`tabsProvider`는 main.dart의 ProviderScope overrides에서 주입됩니다.'));

final activeTabIdProvider = StateProvider<String?>(
  (ref) => ref.watch(tabsProvider).activeId,
);

final activeProjectProvider = Provider<Project?>((ref) {
  final tabs = ref.watch(tabsProvider);
  return tabs.active?.project;
});
```

**Step 2: Wire in main.dart**

`lib/main.dart` 전체 교체:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/file/project_file.dart';
import 'data/local/project_db.dart';
import 'data/local/workspace_db.dart';
import 'data/migration/legacy_to_files.dart';
import 'l10n/app_localizations.dart';
import 'ui/main_screen.dart';
import 'ui/providers/tabs_provider.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final docsDir = await getApplicationDocumentsDirectory();
  final projectsDir = p.join(docsDir.path, 'Cutmaster');
  final autosaveDir = p.join(supportDir.path, 'autosave');
  await Directory(projectsDir).create(recursive: true);
  await Directory(autosaveDir).create(recursive: true);

  final ws = await WorkspaceDb.open(p.join(supportDir.path, 'workspace.db'));

  // 한 번만 마이그레이션 (옛 cutmaster.db 발견 + recent_file 비어 있으면)
  final legacyPath = p.join(supportDir.path, 'cutmaster.db');
  if (File(legacyPath).existsSync() &&
      (await ws.listRecentFiles()).isEmpty) {
    final legacy = await ProjectDb.open(legacyPath);
    await LegacyMigrator(
      legacy: legacy,
      workspace: ws,
      targetFolder: projectsDir,
    ).run();
    await legacy.close();
  }

  final notifier = TabsNotifier(
    workspace: ws,
    files: ProjectFileService(),
    autosaveDir: autosaveDir,
    defaultProjectsDir: projectsDir,
  );
  await notifier.restoreSession(); // Task 7에서 구현
  if (notifier.state.isEmpty) notifier.newUntitled();

  runApp(ProviderScope(
    overrides: [tabsProvider.overrideWith((_) => notifier)],
    child: const CutmasterApp(),
  ));
}

class CutmasterApp extends StatelessWidget {
  const CutmasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: const MainScreen(),
    );
  }
}
```

**Step 3: Run analyzer (still missing restoreSession — expected)**

`flutter analyze`
Expected: error on `restoreSession` (we add it in Task 7).

**Step 4: Commit (skip — will commit with Task 7)**

(이 task는 Task 7과 묶어서 커밋. 정상.)

---

## Task 7: 세션 복원 + 종료 flush

**Why:** 앱 시작 시 마지막 탭들 복원, 종료 시 debounce 즉시 flush + tab 테이블 동기화.

**Files:**
- Modify: `lib/ui/providers/tabs_provider.dart`
- Modify: `lib/main.dart` (앱 라이프사이클 hook)
- Test: `test/ui/providers/tabs_session_test.dart`

**Step 1: Write failing test**

`test/ui/providers/tabs_session_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('saveSession + restoreSession round-trip', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.openInMemory();
    final autosave = '${tmp.path}/autosave';

    var n1 = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: autosave,
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    n1.newUntitled();
    final id = n1.state.first.id;
    n1.updateName(id, '책장');
    final path = await n1.saveAs(id);

    n1.newUntitled(); // 두 번째 untitled
    final untitledId = n1.state.last.id;
    n1.updateName(untitledId, '도면 메모');
    await n1.flushAll();

    n1.setActive(untitledId);
    await n1.saveSession();
    n1.dispose();

    final n2 = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: autosave,
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n2.restoreSession();

    expect(n2.state.length, 2);
    expect(n2.state.firstWhere((t) => t.filePath == path).project.name, '책장');
    expect(n2.activeId, untitledId);
    expect(n2.state.firstWhere((t) => t.id == untitledId).project.name, '도면 메모');

    n2.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/ui/providers/tabs_session_test.dart`
Expected: `restoreSession` / `saveSession` not defined.

**Step 3: Implement**

`lib/ui/providers/tabs_provider.dart` — TabsNotifier 안에 추가:

```dart
  Future<void> restoreSession() async {
    final rows = await workspace.listTabs();
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
```

**Step 4: Run — expect pass**

`flutter test test/ui/providers/tabs_session_test.dart`
Expected: 1 test pass.

`flutter analyze` — no errors.

**Step 5: Wire app shutdown in main.dart**

`lib/main.dart` 의 `CutmasterApp` 을 `StatefulWidget` 으로 바꿔 `WidgetsBindingObserver` 로 lifecycle 처리.

```dart
class CutmasterApp extends ConsumerStatefulWidget {
  const CutmasterApp({super.key});
  @override
  ConsumerState<CutmasterApp> createState() => _CutmasterAppState();
}

class _CutmasterAppState extends ConsumerState<CutmasterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      final n = ref.read(tabsProvider);
      await n.flushAll();
      await n.saveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: const MainScreen(),
    );
  }
}
```

**Step 6: Commit**

```bash
git add lib/ui/providers/tabs_provider.dart lib/ui/providers/db_provider.dart lib/main.dart test/ui/providers/tabs_session_test.dart
git commit -m "feat(state): tabs Riverpod wiring + session save/restore"
```

---

## Task 8: 호출처 일괄 치환 — currentProjectProvider → tabs/active

**Why:** 위젯들이 옛 provider를 봐서 빌드가 깨진다. 활성 탭 기반으로 바꿔야 한다.

**Files:** (모두 modify)
- `lib/ui/widgets/stocks_table.dart`
- `lib/ui/widgets/parts_table.dart`
- `lib/ui/widgets/options_section.dart`
- `lib/ui/widgets/cutting_result_pane.dart`
- `lib/ui/providers/solver_provider.dart`

**Step 1: Read each file, replace pattern**

각 파일에서:

```dart
// 변경 전
ref.watch(currentProjectProvider)        →  ref.watch(activeProjectProvider)!
ref.read(currentProjectProvider)         →  ref.read(tabsProvider).active!.project
ref.read(currentProjectProvider.notifier).updateStocks(x)
                                          →  ref.read(tabsProvider).updateStocks(activeId, x)
```

`activeId` 는 `ref.read(tabsProvider).activeId!` 로 가져온다.

`solver_provider.dart`:
```dart
final project = ref.read(activeProjectProvider);
if (project == null) return;
```

`stocks_table.dart` 패치 예시:
```dart
final project = ref.watch(activeProjectProvider);
if (project == null) return const SizedBox.shrink();
final activeId = ref.read(tabsProvider).activeId!;
// ...
ref.read(tabsProvider).updateStocks(activeId, updated);
```

**Step 2: Run analyzer**

`flutter analyze`
Expected: no errors related to `currentProjectProvider`. (옛 import 제거 잊지 말 것.)

**Step 3: Run all tests**

`flutter test`
Expected: 위젯 테스트 외 모든 unit/widget 통과. (위젯 테스트가 깨지면 다음 task에서 처리)

**Step 4: Commit**

```bash
git add lib/ui lib/ui/providers/solver_provider.dart
git commit -m "refactor(ui): switch widgets to activeProjectProvider/tabsProvider"
```

---

## Task 9: 옛 위젯 / provider 삭제

**Why:** 사용처 모두 치환 끝났으니 dead code 정리.

**Files:**
- Delete: `lib/ui/widgets/project_dropdown.dart`
- Delete: `lib/ui/widgets/rename_project_dialog.dart`
- Delete: `lib/ui/providers/current_project_provider.dart`
- Modify: `lib/ui/widgets/top_bar.dart` (ProjectDropdown import / 사용 제거 — 임시 placeholder Spacer)

**Step 1: Verify no remaining references**

`grep -rn "currentProjectProvider\|ProjectDropdown\|RenameProjectDialog" lib/ test/`
Expected: 매치 0개 (또는 곧 지울 top_bar.dart의 import 1개)

**Step 2: Delete + clean import**

```bash
rm lib/ui/widgets/project_dropdown.dart
rm lib/ui/widgets/rename_project_dialog.dart
rm lib/ui/providers/current_project_provider.dart
```

`lib/ui/widgets/top_bar.dart` 에서 `ProjectDropdown` 자리에 `const Spacer()` 임시 삽입 (다음 task에 TabBar로 교체).

**Step 3: Run analyzer + tests**

`flutter analyze && flutter test`
Expected: 모두 통과.

**Step 4: Commit**

```bash
git add -A lib/
git commit -m "chore: remove ProjectDropdown / RenameProjectDialog / currentProjectProvider"
```

---

## Task 10: TabItem 위젯 (정적 + X 닫기 + untitled 점)

**Why:** 가장 작은 빌딩 블록부터. 인라인 편집은 다음 task에서 추가.

**Files:**
- Create: `lib/ui/widgets/tab_item.dart`
- Test: `test/ui/widgets/tab_item_test.dart`

**Step 1: Write failing widget test**

`test/ui/widgets/tab_item_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/ui/widgets/tab_item.dart';

void main() {
  testWidgets('shows display name and dirty dot when isDirty', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: true,
          isUntitled: false,
          onTap: () {},
          onClose: () {},
          onRenameSubmit: (_) {},
        ),
      ),
    ));
    expect(find.text('책장'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-dirty-dot')), findsOneWidget);
  });

  testWidgets('tapping X calls onClose', (t) async {
    var closed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: false,
          isUntitled: false,
          onTap: () {},
          onClose: () => closed = true,
          onRenameSubmit: (_) {},
        ),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('tab-close')));
    expect(closed, true);
  });
}
```

**Step 2: Run — expect fail**

`flutter test test/ui/widgets/tab_item_test.dart`

**Step 3: Implement**

`lib/ui/widgets/tab_item.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TabItem extends StatelessWidget {
  const TabItem({
    super.key,
    required this.displayName,
    required this.isActive,
    required this.isDirty,
    required this.isUntitled,
    required this.onTap,
    required this.onClose,
    required this.onRenameSubmit,
  });

  final String displayName;
  final bool isActive;
  final bool isDirty;
  final bool isUntitled;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String> onRenameSubmit;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? Colors.white : Colors.white24;
    final fg = isActive ? Colors.black87 : AppColors.textOnHeader;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Row(
          children: [
            if (isUntitled || isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  key: const ValueKey('tab-dirty-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              key: const ValueKey('tab-close'),
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 4: Run — expect pass**

`flutter test test/ui/widgets/tab_item_test.dart`

**Step 5: Commit**

```bash
git add lib/ui/widgets/tab_item.dart test/ui/widgets/tab_item_test.dart
git commit -m "feat(ui): TabItem widget (static, dirty dot, close button)"
```

---

## Task 11: TabItem 인라인 편집 (더블클릭 → TextField)

**Why:** 사용자 요구의 핵심 인터랙션.

**Files:**
- Modify: `lib/ui/widgets/tab_item.dart`
- Modify: `test/ui/widgets/tab_item_test.dart`

**Step 1: Write failing test (확장)**

`test/ui/widgets/tab_item_test.dart` 끝에 추가:

```dart
  testWidgets('double tap turns into TextField, Enter submits new name', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: false,
          isUntitled: false,
          onTap: () {},
          onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await t.enterText(find.byType(TextField), '책상');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, '책상');
  });

  testWidgets('Esc cancels rename', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true, isDirty: false, isUntitled: false,
          onTap: () {}, onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '책상');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(submitted, isNull);
  });
```

`import 'package:flutter/services.dart';` 추가.

**Step 2: Implement (TabItem을 StatefulWidget으로 전환)**

세부 구현: `_isEditing` state, `GestureDetector(onDoubleTap)`, `TextField` 노출, Esc는 Focus 의 onKey 로 잡고 false 반환, Enter / `onSubmitted` 시 `onRenameSubmit(text)`. 빈 / 공백은 reject. 금지 문자(`/ \ : * ? " < > |`)는 `inputFormatters` 로 차단.

(코드는 길어 생략 — 실행 시 작성. 기본 구조는 위 테스트가 요구하는 동작 그대로.)

**Step 3: Run — expect pass**

`flutter test test/ui/widgets/tab_item_test.dart`

**Step 4: Commit**

```bash
git add lib/ui/widgets/tab_item.dart test/ui/widgets/tab_item_test.dart
git commit -m "feat(ui): inline rename on double-click (Enter submit / Esc cancel)"
```

---

## Task 12: TabBar (가로 스크롤 + Reorderable + PlusButton placeholder)

**Why:** TabItem들을 배치하고 드래그 정렬을 지원하는 컨테이너.

**Files:**
- Create: `lib/ui/widgets/tab_bar.dart`
- Create: `lib/ui/widgets/plus_button.dart` (이번 task에선 빈 placeholder만)
- Test: `test/ui/widgets/tab_bar_test.dart`

**Step 1: Write failing test**

```dart
testWidgets('renders one TabItem per tab and a PlusButton', (t) async {
  // notifier에 탭 2개 주입한 ProviderScope 로 pump
  // expect(find.byType(TabItem), findsNWidgets(2));
  // expect(find.byKey(const ValueKey('plus-button')), findsOneWidget);
});

testWidgets('drag reorders tabs in notifier', (t) async {
  // ReorderableListView 의 drag 시뮬레이션
});
```

**Step 2 ~ 5:** 일반적 흐름. `ReorderableListView.builder(scrollDirection: Axis.horizontal, ...)` + 끝에 `PlusButton`. 활성 탭 클릭 시 `notifier.setActive(id)`, 닫기 시 `notifier.closeTab(id)`, rename 시 `notifier.updateName(id, name)` + (저장된 탭이면) `files.rename` 호출 후 `notifier`의 `filePath` 갱신용 메서드 추가 필요 — `TabsNotifier.renameSavedFile(id, newName)`을 같은 task에 추가하고 단위 테스트.

**Commit:**

```bash
git add lib/ui/widgets/tab_bar.dart lib/ui/widgets/plus_button.dart test/ui/widgets/tab_bar_test.dart lib/ui/providers/tabs_provider.dart test/ui/providers/tabs_notifier_test.dart
git commit -m "feat(ui): TabBar with horizontal scroll + drag reorder"
```

---

## Task 13: PlusButton 메뉴 (새 / 열기 / 최근)

**Files:**
- Modify: `lib/ui/widgets/plus_button.dart`
- Test: `test/ui/widgets/plus_button_test.dart`

**Step 1: Write failing test**

- 클릭하면 popup 메뉴에 `[새 프로젝트]`, `[파일에서 열기...]`, `--- 최근 ---`, recent file 항목들이 나오는지
- `[새 프로젝트]` → `notifier.newUntitled` 호출 (mock 으로 검증)
- recent 항목 클릭 → `notifier.openFile(path)` 호출

**Step 2 ~ 5:** `showMenu<...>`로 구현. recent 가져오는 건 `recentFilesProvider`. 사라진 파일은 클릭 시 try/catch → `workspace.removeRecentFile` + 토스트 (ScaffoldMessenger).

**Commit:**

```bash
git add lib/ui/widgets/plus_button.dart test/ui/widgets/plus_button_test.dart
git commit -m "feat(ui): PlusButton menu (new / open / recent)"
```

---

## Task 14: TopBar 통합 + Cmd+S 첫 저장 다이얼로그

**Files:**
- Modify: `lib/ui/widgets/top_bar.dart` (Spacer → TabBar)
- Create: `lib/ui/widgets/save_as_dialog.dart` (이름만 묻는 작은 다이얼로그)
- Test: `test/ui/widgets/save_as_dialog_test.dart`

**Step 1 ~ 5:** SaveAsDialog는 `[파일 이름: ___] [저장] [다른 위치에 저장...] [취소]` 폼. 반환은 `({String name, String? customFolder})` 형태. `[다른 위치에 저장...]`은 `file_picker` 의 `getDirectoryPath` 호출.

`top_bar.dart` 의 `Cmd+S` (Task 16에서 단축키 wiring) 와 별도로, TopBar 내 저장 IconButton이 untitled 탭이면 SaveAsDialog 띄우고 `notifier.saveAs(id, overrideName: name)` 호출.

**Commit:**

```bash
git add lib/ui/widgets/top_bar.dart lib/ui/widgets/save_as_dialog.dart test/ui/widgets/save_as_dialog_test.dart
git commit -m "feat(ui): wire TabBar into TopBar + SaveAsDialog for first save"
```

---

## Task 15: 더블클릭 rename 후 파일 rename 연결

**Why:** Q6 결정 — 탭 이름 변경 = 파일 rename. Untitled는 메모리 이름만, 저장된 탭은 파일도 같이.

**Files:**
- Modify: `lib/ui/providers/tabs_provider.dart` (renameSavedFile 메서드)
- Modify: `lib/ui/widgets/tab_bar.dart` (TabItem의 onRenameSubmit에서 분기)
- Test: `test/ui/providers/tabs_notifier_test.dart` (renameSavedFile 케이스 추가)

**Step 1: Write failing test**

```dart
test('renameSavedFile renames file and updates filePath + project.name', () async {
  // saveAs 후 renameSavedFile(id, '책상')
  // 파일 시스템에 책상.cutmaster 존재, 옛 파일은 없음
  // notifier.state[i].project.name == '책상'
  // notifier.state[i].filePath == .../책상.cutmaster
});
```

**Step 2: Implement**

`TabsNotifier`에:

```dart
Future<String?> renameSavedFile(String id, String newName) async {
  final tab = _tabs.firstWhereOrNull((t) => t.id == id);
  if (tab == null) return null;
  final cleanName = ProjectFileService.sanitizeBaseName(newName);
  if (tab.filePath == null) {
    // untitled — 메모리만
    updateName(id, cleanName);
    return null;
  }
  final newPath = await files.rename(tab.filePath!, cleanName);
  _setTab(id, (t) => t.copyWith(
    filePath: newPath,
    project: t.project.copyWith(name: cleanName),
    isDirty: false,
  ));
  await workspace.touchRecentFile(newPath, cleanName);
  return newPath;
}
```

`TabBar`의 `onRenameSubmit` callback 에서 이 메서드 호출.

**Step 3 ~ 5:** test pass + commit.

```bash
git commit -m "feat(state): renameSavedFile keeps tab name and file in sync"
```

---

## Task 16: 키보드 단축키 (Cmd+N/O/W/Shift+T/S/Tab)

**Why:** 데스크톱 표준 인터랙션.

**Files:**
- Modify: `lib/ui/main_screen.dart` (Shortcuts + Actions wrap)
- Test: `integration_test/keyboard_shortcuts_test.dart`

**Step 1: Implement**

`MainScreen` 의 Scaffold를 `Shortcuts` + `Actions` 로 감쌈:

```dart
Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.keyN, meta: true, control: true): _NewIntent(),
    SingleActivator(LogicalKeyboardKey.keyO, meta: true, control: true): _OpenIntent(),
    SingleActivator(LogicalKeyboardKey.keyW, meta: true, control: true): _CloseIntent(),
    SingleActivator(LogicalKeyboardKey.keyT, meta: true, control: true, shift: true): _ReopenIntent(),
    SingleActivator(LogicalKeyboardKey.keyS, meta: true, control: true): _SaveIntent(),
    SingleActivator(LogicalKeyboardKey.tab, meta: true, control: true): _NextTabIntent(),
  },
  child: Actions(actions: { ... }, child: scaffold),
)
```

각 Action 은 `tabsProvider` 호출. 닫은 탭 복원은 `closedTabsProvider`의 `popLastClosedTab()` + 새 탭으로 추가.

**Step 2 ~ 5:** pump 테스트로 단축키 시뮬레이션 → 탭 개수 변화 검증.

```bash
git commit -m "feat(ui): keyboard shortcuts for tab workflow"
```

---

## Task 17: 우클릭 컨텍스트 메뉴

**Files:**
- Create: `lib/ui/widgets/tab_context_menu.dart`
- Modify: `lib/ui/widgets/tab_item.dart` (GestureDetector secondaryTap)

**메뉴 항목:** 이름 변경 / 복사본 만들기 / Finder에서 보기 / 다른 이름으로 저장 / 닫기 / 다른 탭 모두 닫기.

`Finder/탐색기에서 보기` — macOS: `open -R <path>`, Windows: `explorer /select,<path>` (Process.run).
`복사본 만들기` — `files.writeNew(folder, '${name} 사본', project)` + `notifier.openFile(newPath)`.

**Commit:**

```bash
git commit -m "feat(ui): tab right-click context menu"
```

---

## Task 18: 외부 변경 감지 (mtime conflict → 분기 저장)

**Why:** Dropbox / iCloud sync 동안의 충돌을 안전하게 처리.

**Files:**
- Modify: `lib/data/file/project_file.dart` (overwrite에 lastKnownMtime 인자)
- Modify: `lib/ui/providers/tabs_provider.dart` (저장 시 mtime 비교 → 충돌 사본 분기)

**Step 1: Test**

`test/data/file/project_file_test.dart` 추가:
- 디스크 mtime이 lastKnown보다 새로움 → `ConflictException` throw.

`test/ui/providers/tabs_notifier_test.dart` 추가:
- conflict 발생 시 `<name> (충돌 사본).cutmaster` 만들어지고, 활성 탭은 이 파일로 갈아탐, 토스트 메시지 콜백 호출.

**Step 2 ~ 5:** ProjectFileService.overwrite 시그니처 변경 → `{required DateTime? lastKnownMtime}`. `File(path).statSync().modified` 비교. mismatch면 `ConflictException`. TabsNotifier가 catch → `writeNew(... '<name> (충돌 사본)')` + `_setTab(id, filePath: 새 경로)` + `onConflictNotice` 콜백.

```bash
git commit -m "feat(io): mtime-based conflict detection with fork-on-conflict"
```

---

## Task 19: 누락 / 손상 파일 토스트

**Files:**
- Modify: `lib/ui/main_screen.dart` (snackbar 호스트)
- Modify: `lib/ui/providers/tabs_provider.dart` (notice stream 추가)

`TabsNotifier` 가 `Stream<String> notices` 를 노출. `restoreSession` / `openFile` / 충돌 처리에서 사용자가 봐야 할 메시지를 emit. `MainScreen` 이 `listen` 해서 `ScaffoldMessenger.showSnackBar`.

```bash
git commit -m "feat(ui): user-visible notices for missing / corrupt / conflict files"
```

---

## Task 20: 통합 테스트 (E2E happy path)

**Files:**
- Create: `integration_test/multi_tab_flow_test.dart`

**시나리오:**
1. 앱 시작 → untitled 탭 1개
2. 탭 더블클릭 → "책장" 입력 → 자동 저장 안 됨 (untitled니까 autosave만)
3. Cmd+S → SaveAsDialog → "책장" 확정 → `~/Documents/Cutmaster/책장.cutmaster` 존재
4. + 버튼 → 새 프로젝트 → 두 번째 탭 생성
5. 두 번째 탭 X 닫기
6. Cmd+Shift+T → 두 번째 탭 복원
7. 앱 종료 (lifecycle observer) → 재시작 → 탭 2개 그대로 복원

```bash
git commit -m "test(e2e): full multi-tab create/save/close/reopen/restart flow"
```

---

## Task 21: 문서 업데이트

**Files:**
- Modify: `README.md` (저장 방식 / 단축키 / 파일 위치 섹션 추가)
- Modify: `docs/INSTALL_MACOS.md`, `docs/INSTALL_WINDOWS.md` (필요 시)

```bash
git commit -m "docs: document multi-tab workspace + .cutmaster file model"
```

---

## 구현 후 검증 체크리스트

- [ ] `flutter analyze` 0 issues
- [ ] `flutter test` 모두 pass
- [ ] `flutter test integration_test/multi_tab_flow_test.dart` pass
- [ ] 옛 cutmaster.db 가진 환경에서 첫 실행 → 모든 프로젝트가 `~/Documents/Cutmaster/`에 export
- [ ] 새 사용자 첫 실행 → 빈 untitled 탭 1개
- [ ] 탭 5개 만들고 종료 → 재시작 → 5개 + 활성 탭 복원
- [ ] 탭 닫고 Cmd+Shift+T → 복원
- [ ] 더블클릭 → 인라인 편집 → 파일 rename 확인 (Finder)
- [ ] Untitled 탭에 입력 → 앱 강제 종료 → 재시작 시 autosave 복원
- [ ] Dropbox 같은 폴더에 저장 → 외부에서 파일 수정 → 우리 앱이 저장 시도 → `(충돌 사본)` 분기 확인

---

## 실행 옵션

Plan complete and saved to `docs/plans/2026-04-25-multi-tab-projects-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open a new session with `superpowers:executing-plans`, batch execution with checkpoints

**Which approach?**
