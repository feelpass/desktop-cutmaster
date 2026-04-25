import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    final autosave = p.join(tmp.path, 'autosave');

    var n1 = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: autosave,
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    n1.newUntitled();
    final id = n1.tabs.first.id;
    n1.updateName(id, '책장');
    final path = await n1.saveAs(id);

    n1.newUntitled();
    final untitledId = n1.tabs.last.id;
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

    expect(n2.tabs.length, 2);
    expect(n2.tabs.firstWhere((t) => t.filePath == path).project.name, '책장');
    expect(n2.activeId, untitledId);
    expect(n2.tabs.firstWhere((t) => t.id == untitledId).project.name, '도면 메모');

    n2.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });
}
