import 'dart:io';

import '../file/project_file.dart';
import '../local/project_db.dart';
import '../local/workspace_db.dart';

class MigrationFailure {
  final String projectId;
  final String projectName;
  final Object error;
  const MigrationFailure({
    required this.projectId,
    required this.projectName,
    required this.error,
  });
}

class MigrationResult {
  final int migrated;
  final int failed;
  final List<MigrationFailure> failures;
  const MigrationResult({
    required this.migrated,
    required this.failed,
    this.failures = const [],
  });
}

/// 옛 ProjectDb의 모든 프로젝트를 [targetFolder]에 .cutmaster 파일로 export하고
/// WorkspaceDb의 recent_file에 등록한다. 옛 DB는 read-only로 두고 건드리지 않는다.
///
/// **멱등 아님.** 같은 인스턴스를 두 번 실행하면 모든 프로젝트가 `(2)` 접미사로
/// 다시 export된다. 호출자(예: `main.dart`)는 "이미 마이그레이션됨" 게이트를
/// (예: `WorkspaceDb.listRecentFiles()` 비어있을 때만 실행)로 보장해야 한다.
class LegacyMigrator {
  LegacyMigrator({
    required this.legacy,
    required this.workspace,
    required this.targetFolder,
    ProjectFileService? files,
  }) : files = files ?? ProjectFileService();

  final ProjectDb legacy;
  final WorkspaceDb workspace;
  final String targetFolder;
  final ProjectFileService files;

  Future<MigrationResult> run() async {
    final projects = await legacy.listProjects();
    var ok = 0, fail = 0;
    final failures = <MigrationFailure>[];
    for (final pr in projects) {
      try {
        final path = await files.writeNew(
          folder: targetFolder,
          baseName: pr.name,
          project: pr,
        );
        try {
          await workspace.touchRecentFile(path, pr.name);
          ok++;
        } catch (e) {
          // recent 등록은 실패했지만 파일은 이미 있음 — 파일 정리 (best-effort) 후 fail
          try {
            await File(path).delete();
          } catch (_) {}
          fail++;
          failures.add(MigrationFailure(
              projectId: pr.id, projectName: pr.name, error: e));
        }
      } catch (e) {
        fail++;
        failures.add(MigrationFailure(
            projectId: pr.id, projectName: pr.name, error: e));
      }
    }
    return MigrationResult(migrated: ok, failed: fail, failures: failures);
  }
}
