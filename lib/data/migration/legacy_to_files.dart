import '../file/project_file.dart';
import '../local/project_db.dart';
import '../local/workspace_db.dart';

class MigrationResult {
  final int migrated;
  final int failed;
  const MigrationResult(this.migrated, this.failed);
}

/// 옛 ProjectDb의 모든 프로젝트를 [targetFolder]에 .cutmaster 파일로 export하고
/// WorkspaceDb의 recent_file에 등록한다. 옛 DB는 read-only로 두고 건드리지 않는다.
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
    for (final p in projects) {
      try {
        final path = await files.writeNew(
          folder: targetFolder,
          baseName: p.name,
          project: p,
        );
        await workspace.touchRecentFile(path, p.name);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    return MigrationResult(ok, fail);
  }
}
