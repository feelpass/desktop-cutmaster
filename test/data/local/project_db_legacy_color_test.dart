import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/local/project_db.dart';

/// Regression-locks the matcher path on `ProjectDb` itself (not just the file
/// service). v1 rows whose `parts_json` carries the legacy `color: int` field
/// must round-trip through `loadProject` and surface as `colorPresetId` when
/// a `colorMatcher` is injected at open time.
///
/// Strategy: insert a legacy-shaped row via the raw `Database` (bypassing
/// `ProjectDb.upsertProject`, which only writes the new shape via
/// `CutPart.toJson`). Then re-open through `ProjectDb.open` with a matcher
/// and assert the loaded part resolves to the expected preset id.
void main() {
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_db_legacy_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('legacy row with color:int gets colorPresetId via matcher', () async {
    final dbPath = p.join(tmp.path, 'workspace.db');

    // (1) Open through ProjectDb so the v1 schema gets created via _onCreate,
    // then close. This avoids duplicating the CREATE TABLE DDL in the test.
    final seed = await ProjectDb.open(dbPath);
    await seed.close();

    // (2) Re-open the same file via the raw factory and insert a legacy row.
    // parts_json carries the legacy `color: int` field (no colorPresetId).
    final raw = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1),
    );
    final now = DateTime.parse('2024-01-01T00:00:00.000').toIso8601String();
    await raw.insert('project', {
      'id': 'p_legacy',
      'name': '레거시',
      'kerf': 3.0,
      'grain_locked': 0,
      'show_part_labels': 1,
      'use_single_sheet': 0,
      'stocks_json': jsonEncode(<Map<String, dynamic>>[]),
      'parts_json': jsonEncode([
        {
          'id': 'pa1',
          'length': 600.0,
          'width': 300.0,
          'qty': 1,
          'label': '',
          'grain': 'none',
          'color': 0xFFEF4444, // legacy ARGB int — no colorPresetId
        },
      ]),
      'created_at': now,
      'updated_at': now,
    });
    await raw.close();

    // (3) Re-open through ProjectDb WITH a matcher and verify resolution.
    final db = await ProjectDb.open(
      dbPath,
      colorMatcher: (argb) => argb == 0xFFEF4444 ? 'cp_red' : null,
    );
    final loaded = await db.loadProject('p_legacy');

    expect(loaded, isNotNull);
    expect(loaded!.parts, hasLength(1));
    expect(loaded.parts.first.colorPresetId, 'cp_red');

    await db.close();
  });
}
