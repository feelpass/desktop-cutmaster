/// 결방향 — 합판은 결이 있어서 회전 가능 여부가 달라짐.
enum GrainDirection { none, lengthwise, widthwise }

/// 보유 자재 (재료 시트). 가구공장 친구의 합판 재고에 해당.
/// colorPresetId가 null이면 자재 ID 해시 기반으로 자동 색상 할당 (목재 톤 팔레트).
/// 아니면 ColorPreset.id 참조 — 실제 ARGB는 PresetsNotifier.colorById에서 lookup.
class StockSheet {
  final String id;
  final double length; // mm
  final double width; // mm
  final int qty;
  final String label;
  final GrainDirection grainDirection;
  final String? colorPresetId;

  const StockSheet({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
    this.colorPresetId,
  });

  StockSheet copyWith({
    String? id,
    double? length,
    double? width,
    int? qty,
    String? label,
    GrainDirection? grainDirection,
    String? colorPresetId,
    bool clearColor = false,
  }) =>
      StockSheet(
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
  factory StockSheet.fromJson(
    Map<String, dynamic> j, {
    String? Function(int argb)? colorMatcher,
  }) {
    String? cpid = j['colorPresetId'] as String?;
    if (cpid == null && j['color'] is int && colorMatcher != null) {
      cpid = colorMatcher(j['color'] as int);
    }
    return StockSheet(
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
      other is StockSheet &&
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
