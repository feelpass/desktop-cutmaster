import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/stock_sheet.dart';

/// 2D guillotine cut + First Fit Decreasing 정렬.
///
/// 알고리즘:
/// 1. 부품을 면적 큰 순서로 정렬 (qty 만큼 펼침).
/// 2. 각 부품을 현재 시트의 free rectangle list에서 first-fit으로 배치.
/// 3. 배치 후 남은 공간을 guillotine 방식으로 split (right + bottom).
/// 4. 현재 시트에 안 들어가면 다음 시트로. 시트 다 떨어지면 unplaced로.
///
/// 결방향(grainDirection):
/// - grainLocked=true: 부품 회전 금지.
/// - grainLocked=false: 정방향 안 들어가면 회전 시도.
class FFDSolver {
  CuttingPlan solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
  }) {
    // 1. 부품을 qty만큼 펼치고 면적 큰 순서로 정렬
    final expandedParts = <CutPart>[];
    for (final p in parts) {
      for (int i = 0; i < p.qty; i++) {
        expandedParts.add(p);
      }
    }
    expandedParts.sort(
      (a, b) => (b.length * b.width).compareTo(a.length * a.width),
    );

    // 2. 자재를 qty만큼 펼친 큐
    final stockQueue = <StockSheet>[];
    for (final s in stocks) {
      for (int i = 0; i < s.qty; i++) {
        stockQueue.add(s);
      }
    }

    final sheets = <SheetLayout>[];
    final unplaced = <CutPart>[];
    double usedArea = 0;
    double totalSheetArea = 0;

    if (stockQueue.isEmpty) {
      // 자재가 없으면 모든 부품 unplaced
      unplaced.addAll(expandedParts);
      return CuttingPlan(
        sheets: const [],
        unplaced: unplaced,
        efficiencyPercent: 0,
      );
    }

    int stockIdx = 0;
    StockSheet currentSheet = stockQueue[stockIdx];
    var freeRects = <_Rect>[
      _Rect(0, 0, currentSheet.length, currentSheet.width),
    ];
    var placed = <PlacedPart>[];

    void commitCurrentSheet() {
      if (placed.isNotEmpty) {
        sheets.add(SheetLayout(
          stockSheetId: currentSheet.id,
          placed: List.of(placed),
          sheetLength: currentSheet.length,
          sheetWidth: currentSheet.width,
        ));
        totalSheetArea += currentSheet.length * currentSheet.width;
      }
    }

    for (final part in expandedParts) {
      bool placedThisPart = false;
      while (!placedThisPart) {
        final fit = _findFit(freeRects, part, grainLocked);
        if (fit != null) {
          placed.add(PlacedPart(
            part: part,
            x: fit.x,
            y: fit.y,
            rotated: fit.rotated,
          ));
          usedArea += part.length * part.width;
          freeRects = _splitRects(freeRects, fit, part, kerf);
          placedThisPart = true;
        } else {
          // 현재 시트에 안 들어감
          if (placed.isEmpty) {
            // 빈 시트에도 안 들어가면 부품이 시트보다 큼 → unplaced
            unplaced.add(part);
            placedThisPart = true; // exit while loop
          } else {
            // 현재 시트는 가득 → 다음 시트
            commitCurrentSheet();
            stockIdx++;
            if (stockIdx >= stockQueue.length) {
              // 시트 더 없음 → unplaced
              unplaced.add(part);
              placedThisPart = true;
              placed = [];
              freeRects = [];
            } else {
              currentSheet = stockQueue[stockIdx];
              freeRects = [
                _Rect(0, 0, currentSheet.length, currentSheet.width),
              ];
              placed = [];
              // loop back to retry on new sheet
            }
          }
        }
      }
    }

    // 마지막 시트 commit
    commitCurrentSheet();

    final efficiency = totalSheetArea == 0 ? 0.0 : (usedArea / totalSheetArea) * 100;
    return CuttingPlan(
      sheets: sheets,
      unplaced: unplaced,
      efficiencyPercent: efficiency,
    );
  }

  /// 부품을 free rectangles 중 first-fit으로 배치할 위치 찾기.
  /// 정방향 우선, grainLocked=false이면 회전도 시도.
  _Fit? _findFit(List<_Rect> rects, CutPart part, bool grainLocked) {
    for (final r in rects) {
      // 정방향
      if (part.length <= r.w && part.width <= r.h) {
        return _Fit(x: r.x, y: r.y, rotated: false);
      }
      // 회전 (grainLocked=true이면 회전 금지)
      if (!grainLocked && part.width <= r.w && part.length <= r.h) {
        return _Fit(x: r.x, y: r.y, rotated: true);
      }
    }
    return null;
  }

  /// 부품 배치 후 free rectangles를 guillotine 방식으로 split.
  /// 사용한 rect를 right+bottom 두 새 rect로 분리, 다른 rect는 그대로 유지.
  List<_Rect> _splitRects(
    List<_Rect> rects,
    _Fit fit,
    CutPart part,
    double kerf,
  ) {
    final pl = fit.rotated ? part.width : part.length;
    final pw = fit.rotated ? part.length : part.width;
    final result = <_Rect>[];
    bool consumed = false;
    for (final r in rects) {
      if (!consumed && r.x == fit.x && r.y == fit.y) {
        consumed = true;
        // right rect
        final rightW = r.w - pl - kerf;
        if (rightW > 0) {
          result.add(_Rect(r.x + pl + kerf, r.y, rightW, pw));
        }
        // bottom rect
        final bottomH = r.h - pw - kerf;
        if (bottomH > 0) {
          result.add(_Rect(r.x, r.y + pw + kerf, r.w, bottomH));
        }
      } else {
        result.add(r);
      }
    }
    return result;
  }
}

/// 내부 사각형 표현 (x, y, width, height).
class _Rect {
  final double x;
  final double y;
  final double w;
  final double h;
  const _Rect(this.x, this.y, this.w, this.h);
}

class _Fit {
  final double x;
  final double y;
  final bool rotated;
  const _Fit({required this.x, required this.y, required this.rotated});
}
