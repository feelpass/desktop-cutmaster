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
