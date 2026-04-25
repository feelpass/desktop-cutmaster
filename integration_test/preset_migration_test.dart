import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/data/preset/color_matcher.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';
import 'package:cutmaster/ui/widgets/left_pane.dart';

/// Task 20 — 레거시 색상 마이그레이션 + 색상 이름 변경 시 행 메타 줄
/// 자동 갱신 E2E.
///
/// 시나리오:
/// 1. 격리된 tmp 워크스페이스에 `schemaVersion: 1` .cutmaster 파일을
///    `color: 0xFFEF4444` (옛 빨강 ARGB) 로 작성.
/// 2. `ProjectFileService.read()`가 `colorMatcher`(글로벌 ColorPreset 풀
///    기반)를 통해 그 ARGB를 `cp_red`로 매핑하는지 확인.
/// 3. 그 프로젝트가 든 탭을 가진 `LeftPane`을 mount 해서 부품 행
///    메타 줄에 "빨강" 텍스트가 보이는지 확인 (Task 7~10에서 만든
///    1줄+메타 줄 레이아웃).
/// 4. `PresetsNotifier.updateColor()`로 cp_red 의 이름을 "빨강색"으로
///    변경 → 추가 user input 없이 메타 줄이 "빨강색"으로 자동 rebuild
///    되는지 확인 (Task 19에서 wiring한 글로벌 presetsProvider 구독).
///
/// 본 테스트는 `app.main()`을 부팅하지 않는다 — `getApplicationSupportDirectory()`
/// (path_provider) 로 인해 호스트 로컬 워크스페이스를 만지게 되어 격리가 깨지기
/// 때문이다. 대신 `integration_test` 바인딩 위에 LeftPane + 수동으로 만든
/// TabsNotifier/PresetsNotifier를 띄워 동일한 시나리오를 검증한다.
class _FakePresetRepo extends PresetRepository {
  _FakePresetRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late WorkspaceDb ws;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('preset_migration_');
    ws = await WorkspaceDb.openInMemory();
  });

  tearDown(() async {
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  testWidgets(
    'migration: v1 .cutmaster (color: 0xFFEF4444) → cp_red, 메타 줄 "빨강"',
    (tester) async {
      // === Step 1: tmp에 v1 레거시 파일 작성 ===
      final legacyPath = p.join(tmp.path, 'legacy.cutmaster');
      final legacyJson = {
        'schemaVersion': 1,
        'id': 'pj_legacy',
        'name': '레거시 프로젝트',
        'kerf': 3,
        'grainLocked': false,
        'showPartLabels': true,
        'useSingleSheet': false,
        'stocks': <Map<String, dynamic>>[],
        'parts': <Map<String, dynamic>>[
          {
            'id': 'p1',
            'length': 600.0,
            'width': 300.0,
            'qty': 2,
            'label': '문짝',
            'grain': 'none',
            'color': 0xFFEF4444, // 옛 빨강 ARGB
          },
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await File(legacyPath).writeAsString(jsonEncode(legacyJson));

      // === Step 2: PresetsNotifier 준비 (seed 풀 — cp_red 포함) ===
      final presets = PresetsNotifier(_FakePresetRepo());
      await presets.load();
      addTearDown(presets.dispose);
      expect(
        presets.state.colors.any((c) => c.id == 'cp_red'),
        true,
        reason: '시드에 cp_red(빨강)가 있어야 매칭이 성공한다.',
      );

      // === Step 3: ColorMatcher를 통과한 ProjectFileService로 v1 → v2 마이그레이션 로드 ===
      String? matcher(int argb) =>
          ColorMatcher(presets.state.colors).match(argb);
      final files = ProjectFileService(colorMatcher: matcher);
      final loaded = await files.read(legacyPath);
      expect(loaded.parts.single.colorPresetId, 'cp_red',
          reason: '0xFFEF4444 (legacy 빨강) 이 cp_red로 자동 매핑되어야 한다.');

      // === Step 4: TabsNotifier에 그 프로젝트로 탭을 만들어 LeftPane mount ===
      final tabs = TabsNotifier(
        workspace: ws,
        files: files,
        autosaveDir: p.join(tmp.path, 'autosave'),
        defaultProjectsDir: tmp.path,
        saveDebounce: const Duration(milliseconds: 5),
      );
      addTearDown(tabs.dispose);
      await tabs.openFile(legacyPath);
      expect(tabs.tabs.single.project.parts.single.colorPresetId, 'cp_red');

      await tester.pumpWidget(ProviderScope(
        overrides: [
          tabsProvider.overrideWith((_) => tabs),
          presetsProvider.overrideWith((_) => presets),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: const Scaffold(body: SizedBox(width: 380, child: LeftPane())),
        ),
      ));
      await tester.pumpAndSettle();

      // 메타 줄에 "빨강" 텍스트 — Task 9 / 10 / 19에서 wiring 완료된 부분.
      expect(find.text('빨강'), findsOneWidget,
          reason: '레거시 행의 색상 이름이 시드 cp_red 이름인 "빨강"으로 보여야 한다.');

      // === Step 5: cp_red 이름을 "빨강색"으로 변경 → 메타 줄 자동 갱신 ===
      final cpRed = presets.state.colors.firstWhere((c) => c.id == 'cp_red');
      await presets.updateColor(cpRed.copyWith(name: '빨강색'));
      await tester.pumpAndSettle();

      expect(find.text('빨강색'), findsOneWidget,
          reason: 'presetsProvider 변경 시 행 메타 줄이 추가 입력 없이 rebuild 되어야 한다.');
      expect(find.text('빨강'), findsNothing);
    },
  );
}
