import 'cut_part.dart';
import 'stock_sheet.dart';

/// 한 번의 재단 작업 단위. 자재+부품+옵션+메타데이터 묶음.
/// 자재 라이브러리에서 가져온 자재의 스냅샷을 보유 (라이브러리 수정이 기존 프로젝트에 영향 안 줌).
class Project {
  final String id;
  final String name;
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf; // mm — 톱날 두께
  final bool grainLocked;
  final bool showPartLabels;
  final bool useSingleSheet;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.name,
    this.stocks = const [],
    this.parts = const [],
    this.kerf = 3,
    this.grainLocked = false,
    this.showPartLabels = true,
    this.useSingleSheet = false,
    required this.createdAt,
    required this.updatedAt,
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
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// On-disk JSON 스키마 버전.
  /// v1: `CutPart`/`StockSheet`이 `color: int` (ARGB) 필드를 가졌음.
  /// v2: 색상이 글로벌 `ColorPreset` 라이브러리로 이동 — `colorPresetId: String?`로 참조.
  /// v1 파일은 `colorMatcher`를 통해 ARGB → preset id 마이그레이션을 거쳐 로드된다.
  static const int schemaVersion = 2;

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
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// JSON에서 Project 복원.
  ///
  /// [colorMatcher]는 v1 → v2 마이그레이션용. v1 파일에는 `CutPart`/`StockSheet`에
  /// `color: int` (ARGB)가 있었고, v2에서는 `colorPresetId: String?`만 가진다.
  /// 호출자가 ColorPreset 라이브러리를 들여다보며 ARGB → preset id 매칭을
  /// 책임진다 — 매칭 안 되면 `null`을 돌려주면 색상이 사라진 채로 로드된다.
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
      createdAt: DateTime.parse(j['createdAt'] as String? ??
          DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(j['updatedAt'] as String? ??
          DateTime.now().toIso8601String()),
    );
  }
}
