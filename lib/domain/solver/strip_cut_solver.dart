import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/solver_mode.dart';
import '../models/stock_sheet.dart';

/// n-stage guillotine strip cut solver. panel saw 호환.
///
/// 알고리즘:
/// - Stage 1: 시트 전체를 풀컷해서 strip(기둥/띠)으로 자른다.
/// - Stage 2: 각 strip 안에서 segment로 자른다.
/// - Stage 3: 각 segment 안에서 trim해서 부품을 분리 (자투리 발생).
/// - Stage 4 (옵션): trim 자투리에 작은 부품을 한 번 더 끼워넣음.
///
/// 토글:
/// - preferSameWidth: strip을 동일 폭 부품끼리 묶음 (자투리↓).
/// - minimizeCuts: segment 채우기를 Best-Fit Decreasing (strip 수↓).
/// - minimizeWaste: 풀이 후 자투리에 unplaced 부품 끼워넣기 (1-pass local search).
class StripCutSolver {
  /// strip-cut 솔버 진입점.
  ///
  /// 동작 contract:
  /// - [direction]은 `verticalFirst` 또는 `horizontalFirst`만 허용. `auto`는
  ///   `AutoRecommend`가 두 방향을 비교하므로 솔버에 직접 넘기지 말 것 (assert).
  /// - [maxStages]는 2/3/4. 2-stage는 strip 내부 trim 금지 →
  ///   **`preferSameWidth` 입력은 무시되고 항상 `true`(exact-match)로 강제**된다.
  ///   3-stage 이상에서만 [preferSameWidth]가 의미를 가진다.
  /// - 결과 `CuttingPlan.sheets[i].cutSequence`는 항상 채워짐 (FFDSolver와 다른 점).
  CuttingPlan solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
    required StripDirection direction,
    required int maxStages,
    required bool preferSameWidth,
    required bool minimizeCuts,
    required bool minimizeWaste,
  }) {
    assert(direction != StripDirection.auto,
        'auto는 AutoRecommend가 처리. solver에 직접 못 넘김.');
    assert(maxStages >= 2 && maxStages <= 4,
        'maxStages must be 2, 3, or 4. Got: $maxStages.');

    if (stocks.isEmpty || parts.isEmpty) {
      return const CuttingPlan(
        sheets: [],
        unplaced: [],
        efficiencyPercent: 0,
      );
    }

    // Tasks 6-12 통합: 2/3/4-stage, minimizeWaste ON/OFF.
    // - preferSameWidth: true(exact-match) / false(widest-fit-with-trim).
    //   * maxStages == 2 인 경우 strip 내부 trim cut(=stage-3)이 금지되므로
    //     preferSameWidth 입력값과 무관하게 항상 true(exact-match)로 강제한다.
    // - minimizeCuts: false(First-Fit) / true(Best-Fit Decreasing).
    // - minimizeWaste: false(스킵) / true(메인 루프 후 1-pass post-process).
    //   * maxStages == 4 면 strip leftover rescue 다음에 segment trim rescue도 시도.
    // - vertical/horizontalFirst 모두.
    final axis = direction == StripDirection.verticalFirst
        ? const _Axis.vertical()
        : const _Axis.horizontal();
    return _solveBasic3Stage(
      stocks: stocks,
      parts: parts,
      kerf: kerf,
      grainLocked: grainLocked,
      axis: axis,
      // 2-stage: trim 금지 → exact-match 강제. 3/4-stage: 사용자 선택대로.
      preferSameWidth: maxStages == 2 ? true : preferSameWidth,
      minimizeCuts: minimizeCuts,
      minimizeWaste: minimizeWaste,
      maxStages: maxStages,
    );
  }

  /// Tasks 6-10: 3-stage basic.
  ///
  /// [axis]에 따라 verticalFirst/horizontalFirst 분기. 알고리즘은 동일하며
  /// 축에 의존하는 read만 [_Axis] 추상화를 통해 분기됨.
  ///
  /// 부품을 primary 차원 내림차순으로 정렬한 뒤, 시트 큐를 따라가며 strip을 쌓는다.
  /// 각 strip의 폭은 그 strip을 시작시킨 부품의 primary로 결정.
  ///
  /// [preferSameWidth] 토글:
  /// - true (Task 6/7 baseline): strip 내부 segment는 primary가 stripWidth와
  ///   **정확히 일치**하는 부품만 받음 (exact-match grouping → trim 0).
  /// - false (Task 8): strip 내부 segment는 primary <= stripWidth인 부품을
  ///   받고, segment trim = stripWidth - primary 로 기록 (widest-fit-with-trim).
  ///
  /// [minimizeCuts] 토글 (Task 9):
  /// - false: 부품을 OPEN strip 중 **첫 fit**에 배치 (First-Fit).
  /// - true: 부품을 OPEN strip 중 **잔여 secondary가 가장 작은 fit** 선택
  ///   (Best-Fit Decreasing). strip 수↓ 효과.
  ///
  /// [minimizeWaste] 토글 (Task 10):
  /// - false: 메인 fill 루프 후 즉시 종료.
  /// - true: 메인 루프가 끝난 뒤 unplaced 부품을 모든 시트의 OPEN strip
  ///   leftover에 다시 끼워 넣어 보는 1-pass post-processing 실행.
  ///
  /// [maxStages] (Task 12):
  /// - 4면 위 strip-leftover rescue 다음에 한 단계 더 — 각 segment의 trim
  ///   잔여 공간(stripWidth - segment 메인 부품 primary)에 작은 부품을
  ///   끼워넣는 stage-4 trim-of-trim cut을 시도한다. minimizeWaste=true 일 때만.
  ///
  /// **구현 노트**: minimizeWaste post-processing을 위해 메인 루프 동안
  /// [_SheetBuilder] 인스턴스를 살려두고, 모든 placement가 끝난 뒤
  /// [SheetLayout]/[Strip]/[Segment]를 한 번에 materialize한다.
  CuttingPlan _solveBasic3Stage({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
    required _Axis axis,
    required bool preferSameWidth,
    required bool minimizeCuts,
    required bool minimizeWaste,
    required int maxStages,
  }) {
    // 1. 부품을 qty만큼 펼치고 primary 차원 내림차순으로 정렬.
    final remaining = <CutPart>[];
    for (final p in parts) {
      for (int i = 0; i < p.qty; i++) {
        remaining.add(p);
      }
    }
    remaining.sort((a, b) => axis.primary(b).compareTo(axis.primary(a)));

    // 2. 자재 큐.
    final stockQueue = <StockSheet>[];
    for (final s in stocks) {
      for (int i = 0; i < s.qty; i++) {
        stockQueue.add(s);
      }
    }

    final builders = <_SheetBuilder>[];
    final unplaced = <CutPart>[];

    int stockIdx = 0;

    // 3. 시트 큐를 돌며 시트마다 빌더로 채움. 더 이상 어떤 부품도 못 들어가면 다음 시트.
    while (remaining.isNotEmpty) {
      if (stockIdx >= stockQueue.length) {
        // 시트 더 없음 → 남은 부품 전부 unplaced.
        unplaced.addAll(remaining);
        remaining.clear();
        break;
      }

      final sheet = stockQueue[stockIdx];
      final builder = _SheetBuilder(
        sheet: sheet,
        kerf: kerf,
        axis: axis,
        preferSameWidth: preferSameWidth,
        minimizeCuts: minimizeCuts,
      );

      // 이 시트에 가능한 만큼 채움.
      builder.fill(remaining, grainLocked: grainLocked);

      if (builder.placed.isEmpty) {
        // 빈 시트인데 어떤 부품도 못 들어감 → 첫 부품이 시트보다 큼 → unplaced로 빼고
        // 같은 시트에 다음 부품 시도.
        unplaced.add(remaining.removeAt(0));
        // stockIdx는 그대로 — 같은 시트에 다른 부품 시도.
        continue;
      }

      // 빌더 보관 (post-processing에서 재사용).
      builders.add(builder);
      stockIdx++;
    }

    // 4. minimizeWaste post-processing pass (Task 10).
    // 메인 루프에서 발생한 unplaced 부품 각각에 대해, 이미 commit된 시트의
    // OPEN strip leftover 영역에 끼워 넣을 수 있는지 시도. 들어가면 unplaced에서 제거.
    //
    // 강한 보장은 어렵다 — primary desc 정렬 + FF/BFD에 의해 메인 루프가
    // 이미 모든 OPEN strip을 시도하므로, 같은 시트의 strip leftover에서
    // unplaced를 다시 발견할 일은 사실상 거의 없다 ("unplaced 발생 = 모든 OPEN
    // strip이 fit 안 했고 새 strip도 못 만든 상태"이기 때문).
    // 그러나 멀티-시트 시나리오 + 작은 부품이 큰 부품 unplaced 후에
    // 처리되는 정렬 경계 조건 등에서는 실제로 rescue가 일어날 수 있다.
    // 본 구현은 그 가능성을 막지 않는다(=모드 OFF 대비 절대 regress 안 함).
    if (minimizeWaste && unplaced.isNotEmpty && builders.isNotEmpty) {
      final stillUnplaced = <CutPart>[];
      for (final p in unplaced) {
        bool placed = false;
        for (final b in builders) {
          // _pickStripFor: minimizeCuts-aware. 메인 루프와 동일 정책.
          final fit = b._pickStripFor(p);
          if (fit != null) {
            b._placeInStrip(p, fit);
            placed = true;
            break;
          }
        }
        if (!placed) stillUnplaced.add(p);
      }
      unplaced
        ..clear()
        ..addAll(stillUnplaced);
    }

    // 5. Task 12: maxStages=4 + minimizeWaste 일 때 segment trim rescue.
    // strip leftover rescue로도 못 들어간 부품을 각 segment의 trim 잔여 공간
    // (preferSameWidth=false 일 때 stripWidth - 메인 부품 primary)에 끼워 넣어 본다.
    // stage-4 cut: stage-3 trim 안에서 또 한 번 잘라내는 cut.
    // 단순화: segment 당 최대 1개의 rescue 부품만 허용.
    if (minimizeWaste &&
        maxStages == 4 &&
        unplaced.isNotEmpty &&
        builders.isNotEmpty) {
      final stillUnplaced = <CutPart>[];
      for (final p in unplaced) {
        bool placed = false;
        for (final b in builders) {
          if (b._tryFitInSegmentTrim(p)) {
            placed = true;
            break;
          }
        }
        if (!placed) stillUnplaced.add(p);
      }
      unplaced
        ..clear()
        ..addAll(stillUnplaced);
    }

    // 5. 빌더들을 SheetLayout 으로 materialize + 면적/효율 집계.
    final sheets = <SheetLayout>[];
    double usedArea = 0;
    double totalSheetArea = 0;
    for (final b in builders) {
      sheets.add(SheetLayout(
        stockSheetId: b.sheet.id,
        placed: List.of(b.placed),
        sheetLength: b.sheet.length,
        sheetWidth: b.sheet.width,
        cutSequence: CutSequence(
          verticalFirst: axis.verticalFirst,
          strips: b.buildStrips(),
        ),
      ));
      totalSheetArea += b.sheet.length * b.sheet.width;
      usedArea += b.usedArea;
    }

    final efficiency =
        totalSheetArea == 0 ? 0.0 : (usedArea / totalSheetArea) * 100;
    return CuttingPlan(
      sheets: sheets,
      unplaced: unplaced,
      efficiencyPercent: efficiency,
    );
  }
}

