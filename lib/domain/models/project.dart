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
}
