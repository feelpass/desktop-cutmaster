import 'cut_part.dart';
import 'solver_mode.dart';

/// 솔버 결과. 시트별 배치 + 미배치 부품 + 효율.
class CuttingPlan {
  final List<SheetLayout> sheets;
  final List<CutPart> unplaced;
  final double efficiencyPercent;

  /// Auto-recommend 결과일 때만 채워짐. FFD/strip-cut(non-auto)에서는 둘 다 null.
  final CuttingPlan? runnerUp;
  final StripDirection? runnerUpDirection;

  const CuttingPlan({
    required this.sheets,
    required this.unplaced,
    required this.efficiencyPercent,
    this.runnerUp,
    this.runnerUpDirection,
  });

  /// 모든 시트 자투리 중 가장 큰 단일 사각형 면적.
  /// "큰 자투리 1개"가 의미 있는 재활용 자산이라는 사용자 멘탈모델 반영.
  double get largestLeftoverArea {
    var max = 0.0;
    for (final s in sheets) {
      for (final r in s.leftovers) {
        final a = r.width * r.height;
        if (a > max) max = a;
      }
    }
    return max;
  }
}

class SheetLayout {
  final String stockSheetId;
  final List<PlacedPart> placed;
  final double sheetLength;
  final double sheetWidth;
  final CutSequence? cutSequence;

  /// 솔버가 부품 배치 후 남긴 자유 사각형들 (재활용 가능 자투리).
  /// 빈 리스트면 자투리 정보 미제공 (legacy/strip-cut 등).
  final List<LeftoverRect> leftovers;

  const SheetLayout({
    required this.stockSheetId,
    required this.placed,
    required this.sheetLength,
    required this.sheetWidth,
    this.cutSequence,
    this.leftovers = const [],
  });

  /// 이 시트에서 사용된 면적 비율 (0-100).
  double get usedPercent {
    if (sheetLength == 0 || sheetWidth == 0) return 0;
    final total = sheetLength * sheetWidth;
    final used =
        placed.fold<double>(0, (acc, p) => acc + p.part.length * p.part.width);
    return (used / total) * 100;
  }

  /// 이 시트에서 가장 큰 단일 자투리 사각형. 없으면 null.
  LeftoverRect? get largestLeftover {
    LeftoverRect? best;
    for (final r in leftovers) {
      if (best == null || r.width * r.height > best.width * best.height) {
        best = r;
      }
    }
    return best;
  }
}

/// 시트 위 자유(재활용 가능) 사각형. 솔버가 부품 배치 후 남은 영역.
class LeftoverRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const LeftoverRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double get area => width * height;
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

/// strip-cut 모드 결과의 절단 순서 / 구조 정보.
/// FFD 모드에서는 SheetLayout.cutSequence = null.
class CutSequence {
  /// 풀컷 방향. true = 세로 풀컷이 stage 1.
  final bool verticalFirst;
  final List<Strip> strips;
  const CutSequence({required this.verticalFirst, required this.strips});
}

/// stage 1 풀컷으로 만들어진 시트 위의 한 strip(기둥/띠).
class Strip {
  /// strip의 시작 좌표 (verticalFirst=true이면 x, false면 y).
  final double offset;

  /// strip의 폭 (절단 방향에 수직).
  final double width;

  /// strip의 길이 (시트 전체).
  final double length;

  final List<Segment> segments;

  const Strip({
    required this.offset,
    required this.width,
    required this.length,
    required this.segments,
  });
}

/// 시트의 절단 횟수 — strip-cut은 정확값(strip 수 + segment 수), FFD는
/// 부품 경계에서 unique한 수직/수평 라인을 추정값으로 카운트.
/// 후자는 휴리스틱이므로 UI에서 "≈" 마커와 함께 표시할 것.
int estimateGuillotineCuts(SheetLayout s) {
  final seq = s.cutSequence;
  if (seq != null) {
    var n = seq.strips.length;
    for (final strip in seq.strips) {
      n += strip.segments.length;
    }
    return n;
  }
  if (s.placed.isEmpty) return 0;
  final xs = <int>{};
  final ys = <int>{};
  final l = s.sheetLength.round();
  final w = s.sheetWidth.round();
  for (final p in s.placed) {
    final x1 = p.x.round();
    final y1 = p.y.round();
    final x2 = (p.x + p.drawLength).round();
    final y2 = (p.y + p.drawWidth).round();
    if (x1 > 0 && x1 < l) xs.add(x1);
    if (x2 > 0 && x2 < l) xs.add(x2);
    if (y1 > 0 && y1 < w) ys.add(y1);
    if (y2 > 0 && y2 < w) ys.add(y2);
  }
  return xs.length + ys.length;
}

/// strip 내부에서 stage 2 절단으로 만들어진 segment.
/// width는 별도 필드 없음 — 항상 enclosing Strip.width와 같다.
class Segment {
  /// strip 내부에서의 시작 좌표 (verticalFirst=true이면 y, false면 x).
  final double offset;

  /// segment 길이 (절단 방향과 평행).
  final double length;

  /// 이 segment에 들어간 부품(들). 보통 1개, 4-stage이면 여러 개 가능.
  /// invariant: 동일 PlacedPart 인스턴스가 SheetLayout.placed에도 존재한다.
  /// 솔버가 둘을 함께 채우며, 외부에서는 어느 쪽으로 읽어도 동일.
  final List<PlacedPart> parts;

  /// segment 끝의 trim 자투리 길이 (3-stage 이상일 때만 > 0 가능).
  final double trim;

  const Segment({
    required this.offset,
    required this.length,
    required this.parts,
    required this.trim,
  });
}
