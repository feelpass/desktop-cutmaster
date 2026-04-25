import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/models/project.dart';

const _ext = '.cutmaster';
const _forbidden = r'/\:*?"<>|';

/// 외부 편집기(Dropbox/iCloud 등)가 로드 후 우리 저장 사이에 파일을
/// 수정한 경우 throw 된다.
class ConflictException implements Exception {
  final String path;
  final DateTime expected;
  final DateTime found;
  ConflictException(this.path, this.expected, this.found);
  @override
  String toString() =>
      'ConflictException at $path: expected mtime $expected, found $found';
}

/// [ProjectFileService.readWithMtime] 결과 — Project + 디스크 mtime.
class FileWithMtime {
  final Project project;
  final DateTime mtime;
  const FileWithMtime(this.project, this.mtime);
}

class ProjectFileService {
  /// [colorMatcher]는 v1 .cutmaster 파일을 읽을 때 사용. v1에는 `color: int`
  /// (ARGB) 필드가 있었고, v2부터는 글로벌 ColorPreset id로 참조한다.
  /// matcher는 ARGB → ColorPreset.id를 돌려주어야 한다 — null이면 색이 사라진다.
  /// 호출자(보통 main.dart)가 PresetRepository를 들고 있다가 주입한다.
  ProjectFileService({this.colorMatcher});

  final String? Function(int argb)? colorMatcher;

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
  ///
  /// [expectedMtime]이 주어지고 디스크의 mtime이 1초 넘게 차이나면
  /// 외부에서 변경된 것으로 간주하고 [ConflictException]을 던진다.
  /// 반환: 새로 기록된 파일의 mtime.
  Future<DateTime> overwrite(
    String path,
    Project project, {
    DateTime? expectedMtime,
  }) async {
    final f = File(path);
    if (expectedMtime != null && f.existsSync()) {
      final actual = await f.lastModified();
      // 1초 이상 차이날 때만 충돌. 파일시스템마다 mtime 정밀도가 다름.
      if (actual.difference(expectedMtime).abs() >
          const Duration(seconds: 1)) {
        throw ConflictException(path, expectedMtime, actual);
      }
    }
    await _atomicWrite(path, project);
    return File(path).lastModified();
  }

  /// 파일 한 개를 같은 폴더 안에서 새 baseName으로 rename. 충돌 시 (2) suffix.
  /// 반환: 새 경로.
  Future<String> rename(String path, String newBaseName) async {
    final folder = p.dirname(path);
    final clean = sanitizeBaseName(newBaseName);
    final desiredPath = p.join(folder, '$clean$_ext');
    if (desiredPath == path) return path;
    final newPath = await _resolveCollision(folder, clean);
    if (newPath == path) return path;
    await File(path).rename(newPath);
    return newPath;
  }

  /// 파일에서 Project 로드. JSON / schemaVersion 손상 시 FormatException.
  /// v1 파일은 [colorMatcher]를 통해 ARGB → ColorPreset id로 마이그레이션된다.
  Future<Project> read(String path) async {
    final raw = await File(path).readAsString();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return Project.fromJson(j, colorMatcher: colorMatcher);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid .cutmaster: $e');
    }
  }

  /// [read]와 같지만 디스크의 lastModified mtime을 함께 반환한다.
  /// 충돌 감지를 위해 호출자가 mtime을 함께 보관할 때 사용한다.
  Future<FileWithMtime> readWithMtime(String path) async {
    final project = await read(path);
    final mtime = await File(path).lastModified();
    return FileWithMtime(project, mtime);
  }

  /// 파일명으로 안전한 형태로 [name] 정규화 (금지 문자 제거).
  static String sanitizeBaseName(String name) {
    var s = name.trim();
    for (final c in _forbidden.split('')) {
      s = s.replaceAll(c, '');
    }
    if (s.isEmpty) s = '새 프로젝트';
    return s;
  }

  /// single-process assumption — caller-level uniqueness.
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

  /// single-writer assumption.
  Future<void> _atomicWrite(String path, Project project) async {
    final tmp = '$path.tmp';
    final raw = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await File(tmp).writeAsString(raw, flush: true);
    await File(tmp).rename(path);
  }
}
