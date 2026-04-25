/// 결방향 — 합판은 결이 있어서 회전 가능 여부가 달라짐.
enum GrainDirection { none, lengthwise, widthwise }

/// 보유 자재 (재료 시트). 가구공장 친구의 합판 재고에 해당.
class StockSheet {
  final String id;
  final double length; // mm
  final double width; // mm
  final int qty;
  final String label;
  final GrainDirection grainDirection;

  const StockSheet({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
  });

  StockSheet copyWith({
    String? id,
    double? length,
    double? width,
    int? qty,
    String? label,
    GrainDirection? grainDirection,
  }) =>
      StockSheet(
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

  factory StockSheet.fromJson(Map<String, dynamic> j) => StockSheet(
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
      other is StockSheet &&
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
