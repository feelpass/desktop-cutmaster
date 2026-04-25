import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/models/cut_part.dart';
import '../../domain/models/project.dart';
import '../../domain/models/stock_sheet.dart';

/// 프로젝트 영속화. sqflite_common_ffi (데스크톱 SQLite).
///
/// 스키마 v1:
/// - project: 프로젝트 메타 + stocks_json + parts_json (JSON 컬럼)
///   - 프로젝트는 사용 시점의 자재 스냅샷을 자체 보유 (라이브러리 변경에 안 흔들림)
/// - stock_sheet_library: 자재 라이브러리 (재사용 가능한 자재 정의)
class ProjectDb {
  final Database _db;
  ProjectDb._(this._db);

  static Future<ProjectDb> openInMemory() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _onCreate),
    );
    return ProjectDb._(db);
  }

  static Future<ProjectDb> open(String path) async {
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return ProjectDb._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE project (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kerf REAL NOT NULL,
        grain_locked INTEGER NOT NULL,
        show_part_labels INTEGER NOT NULL,
        use_single_sheet INTEGER NOT NULL,
        stocks_json TEXT NOT NULL,
        parts_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_sheet_library (
        id TEXT PRIMARY KEY,
        length REAL NOT NULL,
        width REAL NOT NULL,
        qty INTEGER NOT NULL,
        label TEXT NOT NULL,
        grain TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // v2+ 마이그레이션은 여기에 추가
  }

  Future<void> upsertProject(Project p) async {
    await _db.insert(
      'project',
      _projectToRow(p),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Project?> loadProject(String id) async {
    final rows = await _db.query('project', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToProject(rows.first);
  }

  Future<List<Project>> listProjects() async {
    final rows = await _db.query('project', orderBy: 'updated_at DESC');
    return rows.map(_rowToProject).toList();
  }

  Future<void> deleteProject(String id) async {
    await _db.delete('project', where: 'id = ?', whereArgs: [id]);
  }

  // === 자재 라이브러리 ===

  Future<List<StockSheet>> listLibrary() async {
    final rows = await _db.query('stock_sheet_library', orderBy: 'label');
    return rows.map((r) => StockSheet(
          id: r['id'] as String,
          length: (r['length'] as num).toDouble(),
          width: (r['width'] as num).toDouble(),
          qty: r['qty'] as int,
          label: r['label'] as String,
          grainDirection:
              GrainDirection.values.byName(r['grain'] as String? ?? 'none'),
        )).toList();
  }

  Future<void> upsertLibraryItem(StockSheet s) async {
    await _db.insert(
      'stock_sheet_library',
      {
        'id': s.id,
        'length': s.length,
        'width': s.width,
        'qty': s.qty,
        'label': s.label,
        'grain': s.grainDirection.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLibraryItem(String id) async {
    await _db.delete('stock_sheet_library', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async => _db.close();

  // === Internal ===

  Map<String, dynamic> _projectToRow(Project p) => {
        'id': p.id,
        'name': p.name,
        'kerf': p.kerf,
        'grain_locked': p.grainLocked ? 1 : 0,
        'show_part_labels': p.showPartLabels ? 1 : 0,
        'use_single_sheet': p.useSingleSheet ? 1 : 0,
        'stocks_json': jsonEncode(p.stocks.map((s) => s.toJson()).toList()),
        'parts_json': jsonEncode(p.parts.map((c) => c.toJson()).toList()),
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
      };

  Project _rowToProject(Map<String, Object?> r) {
    final stocksJson = jsonDecode(r['stocks_json'] as String) as List;
    final partsJson = jsonDecode(r['parts_json'] as String) as List;
    return Project(
      id: r['id'] as String,
      name: r['name'] as String,
      stocks: stocksJson
          .map((j) => StockSheet.fromJson(j as Map<String, dynamic>))
          .toList(),
      parts: partsJson
          .map((j) => CutPart.fromJson(j as Map<String, dynamic>))
          .toList(),
      kerf: (r['kerf'] as num).toDouble(),
      grainLocked: r['grain_locked'] == 1,
      showPartLabels: r['show_part_labels'] == 1,
      useSingleSheet: r['use_single_sheet'] == 1,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }
}
