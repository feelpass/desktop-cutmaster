import '../../domain/models/stock_sheet.dart' show GrainDirection;

/// 사용자 정의 색상 프리셋. presets.json에 저장되어 부품/자재 프리셋과
/// 행에서 id로 참조된다. 이름과 ARGB를 함께 보유 — UI에서 텍스트로도 표시.
class ColorPreset {
  final String id;
  final String name;
  final int argb;
  const ColorPreset({required this.id, required this.name, required this.argb});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'argb': argb};

  factory ColorPreset.fromJson(Map<String, dynamic> j) => ColorPreset(
        id: j['id'] as String,
        name: j['name'] as String,
        argb: j['argb'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is ColorPreset &&
      other.id == id &&
      other.name == name &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(id, name, argb);
}

/// 부품/자재 치수 프리셋. (length, width, label, grainDirection, colorPresetId)
/// 조합을 저장하고 적용 시 소비자가 qty=1을 추가해 CutPart/StockSheet으로 변환한다.
/// colorPresetId가 null이면 "자동 색상" — 적용 시 ID 해시 기반으로 색이 정해진다.
class DimensionPreset {
  final String id;
  final double length;
  final double width;
  final String label;
  final String? colorPresetId;
  final GrainDirection grainDirection;

  const DimensionPreset({
    required this.id,
    required this.length,
    required this.width,
    required this.label,
    required this.colorPresetId,
    required this.grainDirection,
  });

  DimensionPreset copyWith({
    String? id,
    double? length,
    double? width,
    String? label,
    String? colorPresetId,
    GrainDirection? grainDirection,
    bool clearColor = false,
  }) =>
      DimensionPreset(
        id: id ?? this.id,
        length: length ?? this.length,
        width: width ?? this.width,
        label: label ?? this.label,
        colorPresetId:
            clearColor ? null : (colorPresetId ?? this.colorPresetId),
        grainDirection: grainDirection ?? this.grainDirection,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'label': label,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
        'grain': grainDirection.name,
      };

  factory DimensionPreset.fromJson(Map<String, dynamic> j) => DimensionPreset(
        id: j['id'] as String,
        length: (j['length'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        label: (j['label'] as String?) ?? '',
        colorPresetId: j['colorPresetId'] as String?,
        grainDirection:
            GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      );

  @override
  bool operator ==(Object other) =>
      other is DimensionPreset &&
      other.id == id &&
      other.length == length &&
      other.width == width &&
      other.label == label &&
      other.colorPresetId == colorPresetId &&
      other.grainDirection == grainDirection;

  @override
  int get hashCode => Object.hash(
        id,
        length,
        width,
        label,
        colorPresetId,
        grainDirection,
      );
}
