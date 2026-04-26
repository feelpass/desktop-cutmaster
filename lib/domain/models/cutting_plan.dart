import 'cut_part.dart';
import 'solver_mode.dart';

/// 솔버 결과. 시트별 배치 + 미배치 부품 + 효율.
class CuttingPlan {
  final List<SheetLayout> sheets;
  final List<CutPart> unplaced;
  final double efficiencyPercent;

  /// Auto-recommend 결과일 때만 채워짐. FFD/strip-cut(non-auto)에서는 둘 다 null.
  /// UI(Task 20 chips)에서 winner와 runner-up 비교를 보여줄 때 사용.
  final CuttingPlan? runnerUp;
  final StripDirection? runnerUpDirection;

  const CuttingPlan({
    required this.sheets,
    required this.unplaced,
    required this.efficiencyPercent,
    this.runnerUp,
    this.runnerUpDirection,
  });
}

class SheetLayout {
  final String stockSheetId;
  final List<PlacedPart> placed;
  final double sheetLength;
  final double sheetWidth;
  final CutSequence? cutSequence;

  const SheetLayout({
    required this.stockSheetId,
    required this.placed,
    required this.sheetLength,
    required this.sheetWidth,
    this.cutSequence,
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
