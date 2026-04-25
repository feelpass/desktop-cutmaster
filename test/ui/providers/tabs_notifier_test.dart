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
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.filePath, null);
    expect(notifier.tabs.first.isDirty, false);
  });

  test('updateName marks dirty and updates project.name', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    expect(notifier.tabs.first.project.name, '책장');
    expect(notifier.tabs.first.isDirty, true);
  });

  test('saveAs writes file, clears autosave, registers recent', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    expect(path, p.join(tmp.path, '책장.cutmaster'));
    expect(File(path!).existsSync(), true);

    final tab = notifier.tabs.first;
    expect(tab.filePath, path);
    expect(tab.isDirty, false);

    final recent = await ws.listRecentFiles();
    expect(recent.first.filePath, path);
  });

  test('openFile focuses existing tab if path already open', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    notifier.newUntitled(); // 탭 2개
    expect(notifier.tabs.length, 2);

    await notifier.openFile(path!);
    expect(notifier.tabs.length, 2);
    expect(notifier.activeId, id);
  });

  test('closeTab removes tab and pushes to closed_tab', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    await notifier.closeTab(id);
    expect(notifier.tabs, isEmpty);

    final closed = await ws.listClosedTabs();
    expect(closed.length, 1);
    expect(closed.first.tabId, id);
  });

  test('setActive on unknown id is a no-op', () {
    notifier.newUntitled();
    final id = notifier.activeId;
    notifier.setActive('does-not-exist');
    expect(notifier.activeId, id);
  });

  test('updateName triggers autosave for untitled tab', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final autosavePath = p.join(tmp.path, 'autosave', '$id.cutmaster');
    expect(File(autosavePath).existsSync(), true);
  });

  test('closeTab on active moves focus to neighbor', () async {
    notifier.newUntitled();
    final first = notifier.tabs.first.id;
    notifier.newUntitled();
    final second = notifier.tabs.last.id;
    expect(notifier.activeId, second);
    await notifier.closeTab(second);
    expect(notifier.activeId, first);
  });

  test('openFile reads project from disk into a new tab', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);
    notifier.newUntitled(); // 2 tabs
    await notifier.closeTab(id); // close the saved one (now 1 untitled)
    expect(notifier.tabs.length, 1);
    await notifier.openFile(path!);
    expect(notifier.tabs.length, 2);
    expect(notifier.tabs.last.project.name, '책장');
  });

  test('flushAll persists pending dirty edits immediately', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    expect(notifier.tabs.first.isDirty, true);
    await notifier.flushAll();
    expect(notifier.tabs.first.isDirty, false);
  });

  test('renameSavedFile renames file + filePath + name + recent', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final originalPath = await notifier.saveAs(id);
    expect(originalPath, p.join(tmp.path, '책장.cutmaster'));

    final newPath = await notifier.renameSavedFile(id, '책상');

    expect(newPath, p.join(tmp.path, '책상.cutmaster'));
    expect(File(newPath!).existsSync(), true);
    expect(File(originalPath!).existsSync(), false);

    final tab = notifier.tabs.first;
    expect(tab.filePath, newPath);
    expect(tab.project.name, '책상');
    expect(tab.isDirty, false);

    final recent = await ws.listRecentFiles();
    expect(recent.length, 1);
    expect(recent.first.filePath, newPath);
  });

  test('renameSavedFile on untitled tab updates name only (no file)', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    final result = await notifier.renameSavedFile(id, '책장');
    expect(result, null);
    expect(notifier.tabs.first.project.name, '책장');
    expect(notifier.tabs.first.filePath, null);
    expect(notifier.tabs.first.isDirty, true);
  });

  test('renameSavedFile rejects empty/whitespace', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    final result = await notifier.renameSavedFile(id, '   ');
    expect(result, null);
    expect(notifier.tabs.first.filePath, path);
    expect(notifier.tabs.first.project.name, '책장');
  });

  test('cycleNext rotates active id through tabs', () {
    notifier.newUntitled();
    final id1 = notifier.tabs[0].id;
    notifier.newUntitled();
    final id2 = notifier.tabs[1].id;

    expect(notifier.activeId, id2);
    notifier.cycleNext();
    expect(notifier.activeId, id1);
    notifier.cycleNext();
    expect(notifier.activeId, id2);
  });

  test('reopenLastClosed restores a saved tab from filePath', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final path = await notifier.saveAs(id);

    await notifier.closeTab(id);
    expect(notifier.tabs, isEmpty);

    final reopened = await notifier.reopenLastClosed();
    expect(reopened, true);
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.filePath, path);
    expect(notifier.tabs.first.project.name, '책장');
  });

  test('reopenLastClosed restores untitled tab from autosave', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '메모');
    await notifier.flushAll(); // autosave 파일 만들기

    await notifier.closeTab(id);
    expect(notifier.tabs, isEmpty);

    final reopened = await notifier.reopenLastClosed();
    expect(reopened, true);
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.filePath, null);
    expect(notifier.tabs.first.project.name, '메모');
  });

  test('reopenLastClosed returns false when no closed tabs', () async {
    final result = await notifier.reopenLastClosed();
    expect(result, false);
  });

  test('duplicateTab on saved tab writes a new file with copy name', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    final orig = await notifier.saveAs(id);
    expect(orig, p.join(tmp.path, '책장.cutmaster'));

    final newPath = await notifier.duplicateTab(id);
    expect(newPath, p.join(tmp.path, '책장 사본.cutmaster'));
    expect(File(newPath!).existsSync(), true);
    expect(notifier.tabs.length, 2);
    expect(notifier.tabs.last.project.name, '책장 사본');
    expect(notifier.activeId, notifier.tabs.last.id);
  });

  test('duplicateTab on untitled creates a new untitled tab', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '메모');

    final result = await notifier.duplicateTab(id);
    expect(result, null);
    expect(notifier.tabs.length, 2);
    expect(notifier.tabs.last.filePath, null);
    expect(notifier.tabs.last.project.name, '메모 사본');
  });

  test('saveAsCopy creates a new tab with a separate file', () async {
    notifier.newUntitled();
    final id = notifier.tabs.first.id;
    notifier.updateName(id, '책장');
    await notifier.saveAs(id);

    final newPath = await notifier.saveAsCopy(id, '책장-복제');
    expect(newPath, p.join(tmp.path, '책장-복제.cutmaster'));
    expect(File(newPath!).existsSync(), true);
    expect(notifier.tabs.length, 2);
    expect(notifier.activeId, notifier.tabs.last.id);
  });

  test('closeOthers closes all tabs except the kept one', () async {
    notifier.newUntitled();
    notifier.newUntitled();
    notifier.newUntitled();
    expect(notifier.tabs.length, 3);
    final keep = notifier.tabs[1].id;

    await notifier.closeOthers(keep);
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.id, keep);
  });
}
