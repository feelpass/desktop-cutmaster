import 'cut_part.dart';
import 'solver_mode.dart';
import 'stock_sheet.dart';

/// 한 번의 재단 작업 단위. 자재+부품+옵션+메타데이터 묶음.
class Project {
  final String id;
  final String name;
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf; // mm — 톱날 두께
  final bool grainLocked;
  final bool showPartLabels;
  final bool useSingleSheet;
  final SolverMode solverMode;
  final StripDirection stripDirection;
  final int maxStages;
  final bool preferSameWidth;
  final bool minimizeCuts;
  final bool minimizeWaste;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 주문 정보
  final String orderNumber;
  final DateTime? dueDate;
  final String memo;

  // 헤드컷 (자재 가장자리에서 잘라낼 mm)
  final double headcutTop;
  final double headcutBottom;
  final double headcutLeft;
  final double headcutRight;

  /// 자동 자재 도출 시 사용되는 표준 자재 크기.
  static const double standardStockLength = 2440;
  static const double standardStockWidth = 1220;

  const Project({
    required this.id,
    required this.name,
    this.stocks = const [],
    this.parts = const [],
    this.kerf = 3,
    this.grainLocked = false,
    this.showPartLabels = true,
    this.useSingleSheet = false,
    this.solverMode = SolverMode.ffd,
    this.stripDirection = StripDirection.auto,
    this.maxStages = 3,
    this.preferSameWidth = true,
    this.minimizeCuts = true,
    this.minimizeWaste = true,
    required this.createdAt,
    required this.updatedAt,
    this.orderNumber = '',
    this.dueDate,
    this.memo = '',
    this.headcutTop = 0,
    this.headcutBottom = 0,
    this.headcutLeft = 0,
    this.headcutRight = 0,
  });

  factory Project.create({required String id, required String name}) {
    final now = DateTime.now();
    return Project(id: id, name: name, createdAt: now, updatedAt: now);
  }

  Project copyWith({
    String? name,
    List<StockSheet>? stocks,
    List<CutPart>? parts,
    double? kerf,
    bool? grainLocked,
    bool? showPartLabels,
    bool? useSingleSheet,
    SolverMode? solverMode,
    StripDirection? stripDirection,
    int? maxStages,
    bool? preferSameWidth,
    bool? minimizeCuts,
    bool? minimizeWaste,
    String? orderNumber,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? memo,
    double? headcutTop,
    double? headcutBottom,
    double? headcutLeft,
    double? headcutRight,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        stocks: stocks ?? this.stocks,
        parts: parts ?? this.parts,
        kerf: kerf ?? this.kerf,
        grainLocked: grainLocked ?? this.grainLocked,
        showPartLabels: showPartLabels ?? this.showPartLabels,
        useSingleSheet: useSingleSheet ?? this.useSingleSheet,
        solverMode: solverMode ?? this.solverMode,
        stripDirection: stripDirection ?? this.stripDirection,
        maxStages: maxStages ?? this.maxStages,
        preferSameWidth: preferSameWidth ?? this.preferSameWidth,
        minimizeCuts: minimizeCuts ?? this.minimizeCuts,
        minimizeWaste: minimizeWaste ?? this.minimizeWaste,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        orderNumber: orderNumber ?? this.orderNumber,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        memo: memo ?? this.memo,
        headcutTop: headcutTop ?? this.headcutTop,
        headcutBottom: headcutBottom ?? this.headcutBottom,
        headcutLeft: headcutLeft ?? this.headcutLeft,
        headcutRight: headcutRight ?? this.headcutRight,
      );

  /// 부품의 (colorPresetId, thickness) 고유 조합으로 자재 시트 자동 도출.
  /// 모두 표준 크기(2440×1220) 무제한 수량(qty=999)으로 생성된다.
  /// [stocks] 필드에 사용자가 직접 입력한 시트가 있어도 무시하고 부품에서만 도출.
  List<StockSheet> derivedStocks() {
    final seen = <String, StockSheet>{};
    for (final p in parts) {
      final key = '${p.colorPresetId ?? ''}|${p.thickness}';
      if (seen.containsKey(key)) continue;
      seen[key] = StockSheet(
        id: 'auto_$key',
        length: standardStockLength,
        width: standardStockWidth,
        qty: 999,
        label: _materialLabel(p),
        grainDirection: GrainDirection.none,
        colorPresetId: p.colorPresetId,
      );
    }
    return seen.values.toList();
  }

  static String _materialLabel(CutPart p) {
    final t = p.thickness == p.thickness.toInt()
        ? p.thickness.toInt().toString()
        : p.thickness.toString();
    return '${t}T';
  }

  /// On-disk JSON 스키마 버전.
  /// v4: 주문 정보(orderNumber/dueDate/memo) + 헤드컷 4면 + 부품 thickness/priority 필드 추가.
  static const int schemaVersion = 4;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'kerf': kerf,
        'grainLocked': grainLocked,
        'showPartLabels': showPartLabels,
        'useSingleSheet': useSingleSheet,
        'stocks': stocks.map((s) => s.toJson()).toList(),
        'parts': parts.map((c) => c.toJson()).toList(),
        'solverMode': solverMode.name,
        'stripDirection': stripDirection.name,
        'maxStages': maxStages,
        'preferSameWidth': preferSameWidth,
        'minimizeCuts': minimizeCuts,
        'minimizeWaste': minimizeWaste,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'orderNumber': orderNumber,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        'memo': memo,
        'headcutTop': headcutTop,
        'headcutBottom': headcutBottom,
        'headcutLeft': headcutLeft,
        'headcutRight': headcutRight,
      };

