import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/project.dart';

const _ext = '.cutmaster';
const _kForbidden = r'/\:*?"<>|';

class ProjectFileService {
  /// 같은 폴더 안에서 충돌 안 나는 경로를 만들어 [project]를 새 파일로 쓴다.
  /// 반환: 실제로 쓰인 절대 경로.
  Future<String> writeNew({
    required String folder,
    required String baseName,
    required Project project,
  }) async {
    await Directory(folder).create(recursive: true);
    final path = await _resolveCollision(folder, baseName);
    await _atomicWrite(path, project);
    return path;
  }

  /// 같은 경로에 atomic으로 덮어쓴다.
  Future<void> overwrite(String path, Project project) async {
    await _atomicWrite(path, project);
  }

  /// 파일 한 개를 같은 폴더 안에서 새 baseName으로 rename. 충돌 시 (2) suffix.
  /// 반환: 새 경로.
  Future<String> rename(String path, String newBaseName) async {
    final folder = p.dirname(path);
    final newPath = await _resolveCollision(folder, newBaseName);
    if (newPath == path) return path;
    await File(path).rename(newPath);
    return newPath;
  }

  /// 파일에서 Project 로드. JSON / schemaVersion 손상 시 FormatException.
  Future<Project> read(String path) async {
    final raw = await File(path).readAsString();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Project.fromJson(j);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid .cutmaster: $e');
    }
  }

  /// 파일명으로 안전한 형태로 [name] 정규화 (금지 문자 제거).
  static String sanitizeBaseName(String name) {
    var s = name.trim();
    for (final c in _kForbidden.split('')) {
      s = s.replaceAll(c, '');
    }
    if (s.isEmpty) s = '새 프로젝트';
    return s;
  }

  Future<String> _resolveCollision(String folder, String baseName) async {
    final clean = sanitizeBaseName(baseName);
    var path = p.join(folder, '$clean$_ext');
    if (!File(path).existsSync()) return path;
    var i = 2;
    while (true) {
      path = p.join(folder, '$clean ($i)$_ext');
      if (!File(path).existsSync()) return path;
      i++;
    }
  }

  Future<void> _atomicWrite(String path, Project project) async {
    final tmp = '$path.tmp';
    final raw = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await File(tmp).writeAsString(raw, flush: true);
    await File(tmp).rename(path);
  }
}
