import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/file/project_file.dart';
import 'package:cutmaster/domain/models/project.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cutmaster_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('writeNew creates file and returns chosen path', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);

    expect(path, p.join(tmp.path, '책장.cutmaster'));
    expect(File(path).existsSync(), true);

    final loaded = await svc.read(path);
    expect(loaded.name, '책장');
  });

  test('writeNew adds (2) suffix on collision', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');

    final p1 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);
    final p2 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);

    expect(p1, p.join(tmp.path, '책장.cutmaster'));
    expect(p2, p.join(tmp.path, '책장 (2).cutmaster'));
  });

  test('overwrite is atomic (no .tmp left behind)', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);

    final p2 = p0.copyWith(kerf: 7);
    await svc.overwrite(path, p2);

    final loaded = await svc.read(path);
    expect(loaded.kerf, 7);

    final tmpFiles = tmp.listSync().where((f) => f.path.endsWith('.tmp'));
    expect(tmpFiles, isEmpty);
  });

  test('rename moves file with suffix on collision', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final pathA = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);
    await svc.writeNew(folder: tmp.path, baseName: '책상', project: p0);

    final newPath = await svc.rename(pathA, '책상');
    expect(newPath, p.join(tmp.path, '책상 (2).cutmaster'));
    expect(File(pathA).existsSync(), false);
  });

  test('rename to same name is no-op', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);

    final result = await svc.rename(path, '책장');
    expect(result, path);
    expect(File(path).existsSync(), true);
    expect(tmp.listSync().length, 1);
  });

  test('read throws FormatException on corrupt JSON', () async {
    final f = File(p.join(tmp.path, 'bad.cutmaster'))..writeAsStringSync('not json');
    expect(
      () => ProjectFileService().read(f.path),
      throwsA(isA<FormatException>()),
    );
  });

  test('overwrite throws ConflictException when expectedMtime stale', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final path =
        await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);

    // Touch file to make its mtime newer than what we'll claim
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await svc.overwrite(path, p0); // bumps mtime

    final stale = DateTime.now().subtract(const Duration(seconds: 5));
    expect(
      () => svc.overwrite(path, p0, expectedMtime: stale),
      throwsA(isA<ConflictException>()),
    );
  });

  test('readWithMtime returns project + file mtime', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final path =
        await svc.writeNew(folder: tmp.path, baseName: '책장', project: p0);
    final res = await svc.readWithMtime(path);
    expect(res.project.name, '책장');
    expect(res.mtime, isA<DateTime>());
  });

  // 사용자가 NSSavePanel로 새 경로를 picker한 직후 첫 저장 시뮬레이션 —
  // overwrite를 한 번도 본 적 없는 fresh path. 가장 흔한 Save As 진입점이므로
  // 회귀 안 나도록 명시적으로 검증.
  test('overwrite to a fresh path that does not yet exist', () async {
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');
    final freshPath = p.join(tmp.path, '아직-없는-파일.cutmaster');

    expect(File(freshPath).existsSync(), false);
    await svc.overwrite(freshPath, p0);

    expect(File(freshPath).existsSync(), true);
    final loaded = await svc.read(freshPath);
    expect(loaded.name, '책장');
  });

  // macOS sandbox 회귀 가드: `.tmp` 사이드 파일 쓰기가 막힌 상황을 호스트에서
  // 시뮬레이션 — 부모 디렉토리에서 쓰기 권한을 빼앗고 destination에는 쓸 수
  // 있게 한 뒤, overwrite가 fallback path로 성공하는지 확인.
  //
  // 실제 macOS sandbox 환경(`files.user-selected.read-write`)에서는 user-selected
  // URL 한 개에만 write가 허가되어 sibling `.tmp` 쓰기가 실패한다. 이 테스트는
  // 그 상황을 chmod로 흉내낸다.
  test('overwrite falls back to direct write when .tmp is blocked', () async {
    if (Platform.isWindows) return; // chmod-기반 시뮬레이션은 POSIX 한정
    final svc = ProjectFileService();
    final p0 = Project.create(id: 'a', name: '책장');

    // 1) 먼저 정상 경로로 한 번 쓴다.
    final path = await svc.writeNew(
        folder: tmp.path, baseName: 'sandboxed', project: p0);
    expect(File(path).existsSync(), true);

    // 2) 부모 디렉토리를 r-x로 잠가 새 파일(`.tmp`) 생성을 막는다.
    //    기존 파일에 대한 write는 inode 단위라 여전히 가능.
    final dir = Directory(tmp.path);
    await Process.run('chmod', ['555', dir.path]);
    addTearDown(() async {
      await Process.run('chmod', ['755', dir.path]);
    });

    // 3) `.tmp` 새 파일 생성이 막혀도 overwrite는 fallback으로 성공해야 한다.
    final updated = p0.copyWith(kerf: 9);
    await svc.overwrite(path, updated);

    final loaded = await svc.read(path);
    expect(loaded.kerf, 9);
  });

  group('sanitizeBaseName', () {
    test('strips forbidden chars', () {
      expect(ProjectFileService.sanitizeBaseName(r'a/b\c:d*e?f"g<h>i|j'), 'abcdefghij');
    });
    test('returns 새 프로젝트 for empty / whitespace', () {
      expect(ProjectFileService.sanitizeBaseName(''), '새 프로젝트');
      expect(ProjectFileService.sanitizeBaseName('   '), '새 프로젝트');
    });
    test('trims surrounding whitespace', () {
      expect(ProjectFileService.sanitizeBaseName('  책장  '), '책장');
    });
  });
}
