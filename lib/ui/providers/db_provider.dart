import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/local/project_db.dart';
import '../../data/local/workspace_db.dart';

/// 데스크톱 SQLite (sqflite_common_ffi) 초기화 + DB 인스턴스.
final dbProvider = FutureProvider<ProjectDb>((ref) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'cutmaster.db');
  return ProjectDb.open(path);
});

final workspaceDbProvider = FutureProvider<WorkspaceDb>((ref) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dir = await getApplicationSupportDirectory();
  return WorkspaceDb.open(p.join(dir.path, 'workspace.db'));
});
