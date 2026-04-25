import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;
import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/providers/tabs_provider.dart';
import 'package:cutmaster/ui/widgets/left_pane.dart';

/// Task 21 — 부품 프리셋 CRUD + 적용 + 색상 cascade fallback E2E.
///
/// 시나리오 (스펙):
/// 1. 새 프로젝트 (untitled) 시작.
/// 2. 부품 섹션 ⚙️ 클릭 → PresetManagementDialog 열기.
/// 3. "추가" 클릭 → 라벨="선반 600", 길이=600, 폭=300, 색="초록"(cp_green).
/// 4. 다이얼로그 닫기.
/// 5. PartsTable의 "프리셋" 버튼 → "선반 600" 선택.
/// 6. 새 부품 행 (qty=1, 600×300, 라벨 "선반 600", 메타 줄 "초록") 확인.
/// 7. 색상 관리 다이얼로그 → cp_green 삭제 (확인 다이얼로그 + cascade 경고 acknowledge).
/// 8. 닫기.
/// 9. 부품 행 메타 줄이 "자동"으로 fallback.
///
/// 본 테스트는 `app.main()`을 부팅하지 않는다 — path_provider가 실제 워크스페이스를
/// 만지게 되어 격리가 어렵기 때문. 대신 LeftPane 위젯 트리를 격리된
/// TabsNotifier/PresetsNotifier 위에 mount 한다. 다이얼로그 폼 필드 입력
/// (라벨/길이/폭/색상)은 ⚙️ → 추가 까지는 UI로 드라이브하고, 그 외 폼 필드는
/// `presets.updatePartPreset()`로 직접 set 한다 — 폼 fields 입력 자체는
/// `test/ui/widgets/preset_management_dialog_test.dart`에서 별도 단위 검증되어 있다.
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
    tmp = await Directory.systemTemp.createTemp('preset_crud_');
    ws = await WorkspaceDb.openInMemory();
  });

  tearDown(() async {
    await ws.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  testWidgets(
    'CRUD: ⚙️ → 추가 → 프리셋 적용 → 색상 cascade로 메타 줄 "자동" fallback',
    (tester) async {
      // === Setup: 시드 PresetsNotifier + 새 프로젝트 1개 ===
      final presets = PresetsNotifier(_FakePresetRepo());
      await presets.load();
      addTearDown(presets.dispose);
      expect(
        presets.state.colors.any((c) => c.id == 'cp_green'),
        true,
        reason: '시드에 cp_green(초록)가 있어야 시나리오가 성립한다.',
      );
      // 부품 프리셋은 시드가 비어 있어야 한다 — 그래야 "추가" 후 1개가 된다.
      expect(presets.state.parts, isEmpty);

      final tabs = TabsNotifier(
        workspace: ws,
        files: ProjectFileService(),
        autosaveDir: p.join(tmp.path, 'autosave'),
        defaultProjectsDir: tmp.path,
        saveDebounce: const Duration(milliseconds: 5),
      );
      addTearDown(tabs.dispose);
      tabs.newUntitled();
      final tabId = tabs.activeId!;

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

      // === Step 1: 부품 섹션 ⚙️ 탭 → PresetManagementDialog ===
      // ⚙️ 버튼은 부품/자재 섹션 헤더에 각각 1개씩 있으므로 first.
      final gearTooltip = find.byTooltip('프리셋 관리');
      expect(gearTooltip, findsWidgets);
      await tester.tap(gearTooltip.first);
      await tester.pumpAndSettle();
      expect(find.text('부품 프리셋 관리'), findsOneWidget);

      // === Step 2: "추가" 버튼 → 새 부품 프리셋 1개 (default label "새 부품 프리셋") ===
      await tester.tap(find.byTooltip('추가'));
      await tester.pumpAndSettle();
      expect(presets.state.parts.length, 1);
      final addedId = presets.state.parts.single.id;

      // === Step 3: 라벨/길이/폭/색상을 스펙대로 set ===
      // 폼 텍스트 필드를 픽셀로 식별하기보다 API로 set — 폼 필드 자체는
      // preset_management_dialog_test.dart에서 별도 검증.
      await presets.updatePartPreset(DimensionPreset(
        id: addedId,
        label: '선반 600',
        length: 600,
        width: 300,
        colorPresetId: 'cp_green',
        grainDirection: GrainDirection.none,
      ));
      await tester.pumpAndSettle();

      // === Step 4: 다이얼로그 닫기 ===
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(find.text('부품 프리셋 관리'), findsNothing);

      // === Step 5: "프리셋" 버튼 → "선반 600" 선택 ===
      // PartsTable의 "프리셋" 버튼 — 자재/부품 모두 같은 라벨이지만,
      // PartsTable에는 OutlinedButton.icon, StocksTable도 동일.
      // 부품 섹션 안에 있는 첫 번째 "프리셋" 텍스트 버튼.
      final presetButtons = find.widgetWithText(OutlinedButton, '프리셋');
      expect(presetButtons, findsWidgets);
      await tester.tap(presetButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('부품 프리셋 선택'), findsOneWidget);
      await tester.tap(find.text('선반 600'));
      await tester.pumpAndSettle();

      // === Step 6: 새 부품 행 확인 ===
      final activeTab = tabs.tabs.firstWhere((t) => t.id == tabId);
      expect(activeTab.project.parts.length, 1);
      final addedPart = activeTab.project.parts.single;
      expect(addedPart.qty, 1);
      expect(addedPart.length, 600);
      expect(addedPart.width, 300);
      expect(addedPart.label, '선반 600');
      expect(addedPart.colorPresetId, 'cp_green');

      // 메타 줄에 "초록" 텍스트.
      expect(find.text('초록'), findsOneWidget,
          reason: '적용 직후 행 메타 줄에 cp_green 이름인 "초록"이 보여야 한다.');
      expect(find.text('자동'), findsNothing);

      // === Step 7: 색상 cascade — cp_green removeColor() ===
      // ColorPresetManagementDialog의 삭제 확인 다이얼로그를 UI로 드라이브하기보다
      // PresetsNotifier.removeColor() 자체를 호출. cascade 동작 (Task 5)이
      // unit test 되어 있고, 본 테스트는 "삭제 후 행이 자동으로 fallback 한다"
      // 라는 E2E reactive 흐름을 검증.
      await presets.removeColor('cp_green');
      await tester.pumpAndSettle();

      // === Step 8: 부품 행 메타 줄 "자동" fallback ===
      expect(find.text('초록'), findsNothing);
      expect(find.text('자동'), findsOneWidget,
          reason: 'cp_green 삭제 시 행의 colorPresetId 참조가 풀의 ColorPreset과 '
              '매칭되지 않아 _MetaLine이 "자동"으로 표시되어야 한다.');

      // 부품 프리셋의 colorPresetId도 cascade로 null이 되어야 한다 (Task 5).
      // (ColorPreset만 삭제됐고 부품 프리셋의 다른 필드는 유지.)
      final updatedPreset =
          presets.state.parts.firstWhere((d) => d.id == addedId);
      expect(updatedPreset.colorPresetId, isNull);
      expect(updatedPreset.label, '선반 600');
      expect(updatedPreset.length, 600);
      expect(updatedPreset.width, 300);
    },
  );
}