/// 축 추상화. 단일 [_SheetBuilder]가 verticalFirst/horizontalFirst 양쪽을
/// 처리할 수 있도록 방향 의존적인 read만 캡슐화한다.
///
/// "primary" = stage-1 strip cut이 소비하는 차원 (V: length, H: width).
/// "secondary" = strip 내부에서 segment가 쌓이는 수직 차원.
class _Axis {
  final bool verticalFirst;

  const _Axis.vertical() : verticalFirst = true;
  const _Axis.horizontal() : verticalFirst = false;

  /// 부품의 primary(strip-stacking) 차원.
  /// vertical: 부품 length가 X를 소비. horizontal: 부품 width가 Y를 소비.
  double primary(CutPart p) => verticalFirst ? p.length : p.width;

  /// 부품의 secondary(within-strip) 차원.
  double secondary(CutPart p) => verticalFirst ? p.width : p.length;

  /// 시트의 primary 한계.
  double sheetPrimary(StockSheet s) => verticalFirst ? s.length : s.width;

  /// 시트의 secondary 한계.
  double sheetSecondary(StockSheet s) => verticalFirst ? s.width : s.length;

  /// strip(primary) + segment(secondary) 좌표를 x/y로 매핑하여 PlacedPart 생성.
  PlacedPart placePart(CutPart part, double stripOffset, double segOffset) {
    return PlacedPart(
      part: part,
      x: verticalFirst ? stripOffset : segOffset,
      y: verticalFirst ? segOffset : stripOffset,
      rotated: false,
    );
  }
}

