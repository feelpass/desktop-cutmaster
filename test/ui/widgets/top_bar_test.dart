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
import 'package:cutmaster/ui/providers/theme_mode_provider.dart';
import 'package:cutmaster/ui/widgets/top_bar.dart';

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
  late ThemeModeNotifier themeMode;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('top_bar_');
    ws = await WorkspaceDb.open(p.join(tmp.path, 'workspace.db'));
    tabs = TabsNotifier(
      workspace: ws,
      files: ProjectFileService(),
      autosaveDir: p.join(tmp.path, 'autosave'),
      defaultProjectsDir: tmp.path,
      saveDebounce: const Duration(milliseconds: 1),
    );
    tabs.newUntitled();

    presets = PresetsNotifier(_FakePresetRepo());
    await presets.load();

    themeMode = ThemeModeNotifier(ws, ThemeMode.light);
  });

  tearDown(() async {
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Widget pump() => ProviderScope(
        overrides: [
          tabsProvider.overrideWith((_) => tabs),
          presetsProvider.overrideWith((_) => presets),
          themeModeProvider.overrideWith((_) => themeMode),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: const Scaffold(body: TopBar()),
        ),
      );

  testWidgets('renders save split-button — main 저장 + dropdown chevron',
      (tester) async {
    // TopBar는 가로로 길어서 좁은 뷰포트에서 overflow가 난다 — 데스크탑 폭 사용.
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    // 메인 저장 버튼 라벨이 보인다.
    expect(find.text('저장'), findsOneWidget);
    // 드롭다운 chevron InkWell이 ValueKey로 식별 가능.
    expect(find.byKey(const ValueKey('save-as-dropdown')), findsOneWidget);
  });

  testWidgets(
      'tapping the dropdown chevron opens menu with "다른 이름으로 저장..."',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-as-dropdown')));
    await tester.pumpAndSettle();

    // PopupMenu 항목 — 메뉴 아이템과 단축키 hint 모두 노출.
    expect(find.text('다른 이름으로 저장...'), findsOneWidget);
    expect(find.text('⇧⌘S'), findsOneWidget);
  });

  testWidgets('save dropdown menu dismisses when tapped outside',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pump());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-as-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('다른 이름으로 저장...'), findsOneWidget);

    // 메뉴 바깥 영역(좌상단 스캐폴드 가장자리)을 탭 — 메뉴 dismiss.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('다른 이름으로 저장...'), findsNothing);
  });
}
