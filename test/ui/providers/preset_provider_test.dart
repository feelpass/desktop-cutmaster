import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_pp_test_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('addColor / updateColor / removeColor persist to disk', () async {
    final path = p.join(tmp.path, 'presets.json');
    final repo = PresetRepository(filePath: path);
    final notifier = PresetsNotifier(repo);
    await notifier.load();

    final initialLen = notifier.state.colors.length;
    final added = ColorPreset(id: 'cp_x', name: '내색', argb: 0xFF112233);
    await notifier.addColor(added);
    expect(notifier.state.colors.length, initialLen + 1);

    await notifier.updateColor(
        added.copyWith(name: '내색2', argb: 0xFF445566));
    expect(notifier.state.colors.last.name, '내색2');

    await notifier.removeColor('cp_x');
    expect(notifier.state.colors.length, initialLen);

    final reloaded = await PresetRepository(filePath: path).load();
    expect(reloaded.colors.length, initialLen);
  });

  test('removeColor cascades colorPresetId=null on stock/part presets', () async {
    final path = p.join(tmp.path, 'presets.json');
    final repo = PresetRepository(filePath: path);
    final notifier = PresetsNotifier(repo);
    await notifier.load();

    final c = ColorPreset(id: 'cp_y', name: '연두색', argb: 0xFF00FF00);
    await notifier.addColor(c);
    await notifier.addStockPreset(DimensionPreset(
      id: 'sp_test', length: 100, width: 50, label: 'A',
      colorPresetId: 'cp_y', grainDirection: GrainDirection.none,
    ));
    await notifier.removeColor('cp_y');
    final s = notifier.state.stocks.firstWhere((x) => x.id == 'sp_test');
    expect(s.colorPresetId, isNull);
  });

  test('part preset CRUD', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();

    const part = DimensionPreset(
      id: 'pp_x', length: 600, width: 300, label: '선반',
      colorPresetId: null, grainDirection: GrainDirection.none,
    );
    await notifier.addPartPreset(part);
    expect(notifier.state.parts.length, 1);

    await notifier.updatePartPreset(part.copyWith(label: '선반 600'));
    expect(notifier.state.parts.first.label, '선반 600');

    await notifier.removePartPreset('pp_x');
    expect(notifier.state.parts, isEmpty);
  });

  test('removeColor cascades on part presets too', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();

    await notifier.addColor(
        const ColorPreset(id: 'cp_z', name: 'Z', argb: 0xFF333333));
    await notifier.addPartPreset(const DimensionPreset(
      id: 'pp_z', length: 600, width: 300, label: '',
      colorPresetId: 'cp_z', grainDirection: GrainDirection.lengthwise,
    ));
    await notifier.removeColor('cp_z');

    final part = notifier.state.parts.firstWhere((p) => p.id == 'pp_z');
    expect(part.colorPresetId, isNull);
    // sibling fields preserved:
    expect(part.length, 600);
    expect(part.width, 300);
    expect(part.grainDirection, GrainDirection.lengthwise);
  });

  test('listeners fire on every mutation', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();

    var count = 0;
    notifier.addListener(() => count++);

    await notifier.addColor(
        const ColorPreset(id: 'cp_a', name: 'A', argb: 0xFFAAAAAA));
    await notifier.updateColor(
        const ColorPreset(id: 'cp_a', name: 'A2', argb: 0xFFAAAAAA));
    await notifier.removeColor('cp_a');

    expect(count, greaterThanOrEqualTo(3));
  });

  test('colorById hit / miss / null', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();

    // hit (seed has 'cp_red')
    expect(notifier.colorById('cp_red')?.name, '빨강');
    // miss
    expect(notifier.colorById('cp_does_not_exist'), isNull);
    // null input
    expect(notifier.colorById(null), isNull);
  });

  test('stock preset update preserves other items', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();

    final initialIds = notifier.state.stocks.map((s) => s.id).toList();

    await notifier.addStockPreset(const DimensionPreset(
      id: 'sp_new', length: 1000, width: 500, label: 'New',
      colorPresetId: null, grainDirection: GrainDirection.none,
    ));
    await notifier.updateStockPreset(const DimensionPreset(
      id: 'sp_new', length: 1500, width: 750, label: 'Updated',
      colorPresetId: null, grainDirection: GrainDirection.none,
    ));

    // initial seeds still present
    for (final id in initialIds) {
      expect(notifier.state.stocks.any((s) => s.id == id), true);
    }
    final updated = notifier.state.stocks.firstWhere((s) => s.id == 'sp_new');
    expect(updated.length, 1500);
    expect(updated.label, 'Updated');
  });

  test('lastSaveError starts null and stays null on success', () async {
    final notifier = PresetsNotifier(
        PresetRepository(filePath: p.join(tmp.path, 'presets.json')));
    await notifier.load();
    await notifier.addColor(
        const ColorPreset(id: 'cp_ok', name: 'OK', argb: 0xFFCCCCCC));
    expect(notifier.lastSaveError, isNull);
  });
}
