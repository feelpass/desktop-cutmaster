import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_preset_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('load on missing file returns seeds', () async {
    final repo = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final state = await repo.load();
    expect(state.colors, seedColorPresets);
    expect(state.stocks, seedStockPresets);
    expect(state.parts, isEmpty);
  });

  test('save creates file and load round-trips', () async {
    final repo = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final added = ColorPreset(id: 'cp_custom', name: '내색', argb: 0xFF112233);
    final state = PresetState(
      colors: [...seedColorPresets, added],
      parts: const [],
      stocks: seedStockPresets,
    );
    await repo.save(state);

    final repo2 = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final loaded = await repo2.load();
    expect(loaded.colors.last, added);
  });

  test('load on corrupt JSON falls back to seeds', () async {
    final path = p.join(tmp.path, 'presets.json');
    File(path).writeAsStringSync('{not json');
    final repo = PresetRepository(filePath: path);
    final state = await repo.load();
    expect(state.colors, seedColorPresets); // fallback
  });
}
