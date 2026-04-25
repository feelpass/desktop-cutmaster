import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'preset_models.dart';
import 'preset_seeds.dart';

/// 색상/부품/자재 프리셋 묶음. presets.json의 메모리 표현.
class PresetState {
  final List<ColorPreset> colors;
  final List<DimensionPreset> parts;
  final List<DimensionPreset> stocks;
  const PresetState({
    required this.colors,
    required this.parts,
    required this.stocks,
  });

  /// 파일이 없거나 손상되었을 때 fallback으로 쓰는 초기값.
  static const seeded = PresetState(
    colors: seedColorPresets,
    parts: seedPartPresets,
    stocks: seedStockPresets,
  );
}

/// presets.json I/O. 기본 경로는 path_provider의
/// applicationSupportDirectory이며, 테스트에선 [filePath]로 주입한다.
class PresetRepository {
  PresetRepository({String? filePath}) : _explicitPath = filePath;
  final String? _explicitPath;

  static const _version = 1;

  Future<String> _resolvePath() async {
    if (_explicitPath != null) return _explicitPath!;
    final dir = await getApplicationSupportDirectory();
    final cm = Directory(p.join(dir.path));
    if (!cm.existsSync()) cm.createSync(recursive: true);
    return p.join(cm.path, 'presets.json');
  }

  Future<PresetState> load() async {
    final path = await _resolvePath();
    final f = File(path);
    if (!f.existsSync()) return PresetState.seeded;
    try {
      final raw = await f.readAsString();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PresetState(
        colors: (j['colorPresets'] as List? ?? [])
            .map((e) => ColorPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        parts: (j['partPresets'] as List? ?? [])
            .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        stocks: (j['stockPresets'] as List? ?? [])
            .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      // JSON 손상/스키마 불일치 등 어떤 예외든 seed로 fallback.
      return PresetState.seeded;
    }
  }

  Future<void> save(PresetState s) async {
    final path = await _resolvePath();
    final tmp = '$path.tmp';
    final body = const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'colorPresets': s.colors.map((c) => c.toJson()).toList(),
      'partPresets': s.parts.map((p) => p.toJson()).toList(),
      'stockPresets': s.stocks.map((p) => p.toJson()).toList(),
    });
    await File(tmp).writeAsString(body, flush: true);
    await File(tmp).rename(path);
  }
}
