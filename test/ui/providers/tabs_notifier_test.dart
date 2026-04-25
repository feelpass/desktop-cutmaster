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

  late Directory tmp;
  late WorkspaceDb ws;
  late TabsNotifier notifier;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tabs_');
    ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    notifier = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
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

    expect(path, p.join(tmp.path, '책장.cutmaster'));
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