/// 시트 빌더가 내부적으로 추적하는 OPEN strip 상태.
/// 각 strip은 primary축의 한 구간을 차지하며, secondary축으로 segment를 쌓는다.
class _OpenStrip {
  final double offset;
  final double width;
  final List<Segment> segments = [];
  double currentSecondary = 0;
  bool isFirstSegment = true;

  _OpenStrip({required this.offset, required this.width});
}

/// 한 장의 시트를 채우는 빌더. [_Axis]에 따라 verticalFirst/horizontalFirst
/// 양쪽 모드를 처리.
///
/// **알고리즘 (Task 9 refactor)**: 모든 strip을 동시에 OPEN 상태로 유지하면서
/// 부품을 하나씩 처리한다. 각 부품마다:
/// 1. OPEN strip 중 부품이 들어가는 것들을 찾는다.
/// 2. [minimizeCuts]에 따라 그 중 하나를 선택:
///    - false (First-Fit): 첫 fit strip.
///    - true (Best-Fit): 잔여 secondary가 가장 작은 fit strip.
/// 3. 어느 strip에도 안 들어가면 새 strip을 OPEN.
/// 4. 새 strip도 못 만들면 (시트 primary 초과 / secondary 초과) skip.
class _SheetBuilder {
  final StockSheet sheet;
  final double kerf;
  final _Axis axis;

