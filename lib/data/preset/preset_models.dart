import '../../domain/models/stock_sheet.dart' show GrainDirection;

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

class DimensionPreset {
  final String id;
  final double length;
  final double width;
  final String label;
  final String? colorPresetId;
  final GrainDirection grain;

  const DimensionPreset({
    required this.id,
    required this.length,
    required this.width,
    required this.label,
    required this.colorPresetId,
    required this.grain,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'label': label,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
        'grain': grain.name,
      };

  factory DimensionPreset.fromJson(Map<String, dynamic> j) => DimensionPreset(
        id: j['id'] as String,
        length: (j['length'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        label: (j['label'] as String?) ?? '',
        colorPresetId: j['colorPresetId'] as String?,
        grain: GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      );

  @override
  bool operator ==(Object other) =>
      other is DimensionPreset &&
      other.id == id &&
      other.length == length &&
      other.width == width &&
      other.label == label &&
      other.colorPresetId == colorPresetId &&
      other.grain == grain;

  @override
  int get hashCode =>
      Object.hash(id, length, width, label, colorPresetId, grain);
}
