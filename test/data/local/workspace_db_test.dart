import 'dart:io';

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

  test('deleteTab on missing id is no-op', () async {
    final db = await WorkspaceDb.openInMemory();
    await db.deleteTab('does-not-exist'); // 예외 없이 통과해야 함
    expect((await db.listTabs()), isEmpty);
    await db.close();
  });

  test('upsertTab with same id replaces existing row', () async {
    final db = await WorkspaceDb.openInMemory();
    await db.upsertTab(const TabRow(
      id: 't1', filePath: '/a', displayName: 'a',
      position: 0, isActive: false,
    ));
    await db.upsertTab(const TabRow(
      id: 't1', filePath: '/b', displayName: 'b',
      position: 0, isActive: true,
    ));
    final list = await db.listTabs();
    expect(list.length, 1);
    expect(list.first.filePath, '/b');
    expect(list.first.isActive, true);
    await db.close();
  });

  test('popLastClosedTab returns null when empty', () async {
    final db = await WorkspaceDb.openInMemory();
    expect(await db.popLastClosedTab(), isNull);
    await db.close();
  });

  test('pruneClosedTabs trims by keepAtMost when nothing is old', () async {
    final db = await WorkspaceDb.openInMemory();
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      await db.pushClosedTab(ClosedTabRow(
        tabId: 't$i', filePath: '/p$i', autosavePath: null,
        displayName: 't$i',
        closedAt: now.subtract(Duration(seconds: i)),
      ));
    }
    final removed = await db.pruneClosedTabs(maxAgeDays: 30, keepAtMost: 3);
    expect(removed.length, 2);
    expect(removed.map((r) => r.tabId).toSet(), {'t3', 't4'});
    expect((await db.listClosedTabs()).length, 3);
    await db.close();
  });

  test('open(path) persists data across close/reopen', () async {
    final tmp = await Directory.systemTemp.createTemp('ws_db_');
    final dbPath = '${tmp.path}/workspace.db';
    final db1 = await WorkspaceDb.open(dbPath);
    await db1.upsertTab(const TabRow(
      id: 't1', filePath: '/x', displayName: 'x',
      position: 0, isActive: true,
    ));
    await db1.close();

    final db2 = await WorkspaceDb.open(dbPath);
    final list = await db2.listTabs();
    expect(list.length, 1);
    expect(list.first.id, 't1');
    await db2.close();
    await tmp.delete(recursive: true);
  });
}