  /// strip 내부 segment의 부품 매칭 정책.
  /// - true: primary == stripWidth만 받음 (exact-match, trim=0).
  /// - false: primary <= stripWidth 받음 (widest-fit, trim=stripWidth-primary).
  final bool preferSameWidth;

  /// strip 선택 정책.
  /// - false: First-Fit (open strip 중 처음 fit하는 것).
  /// - true: Best-Fit Decreasing (잔여 secondary가 가장 작은 fit).
  final bool minimizeCuts;

  final List<PlacedPart> placed = [];
  final List<_OpenStrip> _openStrips = [];
  double usedArea = 0;

  _SheetBuilder({
    required this.sheet,
    required this.kerf,
    required this.axis,
    required this.preferSameWidth,
    required this.minimizeCuts,
  });

  /// open strip의 primary축 끝 (다음 strip을 시작할 수 있는 좌표 직전).
  double get _lastStripEnd {
    if (_openStrips.isEmpty) return 0;
    final last = _openStrips.last;
    return last.offset + last.width;
  }

  /// [remaining]에서 부품을 꺼내 이 시트를 채운다. 들어간 부품은 list에서 제거.
  ///
  /// 부품은 primary 차원 내림차순으로 정렬되어 있다고 가정.
  /// 각 부품은:
  /// 1. 현재 OPEN strip 중 fit하는 strip을 찾는다 (preferSameWidth로 gating).
  /// 2. minimizeCuts에 따라 First-Fit / Best-Fit 선택.
  /// 3. fit strip 없으면 새 strip OPEN 시도. 못 만들면 skip.
  void fill(List<CutPart> remaining, {required bool grainLocked}) {
    int idx = 0;
    while (idx < remaining.length) {
      final p = remaining[idx];

      // 1) OPEN strip 중에 들어갈 수 있는 것 찾기.
      final fitStrip = _pickStripFor(p);
      if (fitStrip != null) {
        _placeInStrip(p, fitStrip);
        remaining.removeAt(idx);
        continue;
      }

      // 2) 새 strip OPEN 시도.
      final newStrip = _tryOpenStripFor(p);
      if (newStrip != null) {
        _openStrips.add(newStrip);
        _placeInStrip(p, newStrip);
        remaining.removeAt(idx);
        continue;
      }

      // 3) 어떤 strip에도 못 들어가고 새 strip도 못 만듦 → 다음 부품 시도.
      idx++;
    }
  }

