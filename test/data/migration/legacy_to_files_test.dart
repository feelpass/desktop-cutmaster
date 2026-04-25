import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  late Directory tmp;
  late Directory outDir;
  late ProjectDb legacy;
  late WorkspaceDb ws;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mig_');
    outDir = await Directory(p.join(tmp.path, 'out')).create();
    // 두 DB가 :memory: 같은 핸들을 공유하지 않도록 파일로 분리.
    legacy = await ProjectDb.open(p.join(tmp.path, 'legacy.db'));
    ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
  });

  tearDown(() async {
    await legacy.close();
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('migrates each project to .cutmaster file and registers as recent', () async {
    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책상'));

    final result = await LegacyMigrator(
            legacy: legacy, workspace: ws, targetFolder: outDir.path)
        .run();

    expect(result.migrated, 2);
    expect(result.failed, 0);
    expect(File('${outDir.path}/책장.cutmaster').existsSync(), true);
    expect(File('${outDir.path}/책상.cutmaster').existsSync(), true);

    final recent = await ws.listRecentFiles();
    expect(recent.length, 2);
  });

  test('handles name collisions with (2) suffix', () async {
    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책장'));

    final result = await LegacyMigrator(
            legacy: legacy, workspace: ws, targetFolder: outDir.path)
        .run();

    expect(result.migrated, 2);
    expect(File('${outDir.path}/책장.cutmaster').existsSync(), true);
    expect(File('${outDir.path}/책장 (2).cutmaster').existsSync(), true);
  });

  test('does not modify the legacy DB', () async {
    // setUp creates tmp, legacy, ws. We add projects, run migrator, assert legacy unchanged.
    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책상'));

    final beforeCount = (await legacy.listProjects()).length;
    final beforeIds =
        (await legacy.listProjects()).map((p) => p.id).toSet();

    await LegacyMigrator(
            legacy: legacy, workspace: ws, targetFolder: outDir.path)
        .run();

    final after = await legacy.listProjects();
    expect(after.length, beforeCount);
    expect(after.map((p) => p.id).toSet(), beforeIds);
  });
}
