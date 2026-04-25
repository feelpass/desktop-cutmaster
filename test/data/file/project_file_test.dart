import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
    final p = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    expect(path, '${tmp.path}/책장.cutmaster');
    expect(File(path).existsSync(), true);

    final loaded = await svc.read(path);
    expect(loaded.name, '책장');
  });

  test('writeNew adds (2) suffix on collision', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');

    final p1 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);
    final p2 = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    expect(p1, '${tmp.path}/책장.cutmaster');
    expect(p2, '${tmp.path}/책장 (2).cutmaster');
  });

  test('overwrite is atomic (no .tmp left behind)', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');
    final path = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);

    final p2 = p.copyWith(kerf: 7);
    await svc.overwrite(path, p2);

    final loaded = await svc.read(path);
    expect(loaded.kerf, 7);

    final tmpFiles = tmp.listSync().where((f) => f.path.endsWith('.tmp'));
    expect(tmpFiles, isEmpty);
  });

  test('rename moves file with suffix on collision', () async {
    final svc = ProjectFileService();
    final p = Project.create(id: 'a', name: '책장');
    final pathA = await svc.writeNew(folder: tmp.path, baseName: '책장', project: p);
    await svc.writeNew(folder: tmp.path, baseName: '책상', project: p);

    final newPath = await svc.rename(pathA, '책상');
    expect(newPath, '${tmp.path}/책상 (2).cutmaster');
    expect(File(pathA).existsSync(), false);
  });

  test('read throws FormatException on corrupt JSON', () async {
    final f = File('${tmp.path}/bad.cutmaster')..writeAsStringSync('not json');
    expect(
      () => ProjectFileService().read(f.path),
      throwsA(isA<FormatException>()),
    );
  });
}