  /// open strip 중 부품 [p]가 들어갈 수 있는 strip을 선택. 없으면 null.
  /// minimizeCuts=true면 Best-Fit, false면 First-Fit.
  _OpenStrip? _pickStripFor(CutPart p) {
    final partPrimary = axis.primary(p);
    final partSecondary = axis.secondary(p);

    _OpenStrip? best;
    double bestLeftover = double.infinity;

    for (final s in _openStrips) {
      // gating: preferSameWidth=true → 정확히 일치, false → primary <= stripWidth.
      final bool primaryFits = preferSameWidth
          ? partPrimary == s.width
          : partPrimary <= s.width;
      if (!primaryFits) continue;

      // secondary fit 검사: 다음 segment의 시작 좌표 + 부품 secondary <= 시트 secondary.
      final segOffset =
          s.isFirstSegment ? s.currentSecondary : s.currentSecondary + kerf;
      if (segOffset + partSecondary > axis.sheetSecondary(sheet)) continue;

      if (!minimizeCuts) {
        // First-Fit: 처음 fit하는 strip 즉시 반환.
        return s;
      }

      // Best-Fit: 부품 배치 후 잔여 secondary가 가장 작은 strip 선택.
      final newSecondary = segOffset + partSecondary;
      final leftover = axis.sheetSecondary(sheet) - newSecondary;
      if (leftover < bestLeftover) {
        bestLeftover = leftover;
        best = s;
      }
    }

    return best;
  }

  /// 부품 [p]를 위한 새 strip을 만들 수 있으면 만들고 반환. 못 만들면 null.
  /// 새 strip의 width는 부품의 primary와 같다. 시트의 primary 한계를 체크.
  _OpenStrip? _tryOpenStripFor(CutPart p) {
    final partPrimary = axis.primary(p);
    final partSecondary = axis.secondary(p);

    // 새 strip의 시작 primary 좌표.
    // 첫 strip은 0, 이후로는 마지막 strip의 끝 + kerf.
    final stripOffset =
        _openStrips.isEmpty ? 0.0 : _lastStripEnd + kerf;

    if (stripOffset + partPrimary > axis.sheetPrimary(sheet)) {
      // 새 strip을 만들면 시트의 primary 한계를 넘김.
      return null;
    }

    // 시트의 secondary 한계 안에 첫 부품이 들어가는지.
    if (partSecondary > axis.sheetSecondary(sheet)) {
      // 첫 부품이 secondary 방향으로 시트보다 크다 → 회전 없이 못 넣음.
      return null;
    }

    return _OpenStrip(offset: stripOffset, width: partPrimary);
  }

  /// 부품 [p]를 OPEN strip [s]에 실제로 배치.
  /// segment 생성, placed/usedArea 갱신.
  void _placeInStrip(CutPart p, _OpenStrip s) {
    final partPrimary = axis.primary(p);
    final partSecondary = axis.secondary(p);

    final segOffset =
        s.isFirstSegment ? s.currentSecondary : s.currentSecondary + kerf;

    final placedPart = axis.placePart(p, s.offset, segOffset);
    placed.add(placedPart);
    usedArea += p.length * p.width;

    // trim:
    // - preferSameWidth=true (exact-match) → 항상 0 (gate가 정확히 일치 강제).
    // - preferSameWidth=false (widest-fit) → stripWidth - partPrimary (>= 0).
    final segTrim = preferSameWidth ? 0.0 : s.width - partPrimary;
    s.segments.add(Segment(
      offset: segOffset,
      length: partSecondary,
      parts: [placedPart],
      trim: segTrim,
    ));

    s.currentSecondary = segOffset + partSecondary;
    s.isFirstSegment = false;
  }

