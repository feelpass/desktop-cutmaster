import 'stock_sheet.dart' show GrainDirection;

/// 재단할 부품. 가구 도면의 한 조각에 해당.
class CutPart {
  final String id;
  final double length; // mm
  final double width; // mm
  final int qty;
  final String label;
  final GrainDirection grainDirection;

  const CutPart({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
  });

  CutPart copyWith({
    String? id,
    double? length,
    double? width,
    int? qty,
    String? label,
    GrainDirection? grainDirection,
  }) =>
      CutPart(
        id: id ?? this.id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        grainDirection: grainDirection ?? this.grainDirection,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'qty': qty,
        'label': label,
        'grain': grainDirection.name,
      };

  factory CutPart.fromJson(Map<String, dynamic> j) => CutPart(
        id: j['id'] as String,
        length: (j['length'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        qty: j['qty'] as int,
        label: (j['label'] as String?) ?? '',
        grainDirection:
            GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      );

  @override
  bool operator ==(Object other) =>
      other is CutPart &&
      other.id == id &&
      other.length == length &&
      other.width == width &&
      other.qty == qty &&
      other.label == label &&
      other.grainDirection == grainDirection;

  @override
  int get hashCode =>
      Object.hash(id, length, width, qty, label, grainDirection);
}
