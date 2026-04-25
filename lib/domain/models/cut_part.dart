import 'stock_sheet.dart' show GrainDirection;

class CutPart {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final GrainDirection grainDirection;
  final String? colorPresetId;

  const CutPart({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
    this.colorPresetId,
  });

  CutPart copyWith({
    String? id,
    double? length,
    double? width,
    int? qty,
    String? label,
    GrainDirection? grainDirection,
    String? colorPresetId,
    bool clearColor = false,
  }) =>
      CutPart(
        id: id ?? this.id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        grainDirection: grainDirection ?? this.grainDirection,
        colorPresetId:
            clearColor ? null : (colorPresetId ?? this.colorPresetId),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'qty': qty,
        'label': label,
        'grain': grainDirection.name,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
      };

  /// fromJson는 마이그레이션을 위해 [colorMatcher]를 받는다 — 옛 `color: int`
  /// 필드가 보이면 매칭되는 ColorPreset.id를 반환할 책임이 호출자에게 있다.
  factory CutPart.fromJson(
    Map<String, dynamic> j, {
    String? Function(int argb)? colorMatcher,
  }) {
    String? cpid = j['colorPresetId'] as String?;
    if (cpid == null && j['color'] is int && colorMatcher != null) {
      cpid = colorMatcher(j['color'] as int);
    }
    return CutPart(
      id: j['id'] as String,
      length: (j['length'] as num).toDouble(),
      width: (j['width'] as num).toDouble(),
      qty: j['qty'] as int,
      label: (j['label'] as String?) ?? '',
      grainDirection:
          GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      colorPresetId: cpid,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CutPart &&
      other.id == id &&
      other.length == length &&
      other.width == width &&
      other.qty == qty &&
      other.label == label &&
      other.grainDirection == grainDirection &&
      other.colorPresetId == colorPresetId;

  @override
  int get hashCode =>
      Object.hash(id, length, width, qty, label, grainDirection, colorPresetId);
}