  /// Task 12 — maxStages=4 segment trim rescue.
  ///
  /// 부품 [p]를 이 시트의 어떤 segment의 trim 잔여 공간에 끼워 넣을 수 있으면
  /// 끼워 넣고 true. trim 공간 = stripWidth - segment 메인 부품 primary.
  ///
  /// fit 조건:
  /// - primary(p) <= seg.trim - kerf  (kerf=0 이면 단순히 primary <= trim)
  ///   → stage-4 cut을 위한 kerf 분리 공간을 trim에서 빼준다.
  /// - secondary(p) <= seg.length     (segment가 차지하는 secondary 폭 안에 들어가야)
  ///
  /// 단순화:
  /// - segment 하나당 rescue 부품은 1개만 허용 (= 이미 parts.length > 1 이면 skip).
  /// - segment 내부의 다단 nesting은 지원하지 않음.
  ///
  /// 좌표 (verticalFirst):
  /// - 메인 부품: x = strip.offset, primary 차원 = primary(메인부품).
  /// - rescue: x = strip.offset + primary(메인부품) + kerf, y = seg.offset.
  /// - horizontalFirst 도 axis.placePart 가 자동으로 swap.
  ///
  /// Segment 는 immutable 이므로 새 [Segment] 인스턴스로 교체한다.
  bool _tryFitInSegmentTrim(CutPart p) {
    final partPrimary = axis.primary(p);
    final partSecondary = axis.secondary(p);

    for (final strip in _openStrips) {
      for (int i = 0; i < strip.segments.length; i++) {
        final seg = strip.segments[i];
        // 아직 비어있는 trim 만 후보 (parts.length > 1 이면 이미 rescue 됐음).
        if (seg.trim <= 0) continue;
        if (seg.parts.length > 1) continue;

        // stage-4: 메인부품/rescue 사이 + rescue/잔여sliver 사이 두 번의 kerf.
        // (잔여 sliver==0인 perfect-fit 케이스에선 두 번째 kerf 불필요하지만,
        //  fit 단계에서는 lenient gate(=한 kerf)로 두고, trim 회계는 보수적으로 2*kerf 차감
        //  + clamp(0, ∞)로 정리한다.)
        final usableTrim = seg.trim - kerf;
        if (usableTrim <= 0) continue;
        if (partPrimary > usableTrim) continue;
        if (partSecondary > seg.length) continue;

        // 메인 부품의 primary 끝 좌표 (= strip.offset + 메인부품의 primary).
        // seg.trim = stripWidth - 메인부품.primary  ⇒  메인부품.primary = strip.width - seg.trim.
        final mainPartPrimary = strip.width - seg.trim;
        final rescuePrimaryOffset = strip.offset + mainPartPrimary + kerf;

        final placedPart = axis.placePart(p, rescuePrimaryOffset, seg.offset);
        placed.add(placedPart);
        usedArea += p.length * p.width;

        // segment 교체: parts에 rescue 추가, trim은 partPrimary + 2*kerf 차감 (clamp 0).
        final newParts = List<PlacedPart>.from(seg.parts)..add(placedPart);
        final consumed = partPrimary + 2 * kerf;
        final newTrim = (seg.trim - consumed).clamp(0.0, double.infinity);
        strip.segments[i] = Segment(
          offset: seg.offset,
          length: seg.length,
          parts: newParts,
          trim: newTrim,
        );

        return true;
      }
    }

    return false;
  }

  /// open strip을 최종 [Strip] 모델로 변환.
  /// segment가 0개인 strip은 발생할 수 없음 (strip은 부품과 함께 OPEN되므로).
  List<Strip> buildStrips() {
    return [
      for (final s in _openStrips)
        Strip(
          offset: s.offset,
          width: s.width,
          length: axis.sheetSecondary(sheet),
          segments: s.segments,
        ),
    ];
  }
}
