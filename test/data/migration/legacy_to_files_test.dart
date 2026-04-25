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

  test('migrates each project to .cutmaster file and registers as recent', () async {
    final tmp = await Directory.systemTemp.createTemp('mig_');
    // 두 DB가 :memory: 같은 핸들을 공유하지 않도록 파일로 분리.
    final legacy = await ProjectDb.open(p.join(tmp.path, 'legacy.db'));
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    final out = await Directory(p.join(tmp.path, 'out')).create();

    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책상'));

    final result =
        await LegacyMigrator(legacy: legacy, workspace: ws, targetFolder: out.path)
            .run();

    expect(result.migrated, 2);
    expect(result.failed, 0);
    expect(File('${out.path}/책장.cutmaster').existsSync(), true);
    expect(File('${out.path}/책상.cutmaster').existsSync(), true);

    final recent = await ws.listRecentFiles();
    expect(recent.length, 2);

    await legacy.close();
    await ws.close();
    await tmp.delete(recursive: true);
  });

  test('handles name collisions with (2) suffix', () async {
    final tmp = await Directory.systemTemp.createTemp('mig_');
    final legacy = await ProjectDb.open(p.join(tmp.path, 'legacy.db'));
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    final out = await Directory(p.join(tmp.path, 'out')).create();

    await legacy.upsertProject(Project.create(id: 'a', name: '책장'));
    await legacy.upsertProject(Project.create(id: 'b', name: '책장'));

    final result =
        await LegacyMigrator(legacy: legacy, workspace: ws, targetFolder: out.path)
            .run();

    expect(result.migrated, 2);
    expect(File('${out.path}/책장.cutmaster').existsSync(), true);
    expect(File('${out.path}/책장 (2).cutmaster').existsSync(), true);

    await legacy.close();
    await ws.close();
    await tmp.delete(recursive: true);
  });
}
