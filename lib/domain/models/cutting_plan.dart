import 'cut_part.dart';

/// 솔버 결과. 시트별 배치 + 미배치 부품 + 효율.
class CuttingPlan {
  final List<SheetLayout> sheets;
  final List<CutPart> unplaced;
  final double efficiencyPercent;

  const CuttingPlan({
    required this.sheets,
    required this.unplaced,
    required this.efficiencyPercent,
  });
}

class SheetLayout {
  final String stockSheetId;
  final List<PlacedPart> placed;
  final double sheetLength;
  final double sheetWidth;

  const SheetLayout({
    required this.stockSheetId,
    required this.placed,
    required this.sheetLength,
    required this.sheetWidth,
  });

  /// 이 시트에서 사용된 면적 비율 (0-100).
  double get usedPercent {
    if (sheetLength == 0 || sheetWidth == 0) return 0;
    final total = sheetLength * sheetWidth;
    final used =
        placed.fold<double>(0, (acc, p) => acc + p.part.length * p.part.width);
    return (used / total) * 100;
  }
}

class PlacedPart {
  final CutPart part;
  final double x;
  final double y;
  final bool rotated;

  const PlacedPart({
    required this.part,
    required this.x,
    required this.y,
    this.rotated = false,
  });

  /// 회전 시 시각화용 가로/세로.
  double get drawLength => rotated ? part.width : part.length;
  double get drawWidth => rotated ? part.length : part.width;
}
