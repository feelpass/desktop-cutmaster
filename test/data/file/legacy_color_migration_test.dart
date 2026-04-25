import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/file/project_file.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_legacy_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('legacy v1 file with color:int gets colorPresetId via matcher', () async {
    final path = p.join(tmp.path, 'old.cutmaster');
    File(path).writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'a', 'name': '책장', 'kerf': 3.0,
      'grainLocked': false, 'showPartLabels': true, 'useSingleSheet': false,
      'createdAt': '2024-01-01T00:00:00.000',
      'updatedAt': '2024-01-01T00:00:00.000',
      'parts': [{
        'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
        'label': '', 'grain': 'none', 'color': 0xFFEF4444,
      }],
      'stocks': [],
    }));

    final svc = ProjectFileService(
      colorMatcher: (argb) => argb == 0xFFEF4444 ? 'cp_red' : null,
    );
    final loaded = await svc.read(path);
    expect(loaded.parts.first.colorPresetId, 'cp_red');
  });
}
