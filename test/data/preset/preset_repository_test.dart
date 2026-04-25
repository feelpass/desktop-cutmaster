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

  test('load with empty JSON object falls back to seeds (no silent data loss)', () async {
    final path = p.join(tmp.path, 'presets.json');
    File(path).writeAsStringSync('{}');
    final repo = PresetRepository(filePath: path);
    final state = await repo.load();
    expect(state.colors, seedColorPresets);
    expect(state.parts, seedPartPresets);
    expect(state.stocks, seedStockPresets);
  });

  test('load with only colorPresets present keeps user colors but seeds parts/stocks', () async {
    final path = p.join(tmp.path, 'presets.json');
    File(path).writeAsStringSync('''
{
  "version": 1,
  "colorPresets": [{"id": "cp_only", "name": "Only", "argb": 4294901760}]
}
''');
    final repo = PresetRepository(filePath: path);
    final state = await repo.load();
    expect(state.colors.length, 1);
    expect(state.colors.first.id, 'cp_only');
    // parts and stocks were missing — fall back to seeds, not empty
    expect(state.parts, seedPartPresets);
    expect(state.stocks, seedStockPresets);
  });

  test('save then save again overwrites existing file (no rename failure)', () async {
    final path = p.join(tmp.path, 'presets.json');
    final repo = PresetRepository(filePath: path);

    await repo.save(const PresetState(
      colors: [ColorPreset(id: 'cp_a', name: 'A', argb: 0xFF111111)],
      parts: [],
      stocks: [],
    ));
    expect(File(path).existsSync(), true);

    await repo.save(const PresetState(
      colors: [ColorPreset(id: 'cp_b', name: 'B', argb: 0xFF222222)],
      parts: [],
      stocks: [],
    ));

    final state = await repo.load();
    expect(state.colors.single.id, 'cp_b');

    // .tmp leftover check
    final leftovers = tmp.listSync().where((f) => f.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });
}
