import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';
import 'package:cutmaster/ui/widgets/tab_bar.dart';
import 'package:cutmaster/ui/widgets/tab_item.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late WorkspaceDb ws;
  late TabsNotifier notifier;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tab_bar_');
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
    // ProviderScope already disposes the notifier when the widget tree tears
    // down — calling dispose() again would throw. The notifier is owned by
    // the ProviderScope here, so we only clean up the workspace + tmp dir.
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Widget pump() => ProviderScope(
        overrides: [tabsProvider.overrideWith((_) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(height: 40, child: CutmasterTabBar())),
        ),
      );

  testWidgets('renders one TabItem per tab + a PlusButton', (t) async {
    notifier.newUntitled();
    notifier.newUntitled();
    await t.pumpWidget(pump());
    await t.pumpAndSettle();

    expect(find.byType(TabItem), findsNWidgets(2));
    expect(find.byKey(const ValueKey('plus-button')), findsOneWidget);
  });

  testWidgets('tap on TabItem activates that tab', (t) async {
    notifier.newUntitled();
    final firstId = notifier.tabs.first.id;
    notifier.newUntitled();
    final secondId = notifier.tabs.last.id;
    expect(notifier.activeId, secondId);

    await t.pumpWidget(pump());
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey(firstId)));
    // The TabItem has an inner GestureDetector with onDoubleTap that
    // competes for single taps; need to advance past the double-tap
    // timeout so the outer InkWell.onTap actually fires.
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(notifier.activeId, firstId);
  });

  testWidgets('tap on close removes the tab', (t) async {
    notifier.newUntitled();

    await t.pumpWidget(pump());
    await t.pumpAndSettle();

    expect(find.byType(TabItem), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tab-close')));
    // closeTab does real SQL work — flush real async on the FakeAsync zone.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(notifier.tabs, isEmpty);
  });

  testWidgets('PlusButton creates a new untitled tab', (t) async {
    expect(notifier.tabs, isEmpty);
    await t.pumpWidget(pump());
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('plus-button')));
    await t.pumpAndSettle();
    expect(notifier.tabs.length, 1);
    expect(notifier.tabs.first.filePath, null);
  });

  testWidgets('drag reorder updates tab order', (t) async {
    notifier.newUntitled();
    final firstId = notifier.tabs[0].id;
    notifier.newUntitled();
    final secondId = notifier.tabs[1].id;

    await t.pumpWidget(pump());
    await t.pumpAndSettle();

    expect(notifier.tabs.map((tab) => tab.id), [firstId, secondId]);

    // Programmatically reorder via the notifier (we test the wiring + handler)
    notifier.reorder(0, 2);
    await t.pumpAndSettle();

    expect(notifier.tabs.map((tab) => tab.id), [secondId, firstId]);
  });
}
