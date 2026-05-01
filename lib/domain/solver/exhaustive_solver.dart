import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/stock_sheet.dart';
import 'ffd_solver.dart';

/// Exact 2D guillotine packing via branch-and-bound with BLF (Bottom-Left Fill)
/// position enumeration and area-based upper-bound pruning.
///
/// **NP-hard 문제이므로 이론적 최악은 지수**. 그러나 다음 가지치기로 실전에선
/// ~16 부품 수초 내 탐색 가능:
///
/// 1. **이론적 상한 가지치기**: `(현재 사용된 부품 면적 + 남은 부품 면적) / 사용된 시트 면적 ≥ best`인
///    경로만 탐색. 더 못 만들 경로는 즉시 가지치기.
/// 2. **시간 제한 (deadline)**: 한도 도달 시 그때까지 best 반환 — heuristic fallback.
/// 3. **BLF 위치만 고려**: free rect 좌상단만 placement 후보 (위치 차원 폭발 억제).
/// 4. **회전 양방향 시도**: 정방향과 회전을 둘 다 분기.
/// 5. **불가능 부품 즉시 제거**: 어느 자유 사각형에도 안 들어가는 부품은 unplaced로
///    분리 후 다음 단계.
///
/// 시간 한도 내에 최적해를 못 찾을 수 있다 — 그 경우 FFD heuristic을 초기 best로
/// 사용해 항상 FFD 이상의 결과를 보장한다.
class ExhaustiveSolver {
  ExhaustiveSolver({this.timeLimit = const Duration(seconds: 8)});

  /// 탐색 데드라인. 도달하면 그때까지 찾은 best 반환.
  final Duration timeLimit;

