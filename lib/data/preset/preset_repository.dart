import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// presets.json을 읽어 [PresetState]를 반환한다. 절대 throw 하지 않는다 —
  /// 파일 없음/JSON 손상 시 [PresetState.seeded]로 폴백한다. 한 카테고리 키만
  /// 빠지거나 타입이 잘못된 경우 그 카테고리만 seed로 폴백한다 (다른 카테고리
  /// 사용자 데이터는 유지).
  Future<PresetState> load() async {
    final path = await _resolvePath();
    final file = File(path);
    if (!file.existsSync()) return PresetState.seeded;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final colorsRaw = json['colorPresets'];
      final partsRaw = json['partPresets'];
      final stocksRaw = json['stockPresets'];
      return PresetState(
        colors: colorsRaw is List
            ? colorsRaw
                .map((e) => ColorPreset.fromJson(e as Map<String, dynamic>))
                .toList()
            : seedColorPresets,
        parts: partsRaw is List
            ? partsRaw
                .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
                .toList()
            : seedPartPresets,
        stocks: stocksRaw is List
            ? stocksRaw
                .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
                .toList()
            : seedStockPresets,
      );
    } catch (e, st) {
      debugPrint('PresetRepository.load fallback: $e\n$st');
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
