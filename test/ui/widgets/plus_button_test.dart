import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';
import 'package:cutmaster/ui/widgets/plus_button.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late WorkspaceDb ws;
  late TabsNotifier notifier;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('plus_btn_');
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
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Widget pump() => ProviderScope(
        overrides: [tabsProvider.overrideWith((_) => notifier)],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: PlusButton()),
          ),
        ),
      );

  // Tap the + button and wait for the popup menu (which awaits a real-async
  // sqlite call before showMenu). pumpAndSettle alone doesn't drain real I/O,
  // and pumpAndSettle hangs once the menu is shown (popup repaints, even briefly,
  // can keep settling). Use a fixed pump duration covering the show animation.
  Future<void> openMenu(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('plus-button')));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('clicking + shows menu with [새 프로젝트] and [파일에서 열기...]',
      (t) async {
    await t.pumpWidget(pump());
    await t.pumpAndSettle();
    await openMenu(t);
    expect(find.text('새 프로젝트'), findsOneWidget);
    expect(find.text('파일에서 열기...'), findsOneWidget);
    expect(find.text('최근'), findsNothing); // 비어 있을 때 숨김
  });

  testWidgets('[새 프로젝트] creates an untitled tab', (t) async {
    await t.pumpWidget(pump());
    await t.pumpAndSettle();
    await openMenu(t);
    await t.tap(find.text('새 프로젝트'));
    await t.pumpAndSettle();
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.filePath, null);
  });

  testWidgets('shows recent files when present', (t) async {
    // sqflite_ffi runs real I/O; wrap in runAsync to avoid FakeAsync hangs.
    await t.runAsync(() async {
      await ws.touchRecentFile(p.join(tmp.path, 'a.cutmaster'), '책장');
      await ws.touchRecentFile(p.join(tmp.path, 'b.cutmaster'), '책상');
    });

    await t.pumpWidget(pump());
    await t.pumpAndSettle();
    await openMenu(t);
    expect(find.text('최근'), findsOneWidget);
    expect(find.text('책장'), findsOneWidget);
    expect(find.text('책상'), findsOneWidget);
  });

  testWidgets('clicking missing recent file shows snackbar and removes it',
      (t) async {
    final missingPath = p.join(tmp.path, 'gone.cutmaster');
    await t.runAsync(() async {
      await ws.touchRecentFile(missingPath, '없어진 것');
    });

    await t.pumpWidget(pump());
    await t.pumpAndSettle();
    await openMenu(t);
    await t.tap(find.text('없어진 것'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    final remaining =
        await t.runAsync(() => ws.listRecentFiles()) ?? const [];
    expect(remaining, isEmpty);
  });
}