  CuttingPlan solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
  }) {
    // 부품 펼치기
    final expanded = <CutPart>[];
    for (final p in parts) {
      for (var i = 0; i < p.qty; i++) {
        expanded.add(p);
      }
    }
    if (expanded.isEmpty) {
      return const CuttingPlan(
          sheets: [], unplaced: [], efficiencyPercent: 0);
    }

    // 시트 큐 펼치기
    final stockQueue = <StockSheet>[];
    for (final s in stocks) {
      for (var i = 0; i < s.qty; i++) {
        stockQueue.add(s);
      }
    }
    if (stockQueue.isEmpty) {
      return CuttingPlan(
          sheets: const [], unplaced: List.of(expanded), efficiencyPercent: 0);
    }

    // Heuristic warm start — 항상 이 결과 이상으로 보장.
    final ffdBest = FFDSolver().solve(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
    );

    // 정렬: 면적 큰 순서 (분기 효율 ↑).
    expanded.sort((a, b) =>
        (b.length * b.width).compareTo(a.length * a.width));

    final partsTotalArea = expanded.fold<double>(
        0, (acc, p) => acc + p.length * p.width);

    final state = _SearchState(
      bestUsedArea: _planUsedArea(ffdBest),
      bestPlan: ffdBest,
      deadline: DateTime.now().add(timeLimit),
      timedOut: false,
    );

    final initialOpenSheets = <_OpenSheet>[];
    final initialUnplaced = <CutPart>[];
    _dfs(
      partIdx: 0,
      parts: expanded,
      partsTotalAreaRemaining: partsTotalArea,
      stockQueue: stockQueue,
      stockIdx: 0,
      openSheets: initialOpenSheets,
      unplaced: initialUnplaced,
      kerf: kerf,
      grainLocked: grainLocked,
      state: state,
    );
    return state.bestPlan;
  }

  /// DFS with branch-and-bound.
  /// - [openSheets]: 현재까지 부품이 배치된 시트들 (mutable, 함수가 push/pop).
  /// - [unplaced]: 미배치로 결정된 부품들 (mutable).
  void _dfs({
    required int partIdx,
    required List<CutPart> parts,
    required double partsTotalAreaRemaining,
    required List<StockSheet> stockQueue,
    required int stockIdx,
    required List<_OpenSheet> openSheets,
    required List<CutPart> unplaced,
    required double kerf,
    required bool grainLocked,
    required _SearchState state,
  }) {
    if (state.timedOut) return;
    if (DateTime.now().isAfter(state.deadline)) {
      state.timedOut = true;
      return;
    }

    // 모든 부품 처리 완료 — 결과 평가.
    if (partIdx >= parts.length) {
      final usedArea = _openSheetsUsedArea(openSheets);
      if (usedArea > state.bestUsedArea) {
        state.bestUsedArea = usedArea;
        state.bestPlan = _materialize(openSheets, unplaced);
      }
      return;
    }

    // === 가지치기: 상한이 best를 못 넘으면 즉시 return ===
    final placedArea = _openSheetsUsedArea(openSheets);
    final upperBound = placedArea + partsTotalAreaRemaining;
    if (upperBound <= state.bestUsedArea) return;

    final part = parts[partIdx];

    // 시도 1: 기존 열린 시트의 free rect들에 배치
    for (final sheet in openSheets) {
      for (var ri = 0; ri < sheet.freeRects.length; ri++) {
        final r = sheet.freeRects[ri];
        for (final rotated in const [false, true]) {
          if (grainLocked && rotated) continue;
          final pl = rotated ? part.width : part.length;
          final pw = rotated ? part.length : part.width;
          if (pl > r.w || pw > r.h) continue;

          // place
          final savedRects = sheet.freeRects;
          sheet.freeRects = _splitRects(savedRects, ri, pl, pw, kerf);
          sheet.placed.add(PlacedPart(
            part: part,
            x: r.x,
            y: r.y,
            rotated: rotated,
          ));

          _dfs(
            partIdx: partIdx + 1,
            parts: parts,
            partsTotalAreaRemaining:
                partsTotalAreaRemaining - part.length * part.width,
            stockQueue: stockQueue,
            stockIdx: stockIdx,
            openSheets: openSheets,
            unplaced: unplaced,
            kerf: kerf,
            grainLocked: grainLocked,
            state: state,
          );

          // unplace (rollback)
          sheet.placed.removeLast();
          sheet.freeRects = savedRects;

          if (state.timedOut) return;
        }
      }
    }

    // 시도 2: 새 시트 열어 배치
    if (stockIdx < stockQueue.length) {
      final s = stockQueue[stockIdx];
      for (final rotated in const [false, true]) {
        if (grainLocked && rotated) continue;
        final pl = rotated ? part.width : part.length;
        final pw = rotated ? part.length : part.width;
        if (pl > s.length || pw > s.width) continue;

        final newSheet = _OpenSheet(
          stock: s,
          freeRects: _splitRects(
            [_Rect(0, 0, s.length, s.width)],
            0,
            pl,
            pw,
            kerf,
          ),
          placed: [
            PlacedPart(part: part, x: 0, y: 0, rotated: rotated),
          ],
        );
        openSheets.add(newSheet);

        _dfs(
          partIdx: partIdx + 1,
          parts: parts,
          partsTotalAreaRemaining:
              partsTotalAreaRemaining - part.length * part.width,
          stockQueue: stockQueue,
          stockIdx: stockIdx + 1,
          openSheets: openSheets,
          unplaced: unplaced,
          kerf: kerf,
          grainLocked: grainLocked,
          state: state,
        );

        openSheets.removeLast();

        if (state.timedOut) return;
      }
    }

    // 시도 3: skip — 이 부품을 unplaced로 두고 다음 부품으로
    unplaced.add(part);
    _dfs(
      partIdx: partIdx + 1,
      parts: parts,
      partsTotalAreaRemaining:
          partsTotalAreaRemaining - part.length * part.width,
      stockQueue: stockQueue,
      stockIdx: stockIdx,
      openSheets: openSheets,
      unplaced: unplaced,
      kerf: kerf,
      grainLocked: grainLocked,
      state: state,
    );
    unplaced.removeLast();
  }

  /// guillotine split — usedRect를 right + bottom 두 새 rect로 분리.
  /// 잔여 큰 단일 residual 보존을 위한 split 방향 선택은 FFD와 동일.
  List<_Rect> _splitRects(
      List<_Rect> rects, int usedIdx, double pl, double pw, double kerf) {
    final r = rects[usedIdx];
    final result = <_Rect>[];
    for (var i = 0; i < rects.length; i++) {
      if (i == usedIdx) {
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
        final hMax = (r.w * leftoverH) > (leftoverW * pw)
            ? r.w * leftoverH
            : leftoverW * pw;
        final vMax = (pl * leftoverH) > (leftoverW * r.h)
            ? pl * leftoverH
            : leftoverW * r.h;
        if (hMax >= vMax) {
          result.add(_Rect(r.x, r.y + pw + kerf, r.w, leftoverH));
          result.add(_Rect(r.x + pl + kerf, r.y, leftoverW, pw));
        } else {
          result.add(_Rect(r.x, r.y + pw + kerf, pl, leftoverH));
          result.add(_Rect(r.x + pl + kerf, r.y, leftoverW, r.h));
        }
      } else {
        result.add(rects[i]);
      }
    }
    return result;
  }

  double _openSheetsUsedArea(List<_OpenSheet> sheets) {
    var total = 0.0;
    for (final s in sheets) {
      for (final p in s.placed) {
        total += p.part.length * p.part.width;
      }
    }
    return total;
  }

  double _planUsedArea(CuttingPlan p) {
    var total = 0.0;
    for (final s in p.sheets) {
      for (final pp in s.placed) {
        total += pp.part.length * pp.part.width;
      }
    }
    return total;
  }

  CuttingPlan _materialize(
      List<_OpenSheet> openSheets, List<CutPart> unplaced) {
    final layouts = <SheetLayout>[];
    var totalArea = 0.0;
    var usedArea = 0.0;
    for (final s in openSheets) {
      if (s.placed.isEmpty) continue;
      layouts.add(SheetLayout(
        stockSheetId: s.stock.id,
        placed: List.of(s.placed),
        sheetLength: s.stock.length,
        sheetWidth: s.stock.width,
        leftovers: s.freeRects
            .map((r) =>
                LeftoverRect(x: r.x, y: r.y, width: r.w, height: r.h))
            .toList(),
      ));
      totalArea += s.stock.length * s.stock.width;
      for (final p in s.placed) {
        usedArea += p.part.length * p.part.width;
      }
    }
    final eff = totalArea == 0 ? 0.0 : (usedArea / totalArea) * 100;
    return CuttingPlan(
      sheets: layouts,
      unplaced: List.of(unplaced),
      efficiencyPercent: eff,
    );
  }
}

class _Rect {
  final double x;
  final double y;
  final double w;
  final double h;
  const _Rect(this.x, this.y, this.w, this.h);
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

class _SearchState {
  double bestUsedArea;
  CuttingPlan bestPlan;
  final DateTime deadline;
  bool timedOut;

  _SearchState({
    required this.bestUsedArea,
    required this.bestPlan,
    required this.deadline,
    required this.timedOut,
  });
}