  factory Project.fromJson(
    Map<String, dynamic> j, {
    String? Function(int argb)? colorMatcher,
  }) {
    final v = j['schemaVersion'] as int? ?? 1;
    if (v > schemaVersion) {
      throw FormatException('Unsupported schemaVersion: $v');
    }
    return Project(
      id: j['id'] as String,
      name: j['name'] as String,
      stocks: ((j['stocks'] as List?) ?? const [])
          .map((e) => StockSheet.fromJson(e as Map<String, dynamic>,
              colorMatcher: colorMatcher))
          .toList(),
      parts: ((j['parts'] as List?) ?? const [])
          .map((e) => CutPart.fromJson(e as Map<String, dynamic>,
              colorMatcher: colorMatcher))
          .toList(),
      kerf: ((j['kerf'] as num?) ?? 3).toDouble(),
      grainLocked: (j['grainLocked'] as bool?) ?? false,
      showPartLabels: (j['showPartLabels'] as bool?) ?? true,
      useSingleSheet: (j['useSingleSheet'] as bool?) ?? false,
      solverMode: SolverMode.fromName(j['solverMode'] as String? ?? 'ffd'),
      stripDirection:
          StripDirection.fromName(j['stripDirection'] as String? ?? 'auto'),
      maxStages: (j['maxStages'] as int?) ?? 3,
      preferSameWidth: (j['preferSameWidth'] as bool?) ?? true,
      minimizeCuts: (j['minimizeCuts'] as bool?) ?? true,
      minimizeWaste: (j['minimizeWaste'] as bool?) ?? true,
      createdAt: DateTime.parse(j['createdAt'] as String? ??
          DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(j['updatedAt'] as String? ??
          DateTime.now().toIso8601String()),
      orderNumber: (j['orderNumber'] as String?) ?? '',
      dueDate: j['dueDate'] is String
          ? DateTime.tryParse(j['dueDate'] as String)
          : null,
      memo: (j['memo'] as String?) ?? '',
      headcutTop: ((j['headcutTop'] as num?) ?? 0).toDouble(),
      headcutBottom: ((j['headcutBottom'] as num?) ?? 0).toDouble(),
      headcutLeft: ((j['headcutLeft'] as num?) ?? 0).toDouble(),
      headcutRight: ((j['headcutRight'] as num?) ?? 0).toDouble(),
    );
  }
}
