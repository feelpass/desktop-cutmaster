import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';
import 'package:cutmaster/ui/widgets/left_pane.dart';

class _FakePresetRepo extends PresetRepository {
  _FakePresetRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late WorkspaceDb ws;
  late TabsNotifier tabs;
  late PresetsNotifier presets;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('left_pane_');
    ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    tabs = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    // LeftPane's children watch activeProjectProvider with `!` — need a tab.
    tabs.newUntitled();

    presets = PresetsNotifier(_FakePresetRepo());
    await presets.load();
  });

  tearDown(() async {
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Widget pump() => ProviderScope(
        overrides: [
          tabsProvider.overrideWith((_) => tabs),
          presetsProvider.overrideWith((_) => presets),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: const Scaffold(body: LeftPane()),
        ),
      );

  testWidgets(
      'header has settings button for parts and stocks (not options)',
      (tester) async {
    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    // Two ⚙️ buttons — parts + stocks. Options must not have one.
    expect(find.byTooltip('프리셋 관리'), findsNWidgets(2));
  });

  testWidgets(
      'tapping parts settings opens part preset management dialog',
      (tester) async {
    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    // First gear button is parts (sections render top-down: parts, stocks, options).
    await tester.tap(find.byTooltip('프리셋 관리').first);
    await tester.pumpAndSettle();

    // PresetManagementDialog title for PresetKind.part.
    expect(find.text('부품 프리셋 관리'), findsOneWidget);
  });

}
