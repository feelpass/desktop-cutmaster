import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/stock_sheet.dart';

/// 부품 단위 배치 허용 방향.
/// - [allowOriginal]: 회전 없이(part.length가 stock.length 축에) 배치 가능.
/// - [allowRotated]: 회전(part.width가 stock.length 축에) 배치 가능.
({bool allowOriginal, bool allowRotated}) _allowedOrientations(
  CutPart part,
  bool projectGrainLocked,
) {
  switch (part.grainDirection) {
    case GrainDirection.lengthwise:
      // 결이 part.length 축 — 시트 결(lengthwise)에 맞추려면 회전 금지.
      return (allowOriginal: true, allowRotated: false);
    case GrainDirection.widthwise:
      // 결이 part.width 축 — 시트 결에 맞추려면 강제 회전.
      return (allowOriginal: false, allowRotated: true);
    case GrainDirection.none:
      // 결방향 무관. 프로젝트 grainLocked가 켜져 있으면 회전 금지(기존 동작).
      return (
        allowOriginal: true,
        allowRotated: !projectGrainLocked,
      );
  }
}

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
      _Sort.lengthWidthDesc,
      _Sort.widthLengthDesc,
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
    // 동일 전체 효율일 때 — 가장 안 채워진 시트가 더 채워진 쪽 우선 (균등 분산).
    // 사용자가 마지막 시트가 거의 비는 것을 시각적으로 부정적으로 받아들임 →
    // 79%+71% 같은 균등이 94%+57% 같은 집중보다 우선.
    final aMinFill = _minSheetFill(a);
    final bMinFill = _minSheetFill(b);
    if ((aMinFill - bMinFill).abs() > 0.001) {
      return aMinFill > bMinFill;
    }
    final aLeftover = a.largestLeftoverArea;
    final bLeftover = b.largestLeftoverArea;
    if ((aLeftover - bLeftover).abs() > 1.0) {
      return aLeftover > bLeftover;
    }
    return a.sheets.length < b.sheets.length;
  }

  /// plan에서 가장 적게 채워진 시트의 efficiency (placed_area / sheet_area).
  /// 균등 분산 우선 — 마지막 시트가 너무 비지 않게 하기 위한 tiebreaker.
  double _minSheetFill(CuttingPlan plan) {
    if (plan.sheets.isEmpty) return 0;
    double minFill = double.infinity;
    for (final s in plan.sheets) {
      final sheetArea = s.sheetLength * s.sheetWidth;
      if (sheetArea <= 0) continue;
      double placedArea = 0;
      for (final p in s.placed) {
        placedArea += p.part.length * p.part.width;
      }
      final fill = placedArea / sheetArea;
      if (fill < minFill) minFill = fill;
    }
    return minFill == double.infinity ? 0 : minFill;
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
      case _Sort.lengthWidthDesc:
        // length 같으면 width 큰 쪽 우선 — 같은 length 다른 width 부품을
        // 한 row에 모아 분절 방지 (예: 800×380 3개 → 800×361 3개).
        parts.sort((a, b) {
          final cl = b.length.compareTo(a.length);
          if (cl != 0) return cl;
          return b.width.compareTo(a.width);
        });
      case _Sort.widthLengthDesc:
        parts.sort((a, b) {
          final cw = b.width.compareTo(a.width);
          if (cw != 0) return cw;
          return b.length.compareTo(a.length);
        });
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

    // Post-processing: 시트마다 부품을 좌측+상단으로 슬라이드.
    // L→U→L 사이클을 안정 상태(변화 없음)까지 반복 (최대 4회) — 한 방향
    // 컴팩션 후 다른 방향에서 새로운 공간이 열리는 경우를 처리.
    for (final s in openSheets) {
      if (s.placed.isEmpty) continue;
      var current = List<PlacedPart>.of(s.placed);
      for (int iter = 0; iter < 4; iter++) {
        final afterLeft = _compactLeft(current, kerf);
        final afterUp = _compactUp(afterLeft, kerf);
        if (_placementsEqual(afterUp, current)) {
          current = afterUp;
          break;
        }
        current = afterUp;
      }
      // 가는 strip(전면밴드 등) 재배치 — "본체" 우측 빈 영역으로 옮겨
      // 시트 하단·중앙에 흩어진 가는 부품을 한쪽에 모음.
      // (재배치 후 L 컴팩션을 다시 돌리지 않음 — 다시 좌측으로 끌어당겨
      //  원위치로 되돌리는 부작용이 있음.)
      current = _relocateThinStrips(
        current,
        sheetLength: s.stock.length,
        sheetWidth: s.stock.width,
        kerf: kerf,
      );
      s.placed
        ..clear()
        ..addAll(current);
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
    final allow = _allowedOrientations(part, grainLocked);
    _Placement? best;
    for (final r in rects) {
      // 정방향
      if (allow.allowOriginal &&
          part.length <= r.w &&
          part.width <= r.h) {
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
      if (allow.allowRotated && part.width <= r.w && part.length <= r.h) {
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

  /// 가는 strip (한 변이 [_thinSideThresholdMm] 이하인 부품 — 전면밴드 등)을
  /// "본체" 우측 빈 영역으로 옮겨 흩어진 자투리 부품을 한쪽으로 모음.
  ///
  /// "본체" = strip이 아닌 일반 부품들의 우측 끝.
  static const double _thinSideThresholdMm = 50;

  List<PlacedPart> _relocateThinStrips(
    List<PlacedPart> placed, {
    required double sheetLength,
    required double sheetWidth,
    required double kerf,
  }) {
    bool isThin(PlacedPart p) {
      final pw = p.rotated ? p.part.width : p.part.length;
      final ph = p.rotated ? p.part.length : p.part.width;
      return pw <= _thinSideThresholdMm || ph <= _thinSideThresholdMm;
    }

    if (!placed.any(isThin)) return placed;

    // 본체 우측 끝.
    double mainBodyRight = 0;
    for (final p in placed) {
      if (isThin(p)) continue;
      final pw = p.rotated ? p.part.width : p.part.length;
      final right = p.x + pw;
      if (right > mainBodyRight) mainBodyRight = right;
    }
    final stripX = mainBodyRight + (mainBodyRight > 0 ? kerf : 0);
    final stripW = sheetLength - stripX;
    if (stripW <= 0) return placed;

    // strip 부품들을 y=0부터 세로로 쌓아 우측에 재배치.
    final result = List<PlacedPart>.of(placed);
    double cursorY = 0;
    for (int i = 0; i < result.length; i++) {
      final p = result[i];
      if (!isThin(p)) continue;
      final pw = p.rotated ? p.part.width : p.part.length;
      final ph = p.rotated ? p.part.length : p.part.width;
      if (pw > stripW) continue;
      if (cursorY + ph > sheetWidth) break;
      // 이미 strip 안에 있고 정렬돼 있으면 굳이 옮기지 않음.
      result[i] = PlacedPart(
        part: p.part,
        x: stripX,
        y: cursorY,
        rotated: p.rotated,
      );
      cursorY += ph + kerf;
    }
    return result;
  }

  /// 두 placement 리스트의 x,y 좌표가 모두 일치하는지 (수렴 판정).
  bool _placementsEqual(List<PlacedPart> a, List<PlacedPart> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].x - b[i].x).abs() > 0.01) return false;
      if ((a[i].y - b[i].y).abs() > 0.01) return false;
    }
    return true;
  }

  /// 배치된 부품들을 상단으로 슬라이드. 부품 간 kerf 간격 유지.
  /// 상→하 순으로 처리하여 각 부품을 자기보다 위에 있는 부품들과 x 겹침이
  /// 발생하지 않는 가장 작은 y 좌표(또는 0)로 이동.
  List<PlacedPart> _compactUp(List<PlacedPart> placed, double kerf) {
    final sorted = List<PlacedPart>.of(placed)
      ..sort((a, b) {
        final cy = a.y.compareTo(b.y);
        if (cy != 0) return cy;
        return a.x.compareTo(b.x);
      });
    final result = <PlacedPart>[];
    for (final p in sorted) {
      final pw = p.rotated ? p.part.width : p.part.length;
      double targetY = 0;
      for (final q in result) {
        final qw = q.rotated ? q.part.width : q.part.length;
        final qh = q.rotated ? q.part.length : q.part.width;
        // x축 겹침 (kerf 고려).
        final xOverlap =
            (q.x < p.x + pw + kerf) && (q.x + qw + kerf > p.x);
        if (xOverlap) {
          final candidate = q.y + qh + kerf;
          if (candidate > targetY) targetY = candidate;
        }
      }
      result.add(PlacedPart(
        part: p.part,
        x: p.x,
        y: targetY,
        rotated: p.rotated,
      ));
    }
    return result;
  }

  /// 배치된 부품들을 왼쪽으로 슬라이드. 부품 간 kerf 간격 유지.
  /// 좌→우 순으로 처리하여 각 부품을 자기보다 왼쪽에 있는 부품들과 y 겹침이
  /// 발생하지 않는 가장 작은 x 좌표(또는 0)로 이동.
  List<PlacedPart> _compactLeft(List<PlacedPart> placed, double kerf) {
    final sorted = List<PlacedPart>.of(placed)
      ..sort((a, b) {
        final cx = a.x.compareTo(b.x);
        if (cx != 0) return cx;
        return a.y.compareTo(b.y);
      });
    final result = <PlacedPart>[];
    for (final p in sorted) {
      final ph = p.rotated ? p.part.length : p.part.width;
      double targetX = 0;
      for (final q in result) {
        final qw = q.rotated ? q.part.width : q.part.length;
        final qh = q.rotated ? q.part.length : q.part.width;
        // y축 겹침 (kerf 고려) — kerf 이상 떨어져 있으면 같은 행 아님.
        final yOverlap =
            (q.y < p.y + ph + kerf) && (q.y + qh + kerf > p.y);
        if (yOverlap) {
          final candidate = q.x + qw + kerf;
          if (candidate > targetX) targetX = candidate;
        }
      }
      result.add(PlacedPart(
        part: p.part,
        x: targetX,
        y: p.y,
        rotated: p.rotated,
      ));
    }
    return result;
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

enum _Sort {
  areaDesc,
  maxSideDesc,
  minSideDesc,
  lengthDesc,
  lengthWidthDesc,
  widthLengthDesc,
}

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
