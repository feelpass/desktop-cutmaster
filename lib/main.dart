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
import 'l10n/app_localizations.dart';
import 'ui/main_screen.dart';
import 'ui/providers/tabs_provider.dart';
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

  final ws = await WorkspaceDb.open(p.join(supportDir.path, 'workspace.db'));

  // 1회성 마이그레이션. 옛 cutmaster.db가 있고 워크스페이스에 등록된 최근 파일이
  // 전혀 없을 때만 실행 — 이미 마이그레이션됐거나 새 사용자가 작업을 시작한 경우는 건너뜀.
  final legacyPath = p.join(supportDir.path, 'cutmaster.db');
  if (File(legacyPath).existsSync() &&
      (await ws.listRecentFiles()).isEmpty) {
    final legacy = await ProjectDb.open(legacyPath);
    await LegacyMigrator(
      legacy: legacy,
      workspace: ws,
      targetFolder: projectsDir,
    ).run();
    await legacy.close();
  }

  final notifier = TabsNotifier(
    workspace: ws,
    files: ProjectFileService(),
    autosaveDir: autosaveDir,
    defaultProjectsDir: projectsDir,
  );
  await notifier.restoreSession();
  if (notifier.tabs.isEmpty) notifier.newUntitled();

  runApp(ProviderScope(
    overrides: [tabsProvider.overrideWith((_) => notifier)],
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
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: const MainScreen(),
    );
  }
}
