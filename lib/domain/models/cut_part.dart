import 'stock_sheet.dart' show GrainDirection;

class CutPart {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final GrainDirection grainDirection;
  final String? colorPresetId;
  final double thickness;
  final int priority;

  /// CSV의 EDGE1~4 (4면 엣지 자재). 빈 문자열은 "엣지 없음".
  /// 길이는 항상 4 — 엣지 없으면 ''로 채워둔다. (관행적 매핑: 0=상, 1=하, 2=좌, 3=우)
  final List<String> edges;

  /// CSV의 FILE — 도면 파일명/식별자.
  final String fileName;

  /// CSV의 GROOVE — 홈 가공 메타. 보통 빈 문자열.
  final String groove;

  /// 사용자 메모. CSV에는 없고 UI에서 직접 입력.
  final String memo;

  const CutPart({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
    this.colorPresetId,
    this.thickness = 18,
    this.priority = 1,
    this.edges = const ['', '', '', ''],
    this.fileName = '',
    this.groove = '',
    this.memo = '',
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
    double? thickness,
    int? priority,
    List<String>? edges,
    String? fileName,
    String? groove,
    String? memo,
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
        thickness: thickness ?? this.thickness,
        priority: priority ?? this.priority,
        edges: edges ?? this.edges,
        fileName: fileName ?? this.fileName,
        groove: groove ?? this.groove,
        memo: memo ?? this.memo,
      );

  /// 4면 중 하나라도 엣지가 있으면 true.
  bool get hasAnyEdge => edges.any((e) => e.isNotEmpty);

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'qty': qty,
        'label': label,
        'grain': grainDirection.name,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
        'thickness': thickness,
        'priority': priority,
        if (hasAnyEdge) 'edges': edges,
        if (fileName.isNotEmpty) 'fileName': fileName,
        if (groove.isNotEmpty) 'groove': groove,
        if (memo.isNotEmpty) 'memo': memo,
      };

  factory CutPart.fromJson(
    Map<String, dynamic> j, {
    String? Function(int argb)? colorMatcher,
  }) {
    String? cpid = j['colorPresetId'] as String?;
    if (cpid == null && j['color'] is int && colorMatcher != null) {
      cpid = colorMatcher(j['color'] as int);
    }
    final edgesJson = j['edges'];
    final edges = edgesJson is List
        ? List<String>.generate(
            4,
            (i) => i < edgesJson.length ? (edgesJson[i] as String? ?? '') : '',
          )
        : const ['', '', '', ''];
    return CutPart(
      id: j['id'] as String,
      length: (j['length'] as num).toDouble(),
      width: (j['width'] as num).toDouble(),
      qty: j['qty'] as int,
      label: (j['label'] as String?) ?? '',
      grainDirection:
          GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      colorPresetId: cpid,
      thickness: ((j['thickness'] as num?) ?? 18).toDouble(),
      priority: (j['priority'] as int?) ?? 1,
      edges: edges,
      fileName: (j['fileName'] as String?) ?? '',
      groove: (j['groove'] as String?) ?? '',
      memo: (j['memo'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! CutPart) return false;
    if (other.edges.length != edges.length) return false;
    for (var i = 0; i < edges.length; i++) {
      if (other.edges[i] != edges[i]) return false;
    }
    return other.id == id &&
        other.length == length &&
        other.width == width &&
        other.qty == qty &&
        other.label == label &&
        other.grainDirection == grainDirection &&
        other.colorPresetId == colorPresetId &&
        other.thickness == thickness &&
        other.priority == priority &&
        other.fileName == fileName &&
        other.groove == groove &&
        other.memo == memo;
  }

  @override
  int get hashCode => Object.hash(
        id,
        length,
        width,
        qty,
        label,
        grainDirection,
        colorPresetId,
        thickness,
        priority,
        Object.hashAll(edges),
        fileName,
        groove,
        memo,
      );
}
