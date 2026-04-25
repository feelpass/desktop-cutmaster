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
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
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
    await db.execute(
        'CREATE INDEX idx_recent_last_opened ON recent_file(last_opened_at DESC)');
    await db.execute(
        'CREATE INDEX idx_closed_at ON closed_tab(closed_at DESC)');
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // v2+ 마이그레이션은 여기에 추가
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
    await _db.transaction((tx) async {
      await tx.insert(
        'recent_file',
        {
          'file_path': filePath,
          'display_name': displayName,
          'last_opened_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // LRU 20개 유지
      await tx.rawDelete('''
        DELETE FROM recent_file
        WHERE file_path NOT IN (
          SELECT file_path FROM recent_file
          ORDER BY last_opened_at DESC
          LIMIT 20
        )
      ''');
    });
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
    final cutoffStr =
        DateTime.now().subtract(Duration(days: maxAgeDays)).toIso8601String();
    final removed = <Map<String, Object?>>[];
    await _db.transaction((tx) async {
      final aged = await tx.query('closed_tab',
          where: 'closed_at < ?', whereArgs: [cutoffStr]);
      removed.addAll(aged);
      await tx.delete('closed_tab',
          where: 'closed_at < ?', whereArgs: [cutoffStr]);

      final remaining =
          await tx.query('closed_tab', orderBy: 'closed_at DESC');
      if (remaining.length > keepAtMost) {
        final overflow = remaining.skip(keepAtMost).toList();
        for (final r in overflow) {
          removed.add(r);
          await tx.delete('closed_tab',
              where: 'tab_id = ?', whereArgs: [r['tab_id']]);
        }
      }
    });
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
