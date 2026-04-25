import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('restoreSession on empty DB results in empty tabs', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    final n = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n.restoreSession();
    expect(n.tabs, isEmpty);
    expect(n.activeId, null);
    n.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });

  test('restoreSession skips a tab whose file vanished without autosave', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    // 직접 tab row를 등록 — 파일은 존재하지 않음, autosave도 없음
    await ws.upsertTab(TabRow(
      id: 'gone',
      filePath: p.join(tmp.path, 'gone.cutmaster'),
      displayName: '없어진 것',
      position: 0,
      isActive: true,
    ));
    final n = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n.restoreSession();
    expect(n.tabs, isEmpty); // 그 탭만 빠짐
    n.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });

  test('restoreSession skips a corrupt .cutmaster file', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    // 손상 파일 생성 + 그 탭 row
    final badPath = p.join(tmp.path, 'bad.cutmaster');
    await File(badPath).writeAsString('not json');
    await ws.upsertTab(TabRow(
      id: 'bad',
      filePath: badPath,
      displayName: 'bad',
      position: 0,
      isActive: false,
    ));
    final n = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n.restoreSession();
    expect(n.tabs, isEmpty);
    n.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });

  test('restoreSession falls back to first tab when no row is active', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));

    // 두 개의 untitled 탭을 autosave에 직접 만들고 row 등록 (둘 다 isActive=false)
    final autosave = p.join(tmp.path, 'autosave');
    await Directory(autosave).create(recursive: true);
    final svc = ProjectFileService();
    final pa = Project.create(id: 'pa', name: '하나');
    final pb = Project.create(id: 'pb', name: '둘');
    await svc.overwrite(p.join(autosave, 't1.cutmaster'), pa);
    await svc.overwrite(p.join(autosave, 't2.cutmaster'), pb);
    await ws.upsertTab(const TabRow(
      id: 't1', filePath: null, displayName: '하나', position: 0, isActive: false,
    ));
    await ws.upsertTab(const TabRow(
      id: 't2', filePath: null, displayName: '둘', position: 1, isActive: false,
    ));

    final n = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: autosave,
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n.restoreSession();
    expect(n.tabs.length, 2);
    expect(n.activeId, 't1'); // fallback to first
    n.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });

  test('restoreSession survives one corrupt tab and loads the rest', () async {
    final tmp = await Directory.systemTemp.createTemp('sess_');
    final ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    final svc = ProjectFileService();

    // 정상 파일 1개
    final goodPath = await svc.writeNew(
      folder: tmp.path, baseName: '책장',
      project: Project.create(id: 'p1', name: '책장'),
    );
    // 손상 파일 1개
    final badPath = p.join(tmp.path, 'bad.cutmaster');
    await File(badPath).writeAsString('not json');

    await ws.upsertTab(TabRow(
      id: 'good', filePath: goodPath,
      displayName: '책장', position: 0, isActive: true,
    ));
    await ws.upsertTab(TabRow(
      id: 'bad', filePath: badPath,
      displayName: 'bad', position: 1, isActive: false,
    ));

    final n = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    await n.restoreSession();
    expect(n.tabs.length, 1); // good만
    expect(n.tabs.first.id, 'good');
    expect(n.activeId, 'good');
    n.dispose();
    await ws.close();
    await tmp.delete(recursive: true);
  });
}
