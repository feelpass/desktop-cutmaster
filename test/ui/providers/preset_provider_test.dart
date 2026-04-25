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
}
