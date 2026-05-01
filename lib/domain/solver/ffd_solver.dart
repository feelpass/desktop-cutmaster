import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/stock_sheet.dart';

/// 2D guillotine cut + First Fit Decreasing.
///
/// 알고리즘 (개선 버전):
/// 1. 부품 정렬은 4가지 전략(area-desc, max-side-desc, min-side-desc, length-desc)을 병렬 시도.
/// 2. 위치 점수는 BSSF(Best Short Side Fit)와 BAF(Best Area Fit) 둘 다 시도.
/// 3. 모든 열린 시트를 동시 유지 — 부품마다 모든 시트의 free rect 중 best fit 선택.
/// 4. Split은 잔여가 큰 단일 rect를 보존하는 방향(horizontal vs vertical) 자동 선택.
/// 5. 8개 변형 중 (미배치 적음 → 효율 높음 → 시트 적음) 우선순위로 best 선택.
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
    final stockQueue = <StockSheet>[];
    for (final s in stocks) {
      for (int i = 0; i < s.qty; i++) {
        stockQueue.add(s);
      }
    }

    final expandedParts = <CutPart>[];
    for (final p in parts) {
      for (int i = 0; i < p.qty; i++) {
        expandedParts.add(p);
      }
    }

    if (stockQueue.isEmpty) {
      return CuttingPlan(
        sheets: const [],
        unplaced: List.of(expandedParts),
        efficiencyPercent: 0,
      );
    }

    const sortStrategies = <_Sort>[
      _Sort.areaDesc,
      _Sort.maxSideDesc,
      _Sort.minSideDesc,
      _Sort.lengthDesc,
    ];
    const scoreStrategies = <_Score>[_Score.bssf, _Score.baf];

    CuttingPlan? best;
    for (final sort in sortStrategies) {
      final sorted = List<CutPart>.of(expandedParts);
      _applySort(sorted, sort);
      for (final score in scoreStrategies) {
        final plan = _solveOne(
          sortedParts: sorted,
          stockQueue: stockQueue,
          kerf: kerf,
          grainLocked: grainLocked,
          score: score,
        );
        if (best == null || _isBetter(plan, best)) {
          best = plan;
        }
      }
    }
    return best!;
  }

  /// 두 결과 비교 우선순위:
  ///   1) 미배치 적은 쪽
  ///   2) 효율 높은 쪽
  ///   3) **가장 큰 단일 자투리 면적이 큰 쪽** — 사용자가 자투리를 재활용하려면
  ///      쪼개진 작은 자투리 여러 개보다 큰 자투리 하나가 가치가 높음.
  ///   4) 시트 적은 쪽
  bool _isBetter(CuttingPlan a, CuttingPlan b) {
    if (a.unplaced.length != b.unplaced.length) {
      return a.unplaced.length < b.unplaced.length;
    }
    if ((a.efficiencyPercent - b.efficiencyPercent).abs() > 0.001) {
      return a.efficiencyPercent > b.efficiencyPercent;
    }
    final aLeftover = a.largestLeftoverArea;
    final bLeftover = b.largestLeftoverArea;
    if ((aLeftover - bLeftover).abs() > 1.0) {
      return aLeftover > bLeftover;
    }
    return a.sheets.length < b.sheets.length;
  }

  void _applySort(List<CutPart> parts, _Sort sort) {
    switch (sort) {
      case _Sort.areaDesc:
        parts.sort((a, b) =>
            (b.length * b.width).compareTo(a.length * a.width));
      case _Sort.maxSideDesc:
        double maxSide(CutPart p) =>
            p.length > p.width ? p.length : p.width;
        parts.sort((a, b) => maxSide(b).compareTo(maxSide(a)));
      case _Sort.minSideDesc:
        double minSide(CutPart p) =>
            p.length < p.width ? p.length : p.width;
        parts.sort((a, b) => minSide(b).compareTo(minSide(a)));
      case _Sort.lengthDesc:
        parts.sort((a, b) => b.length.compareTo(a.length));
    }
  }

  CuttingPlan _solveOne({
    required List<CutPart> sortedParts,
    required List<StockSheet> stockQueue,
    required double kerf,
    required bool grainLocked,
    required _Score score,
  }) {
    final openSheets = <_OpenSheet>[];
    int nextStockIdx = 0;
    final unplaced = <CutPart>[];

    for (final part in sortedParts) {
      _Placement? best;
      _OpenSheet? bestSheet;
      for (final sheet in openSheets) {
        final p = _findBestFit(sheet.freeRects, part, grainLocked, score);
        if (p == null) continue;
        if (best == null || p.score < best.score) {
          best = p;
          bestSheet = sheet;
        }
      }

      if (best == null) {
        if (nextStockIdx >= stockQueue.length) {
          unplaced.add(part);
          continue;
        }
        final candidateStock = stockQueue[nextStockIdx];
        final candidateRects = [
          _Rect(0, 0, candidateStock.length, candidateStock.width),
        ];
        final p =
            _findBestFit(candidateRects, part, grainLocked, score);
        if (p == null) {
          unplaced.add(part);
          continue;
        }
        final newSheet = _OpenSheet(
          stock: candidateStock,
          freeRects: candidateRects,
          placed: [],
        );
        nextStockIdx++;
        openSheets.add(newSheet);
        best = p;
        bestSheet = newSheet;
      }

      bestSheet!.placed.add(PlacedPart(
        part: part,
        x: best.x,
        y: best.y,
        rotated: best.rotated,
      ));
      bestSheet.freeRects = _splitRects(
        bestSheet.freeRects,
        best.rect!,
        part,
        best.rotated,
        kerf,
      );
    }

    final sheets = <SheetLayout>[];
    var totalArea = 0.0;
    var usedArea = 0.0;
    for (final s in openSheets) {
      if (s.placed.isEmpty) continue;
      sheets.add(SheetLayout(
        stockSheetId: s.stock.id,
        placed: s.placed,
        sheetLength: s.stock.length,
        sheetWidth: s.stock.width,
        leftovers: s.freeRects
            .map((r) => LeftoverRect(x: r.x, y: r.y, width: r.w, height: r.h))
            .toList(),
      ));
      totalArea += s.stock.length * s.stock.width;
      for (final p in s.placed) {
        usedArea += p.part.length * p.part.width;
      }
    }
    final efficiency =
        totalArea == 0 ? 0.0 : (usedArea / totalArea) * 100;
    return CuttingPlan(
      sheets: sheets,
      unplaced: unplaced,
      efficiencyPercent: efficiency,
    );
  }

  /// 위치 점수.
  /// - BSSF: min(rect.w - placed.w, rect.h - placed.h) — 짧은 변 잔여 최소.
  /// - BAF : (rect.w * rect.h) - (placed.w * placed.h) — 면적 차이 최소.
  _Placement? _findBestFit(
      List<_Rect> rects, CutPart part, bool grainLocked, _Score score) {
    _Placement? best;
    for (final r in rects) {
      // 정방향
      if (part.length <= r.w && part.width <= r.h) {
        final s = score == _Score.bssf
            ? _bssfScore(r, part.length, part.width)
            : _bafScore(r, part.length, part.width);
        if (best == null || s < best.score) {
          best = _Placement(
            x: r.x,
            y: r.y,
            rotated: false,
            score: s,
            rect: r,
          );
        }
      }
      // 회전
      if (!grainLocked && part.width <= r.w && part.length <= r.h) {
        final s = score == _Score.bssf
            ? _bssfScore(r, part.width, part.length)
            : _bafScore(r, part.width, part.length);
        if (best == null || s < best.score) {
          best = _Placement(
            x: r.x,
            y: r.y,
            rotated: true,
            score: s,
            rect: r,
          );
        }
      }
    }
    return best;
  }

  double _bssfScore(_Rect r, double pl, double pw) {
    final dw = r.w - pl;
    final dh = r.h - pw;
    return dw < dh ? dw : dh;
  }

  double _bafScore(_Rect r, double pl, double pw) {
    return r.w * r.h - pl * pw;
  }

  /// 부품 배치 후 free rectangles를 guillotine 방식으로 split.
  /// 잔여가 큰 단일 residual rect를 보존하는 방향(horizontal vs vertical) 자동 선택.
  List<_Rect> _splitRects(
    List<_Rect> rects,
    _Rect usedRect,
    CutPart part,
    bool rotated,
    double kerf,
  ) {
    final pl = rotated ? part.width : part.length;
    final pw = rotated ? part.length : part.width;
    final result = <_Rect>[];

    for (final r in rects) {
      if (r.x == usedRect.x &&
          r.y == usedRect.y &&
          r.w == usedRect.w &&
          r.h == usedRect.h) {
        final leftoverW = r.w - pl - kerf;
        final leftoverH = r.h - pw - kerf;

        if (leftoverW <= 0 && leftoverH <= 0) continue;

        if (leftoverW <= 0) {
          if (leftoverH > 0) {
            result.add(_Rect(r.x, r.y + pw + kerf, r.w, leftoverH));
          }
          continue;
        }
        if (leftoverH <= 0) {
          if (leftoverW > 0) {
            result.add(_Rect(r.x + pl + kerf, r.y, leftoverW, r.h));
          }
          continue;
        }

        final hBottom = r.w * leftoverH;
        final hRight = leftoverW * pw;
        final vBottom = pl * leftoverH;
        final vRight = leftoverW * r.h;
        final hMax = hBottom > hRight ? hBottom : hRight;
        final vMax = vBottom > vRight ? vBottom : vRight;

        if (hMax >= vMax) {
          result.add(_Rect(r.x, r.y + pw + kerf, r.w, leftoverH));
          result.add(_Rect(r.x + pl + kerf, r.y, leftoverW, pw));
        } else {
          result.add(_Rect(r.x, r.y + pw + kerf, pl, leftoverH));
          result.add(_Rect(r.x + pl + kerf, r.y, leftoverW, r.h));
        }
      } else {
        result.add(r);
      }
    }
    return result;
  }
}

enum _Sort { areaDesc, maxSideDesc, minSideDesc, lengthDesc }

enum _Score { bssf, baf }

class _Rect {
  final double x;
  final double y;
  final double w;
  final double h;
  const _Rect(this.x, this.y, this.w, this.h);
}

class _Placement {
  final double x;
  final double y;
  final bool rotated;
  final double score;
  final _Rect? rect;

  const _Placement({
    required this.x,
    required this.y,
    required this.rotated,
    required this.score,
    this.rect,
  });
}

class _OpenSheet {
  final StockSheet stock;
  List<_Rect> freeRects;
  final List<PlacedPart> placed;

  _OpenSheet({
    required this.stock,
    required this.freeRects,
    required this.placed,
  });
}
