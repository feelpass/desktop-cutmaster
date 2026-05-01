import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/file/project_file.dart';
import 'data/local/project_db.dart';
import 'data/local/workspace_db.dart';
import 'data/migration/legacy_to_files.dart';
import 'data/preset/color_matcher.dart';
import 'data/preset/preset_repository.dart';
import 'l10n/app_localizations.dart';
import 'ui/main_screen.dart';
import 'ui/providers/preset_provider.dart';
import 'ui/providers/tabs_provider.dart';
import 'ui/providers/theme_mode_provider.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final supportDir = await getApplicationSupportDirectory();
  final docsDir = await getApplicationDocumentsDirectory();
  final projectsDir = p.join(docsDir.path, 'Cutmaster');
  final autosaveDir = p.join(supportDir.path, 'autosave');
  await Directory(projectsDir).create(recursive: true);
  await Directory(autosaveDir).create(recursive: true);

  // 글로벌 프리셋을 먼저 로드. ProjectFileService / ProjectDb의 colorMatcher
  // 클로저가 *호출 시점*의 프리셋 스냅샷을 보도록 하기 위해 notifier.state를 직접 참조한다
  // (사용자가 레거시 파일을 열기 전에 프리셋을 편집한 경우에도 최신 목록 반영).
  final presetRepo = PresetRepository();
  final presetsNotifier = PresetsNotifier(presetRepo);
  await presetsNotifier.load();
  String? colorMatcher(int argb) =>
      ColorMatcher(presetsNotifier.state.colors).match(argb);

  final ws = await WorkspaceDb.open(p.join(supportDir.path, 'workspace.db'));

  // 1회성 마이그레이션. 옛 cutmaster.db가 있고 워크스페이스에 등록된 최근 파일이
  // 전혀 없을 때만 실행 — 이미 마이그레이션됐거나 새 사용자가 작업을 시작한 경우는 건너뜀.
  final legacyPath = p.join(supportDir.path, 'cutmaster.db');
  if (File(legacyPath).existsSync() &&
      (await ws.listRecentFiles()).isEmpty) {
    final legacy =
        await ProjectDb.open(legacyPath, colorMatcher: colorMatcher);
    await LegacyMigrator(
      legacy: legacy,
      workspace: ws,
      targetFolder: projectsDir,
      files: ProjectFileService(colorMatcher: colorMatcher),
    ).run();
    await legacy.close();
  }

  final notifier = TabsNotifier(
    workspace: ws,
    files: ProjectFileService(colorMatcher: colorMatcher),
    autosaveDir: autosaveDir,
    defaultProjectsDir: projectsDir,
  );
  await notifier.restoreSession();
  if (notifier.tabs.isEmpty) notifier.newUntitled();

  final initialThemeMode = await ThemeModeNotifier.loadInitial(ws);
  final themeNotifier = ThemeModeNotifier(ws, initialThemeMode);

  runApp(ProviderScope(
    overrides: [
      tabsProvider.overrideWith((_) => notifier),
      presetsProvider.overrideWith((_) => presetsNotifier),
      themeModeProvider.overrideWith((_) => themeNotifier),
    ],
    child: const CutmasterApp(),
  ));
}

class CutmasterApp extends ConsumerStatefulWidget {
  const CutmasterApp({super.key});
  @override
  ConsumerState<CutmasterApp> createState() => _CutmasterAppState();
}

class _CutmasterAppState extends ConsumerState<CutmasterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    final n = ref.read(tabsProvider);
    try {
      await n.flushAll();
      await n.saveSession();
    } catch (e) {
      debugPrint('didRequestAppExit save failed: $e');
    }
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: const MainScreen(),
    );
  }
}
