# Strip-Cut Solver Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Cutmaster에 panel saw 작업장에서 실제로 자를 수 있는 n-stage strip-cut 솔버를 추가한다. 기존 FFD 솔버는 그대로 유지하고 `Project.solverMode`로 토글한다.

**Architecture:**
- 새 솔버 `StripCutSolver` (`lib/domain/solver/strip_cut_solver.dart`) — 2/3/4-stage guillotine, 세로/가로 풀컷 두 방향, 세 개의 직교 토글 (`preferSameWidth`, `minimizeCuts`, `minimizeWaste`).
- `AutoRecommend` 래퍼 — 두 방향을 모두 풀고 사용자가 켠 metric으로 비교, runner-up 정보도 결과에 함께 담음.
- `Project` 스키마 v2 → v3 (backward-compat). 새 필드 5개 (`solverMode`, `stripDirection`, `maxStages`, `preferSameWidth`, `minimizeCuts`, `minimizeWaste`).
- UI: 좌측 `OptionsSection` 아래에 collapsible "절단 옵션" 섹션. SolverMode radio + (strip-cut 모드에서만) 방향/단계/체크박스 노출. 결과 패널에 자동 추천 비교 chip.

**Tech Stack:** Dart / Flutter / Riverpod, `flutter_test`. 기존 모델 컨벤션 (`copyWith`, `toJson`, `fromJson` + schemaVersion 가드) 그대로 따른다.

**Commit policy:** 사용자 CLAUDE.md 규칙에 따라 **자동 커밋 금지**. 각 task의 Step "Commit"은 *사용자에게 commit message 제안 + 승인 대기*를 의미한다. 승인 없이 `git commit`을 실행하지 말 것.

**Worktree:** 이 plan은 dedicated worktree에서 실행하는 것이 안전하다. 먼저 superpowers:using-git-worktrees로 worktree를 만든 뒤 시작할 것.

---

## Phase 1 — 데이터 모델 (Project schema v3)

### Task 1: SolverMode / StripDirection enum 추가

**Files:**
- Create: `lib/domain/models/solver_mode.dart`
- Test: `test/domain/models/solver_mode_test.dart`

**Step 1: Write the failing test**

```dart
// test/domain/models/solver_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  test('SolverMode has ffd and stripCut values', () {
    expect(SolverMode.values, [SolverMode.ffd, SolverMode.stripCut]);
  });

  test('StripDirection has three values in expected order', () {
    expect(StripDirection.values, [
      StripDirection.verticalFirst,
      StripDirection.horizontalFirst,
      StripDirection.auto,
    ]);
  });

  test('SolverMode.fromName roundtrips', () {
    for (final m in SolverMode.values) {
      expect(SolverMode.fromName(m.name), m);
    }
  });

  test('StripDirection.fromName roundtrips', () {
    for (final d in StripDirection.values) {
      expect(StripDirection.fromName(d.name), d);
    }
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/domain/models/solver_mode_test.dart`
Expected: FAIL — `solver_mode.dart` 없음.

**Step 3: Write minimal implementation**

```dart
// lib/domain/models/solver_mode.dart

/// 솔버 모드. FFD = 자유 배치 (효율 우선), stripCut = panel saw 호환 (실작업 가능).
enum SolverMode {
  ffd,
  stripCut;

  static SolverMode fromName(String name) =>
      SolverMode.values.firstWhere((m) => m.name == name, orElse: () => ffd);
}

/// strip-cut 모드의 절단 방향.
enum StripDirection {
  /// 세로 풀컷 → 가로 분할.
  verticalFirst,

  /// 가로 풀컷 → 세로 분할.
  horizontalFirst,

  /// 두 방향 모두 풀고 더 나은 쪽 선택.
  auto;

  static StripDirection fromName(String name) =>
      StripDirection.values.firstWhere((d) => d.name == name, orElse: () => auto);
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/domain/models/solver_mode_test.dart`
Expected: PASS (4 tests).

**Step 5: Commit (사용자 승인 후)**

제안 메시지: `feat(domain): add SolverMode + StripDirection enums`

---

### Task 2: Project에 새 필드 5개 + copyWith + toJson v3

**Files:**
- Modify: `lib/domain/models/project.dart` (전체 — 필드/생성자/copyWith/toJson 갱신)
- Test: `test/domain/models/project_json_test.dart` (기존 테스트에 v3 케이스 추가)

**Step 1: 기존 테스트가 어떤 식인지 먼저 읽기**

Read: `test/domain/models/project_json_test.dart` 전체. 기존 roundtrip 테스트 패턴을 따라간다.

**Step 2: 실패 테스트 작성 — v3 roundtrip**

`test/domain/models/project_json_test.dart` 끝에 추가:

```dart
test('Project v3 roundtrip preserves new strip-cut fields', () {
  final orig = Project.create(id: 'p1', name: '서랍').copyWith(
    solverMode: SolverMode.stripCut,
    stripDirection: StripDirection.horizontalFirst,
    maxStages: 4,
    preferSameWidth: false,
    minimizeCuts: true,
    minimizeWaste: false,
  );

  final json = orig.toJson();
  expect(json['schemaVersion'], 3);
  expect(json['solverMode'], 'stripCut');
  expect(json['stripDirection'], 'horizontalFirst');
  expect(json['maxStages'], 4);
  expect(json['preferSameWidth'], false);
  expect(json['minimizeCuts'], true);
  expect(json['minimizeWaste'], false);

  final back = Project.fromJson(json);
  expect(back.solverMode, SolverMode.stripCut);
  expect(back.stripDirection, StripDirection.horizontalFirst);
  expect(back.maxStages, 4);
  expect(back.preferSameWidth, false);
  expect(back.minimizeCuts, true);
  expect(back.minimizeWaste, false);
});
```

`import 'package:cutmaster/domain/models/solver_mode.dart';` 도 import 섹션에 추가.

**Step 3: 테스트 실행해서 fail 확인**

Run: `flutter test test/domain/models/project_json_test.dart`
Expected: FAIL — `solverMode` 필드/`copyWith` 인자 없음.

**Step 4: Project 모델 수정**

`lib/domain/models/project.dart`:

1. import 추가: `import 'solver_mode.dart';`
2. `schemaVersion` 상수: `2` → `3`. 주석에 v3 마이그레이션 설명 추가.
3. 필드 추가 (`showShortcutHints` 다음에 5개):
   ```dart
   final SolverMode solverMode;
   final StripDirection stripDirection;
   final int maxStages;
   final bool preferSameWidth;
   final bool minimizeCuts;
   final bool minimizeWaste;
   ```
4. 생성자 default: `this.solverMode = SolverMode.ffd, this.stripDirection = StripDirection.auto, this.maxStages = 3, this.preferSameWidth = true, this.minimizeCuts = true, this.minimizeWaste = true,`
5. `copyWith` 인자 + 본문에 5개 매핑.
6. `toJson`에 새 5개 키 추가:
   ```dart
   'solverMode': solverMode.name,
   'stripDirection': stripDirection.name,
   'maxStages': maxStages,
   'preferSameWidth': preferSameWidth,
   'minimizeCuts': minimizeCuts,
   'minimizeWaste': minimizeWaste,
   ```
7. `fromJson`에서 v3 가드 (`if (v > 3) throw`) + 새 키 backward-default:
   ```dart
   solverMode: SolverMode.fromName(j['solverMode'] as String? ?? 'ffd'),
   stripDirection:
       StripDirection.fromName(j['stripDirection'] as String? ?? 'auto'),
   maxStages: (j['maxStages'] as int?) ?? 3,
   preferSameWidth: (j['preferSameWidth'] as bool?) ?? true,
   minimizeCuts: (j['minimizeCuts'] as bool?) ?? true,
   minimizeWaste: (j['minimizeWaste'] as bool?) ?? true,
   ```

**Step 5: 테스트 실행해서 pass 확인**

Run: `flutter test test/domain/models/project_json_test.dart`
Expected: PASS (모든 케이스).

**Step 6: 전체 테스트 회귀 확인**

Run: `flutter test`
Expected: PASS — 기존 v2 fixture 가 새 default를 받아 정상 로드되는지 확인.

**Step 7: Commit (사용자 승인 후)**

제안 메시지: `feat(domain): bump Project schema to v3 with strip-cut fields`

---

### Task 3: v2 → v3 마이그레이션 fixture 테스트

**Files:**
- Test: `test/domain/models/project_v2_migration_test.dart` (new)

목적: v2 형식 JSON (새 필드 모두 누락)이 default 값과 함께 그대로 로드되는지 보장.

**Step 1: 실패 테스트 작성**

```dart
// test/domain/models/project_v2_migration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  test('v2 JSON loads with default solver fields (ffd / auto / 3 / all on)', () {
    final v2Json = {
      'schemaVersion': 2,
      'id': 'p1',
      'name': 'legacy',
      'kerf': 3.0,
      'grainLocked': false,
      'showPartLabels': true,
      'useSingleSheet': false,
      'showShortcutHints': true,
      'stocks': const [],
      'parts': const [],
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };

    final p = Project.fromJson(v2Json);
    expect(p.solverMode, SolverMode.ffd);
    expect(p.stripDirection, StripDirection.auto);
    expect(p.maxStages, 3);
    expect(p.preferSameWidth, true);
    expect(p.minimizeCuts, true);
    expect(p.minimizeWaste, true);
  });
}
```

**Step 2: 테스트 실행 → 이미 Task 2의 fromJson default 덕분에 PASS여야 정상**

Run: `flutter test test/domain/models/project_v2_migration_test.dart`
Expected: PASS.

**Step 3: Commit (사용자 승인 후)**

제안 메시지: `test(domain): v2 → v3 Project migration fixture`

---

## Phase 2 — Strip / Segment 출력 자료구조

### Task 4: Strip / Segment / CutSequence 모델

**Files:**
- Modify: `lib/domain/models/cutting_plan.dart` (말미에 새 클래스 추가)
- Test: `test/domain/models/cutting_plan_test.dart` (new)

`SheetLayout`에 optional `cutSequence` 필드를 추가해서 strip-cut 모드일 때만 채워지게 한다. FFD 모드에서는 `null`.

**Step 1: 실패 테스트 작성**

```dart
// test/domain/models/cutting_plan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';

void main() {
  test('Strip exposes total cut length (segments + trims)', () {
    final s = Strip(
      offset: 0,
      width: 400,
      length: 1220,
      segments: [
        Segment(offset: 0, length: 600, parts: const [], trim: 0),
        Segment(offset: 600, length: 500, parts: const [], trim: 100),
      ],
    );
    expect(s.segments.length, 2);
    expect(s.segments.last.trim, 100);
  });

  test('SheetLayout.cutSequence defaults to null (FFD mode)', () {
    const layout = SheetLayout(
      stockSheetId: 's1',
      placed: [],
      sheetLength: 2440,
      sheetWidth: 1220,
    );
    expect(layout.cutSequence, isNull);
  });
}
```

**Step 2: 테스트 실행해서 fail 확인**

Run: `flutter test test/domain/models/cutting_plan_test.dart`
Expected: FAIL — `Strip`/`Segment` 미정의, `cutSequence` 필드 없음.

**Step 3: 모델 추가**

`lib/domain/models/cutting_plan.dart` 끝에 추가:

```dart
/// strip-cut 모드 결과의 절단 순서 / 구조 정보.
/// FFD 모드에서는 SheetLayout.cutSequence = null.
class CutSequence {
  /// 풀컷 방향. true = 세로 풀컷이 stage 1.
  final bool verticalFirst;
  final List<Strip> strips;
  const CutSequence({required this.verticalFirst, required this.strips});
}

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

class Segment {
  /// strip 내부에서의 시작 좌표 (verticalFirst=true이면 y, false면 x).
  final double offset;
  /// segment 길이 (절단 방향과 평행).
  final double length;
  /// 이 segment에 들어간 부품(들).
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
```

`SheetLayout`에 `cutSequence` 필드 추가:

```dart
class SheetLayout {
  final String stockSheetId;
  final List<PlacedPart> placed;
  final double sheetLength;
  final double sheetWidth;
  final CutSequence? cutSequence;  // strip-cut 모드일 때만 채워짐.

  const SheetLayout({
    required this.stockSheetId,
    required this.placed,
    required this.sheetLength,
    required this.sheetWidth,
    this.cutSequence,
  });

  // … 기존 usedPercent 그대로
}
```

**Step 4: 테스트 PASS 확인 + 회귀 테스트**

Run: `flutter test`
Expected: PASS — 기존 `FFDSolver`는 `cutSequence`를 안 넘기므로 default `null`.

**Step 5: Commit (사용자 승인 후)**

제안: `feat(domain): add Strip/Segment/CutSequence output models`

---

## Phase 3 — Strip-Cut Solver

> @superpowers:test-driven-development 스킬 따를 것. 각 task는 작은 입력에 대한 명확한 expected output을 먼저 정의하고 테스트를 깬 다음 구현한다.

### Task 5: StripCutSolver scaffold + 빈 입력 smoke test

**Files:**
- Create: `lib/domain/solver/strip_cut_solver.dart`
- Test: `test/domain/solver/strip_cut_solver_test.dart` (new)

**Step 1: 실패 테스트 작성**

```dart
// test/domain/solver/strip_cut_solver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/solver/strip_cut_solver.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  group('StripCutSolver — scaffold', () {
    test('empty stocks → all parts unplaced, efficiency 0', () {
      final plan = StripCutSolver().solve(
        stocks: const [],
        parts: const [],
        kerf: 3,
        grainLocked: false,
        direction: StripDirection.verticalFirst,
        maxStages: 3,
        preferSameWidth: true,
        minimizeCuts: true,
        minimizeWaste: true,
      );
      expect(plan.sheets, isEmpty);
      expect(plan.unplaced, isEmpty);
      expect(plan.efficiencyPercent, 0);
    });
  });
}
```

**Step 2: 테스트 실행해서 fail 확인**

Run: `flutter test test/domain/solver/strip_cut_solver_test.dart`
Expected: FAIL — class 없음.

**Step 3: 최소 구현**

```dart
// lib/domain/solver/strip_cut_solver.dart
import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import '../models/solver_mode.dart';
import '../models/stock_sheet.dart';

/// n-stage guillotine strip cut. panel saw 호환.
class StripCutSolver {
  CuttingPlan solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
    required StripDirection direction,  // verticalFirst 또는 horizontalFirst만 받음
    required int maxStages,             // 2 / 3 / 4
    required bool preferSameWidth,
    required bool minimizeCuts,
    required bool minimizeWaste,
  }) {
    assert(direction != StripDirection.auto,
        'auto는 AutoRecommend가 처리. solver에 직접 못 넘김.');
    assert(maxStages >= 2 && maxStages <= 4);
    if (stocks.isEmpty || parts.isEmpty) {
      return const CuttingPlan(sheets: [], unplaced: [], efficiencyPercent: 0);
    }
    // TODO: 다음 task에서 구현
    throw UnimplementedError();
  }
}
```

**Step 4: PASS 확인**

Run: `flutter test test/domain/solver/strip_cut_solver_test.dart`
Expected: PASS (smoke test 한 개만).

**Step 5: Commit (사용자 승인 후)**

제안: `feat(solver): scaffold StripCutSolver class`

---

### Task 6: 3-stage vertical-first 기본 배치 (모든 토글 OFF)

**Files:**
- Modify: `lib/domain/solver/strip_cut_solver.dart`
- Modify: `test/domain/solver/strip_cut_solver_test.dart`

목표: 가장 단순한 케이스 — 부품 폭이 다양하더라도 **가장 큰 폭 먼저** 그리디로 strip을 만들어 채운다. 모든 토글 OFF로 동작.

**Step 1: 실패 테스트 작성**

```dart
group('StripCutSolver — 3-stage vertical-first basic', () {
  test('single sheet, two parts side-by-side fit one strip each', () {
    // 시트 1000 x 500. 부품 A: 400x200, B: 400x200 (둘 다 동일).
    // verticalFirst → strip 폭 = 부품 길이 (400), strip 길이 = 시트 폭 (500).
    final plan = StripCutSolver().solve(
      stocks: [
        const StockSheet(id: 's', length: 1000, width: 500, qty: 1, label: ''),
      ],
      parts: [
        const CutPart(id: 'a', length: 400, width: 200, qty: 2, label: 'A'),
      ],
      kerf: 0,  // 단순화
      grainLocked: true,
      direction: StripDirection.verticalFirst,
      maxStages: 3,
      preferSameWidth: false,
      minimizeCuts: false,
      minimizeWaste: false,
    );
    expect(plan.sheets.length, 1);
    expect(plan.unplaced, isEmpty);
    expect(plan.sheets.first.placed.length, 2);
    expect(plan.sheets.first.cutSequence, isNotNull);
    expect(plan.sheets.first.cutSequence!.verticalFirst, true);
    expect(plan.sheets.first.cutSequence!.strips.length, 1);
    expect(plan.sheets.first.cutSequence!.strips.first.segments.length, 2);
  });
});
```

**Step 2: 테스트 fail 확인**

Run: `flutter test test/domain/solver/strip_cut_solver_test.dart`
Expected: FAIL — UnimplementedError.

**Step 3: 구현**

`StripCutSolver.solve` 본문에서 `verticalFirst` 분기를 작성. 핵심 알고리즘:

```dart
// 의사코드 (Dart로 풀어서 작성):
// 1. 부품을 qty만큼 펼치기.
// 2. 부품을 길이(=verticalFirst의 strip 폭) 큰 순서로 정렬.
// 3. 시트 큐 펼치기.
// 4. 각 시트에 대해:
//    a. 사용 가능한 가로 잔여 = 시트 length. 시작 x = 0.
//    b. 정렬된 부품 큐를 순회하면서 First-Fit으로 strip을 만든다.
//       - 새 strip 폭 = 현재 부품의 length (가장 큰 길이).
//       - strip 안에서 그 폭에 fit하는 부품들(width <= 시트 width)을 segment로 stack.
//       - segment 채우기는 First-Fit Decreasing on 부품 width.
//    c. 더 이상 strip 만들 가로 공간 없으면 다음 시트.
// 5. 모든 시트 소진 후 못 넣은 부품 → unplaced.
```

테스트가 통과하는 만큼만 구현 (먼저는 한 strip 안에 같은 폭 부품들 채우기 + cutSequence 기록). `kerf` 적용도 포함. `grainLocked`로 회전 가능 여부 결정.

작성 시 helper 분리:
- `List<CutPart> _expand(parts)` — qty 펼치기.
- `_StripBuild _buildStrip(remainingParts, stripWidth, stripLength, kerf)` — 한 strip 안에 segment FFD.

**Step 4: 테스트 PASS 확인**

Run: `flutter test test/domain/solver/strip_cut_solver_test.dart`
Expected: PASS.

**Step 5: Commit (사용자 승인 후)**

제안: `feat(solver): StripCutSolver vertical-first 3-stage greedy`

---

### Task 7: 3-stage horizontal-first 추가

**Files:**
- Modify: `lib/domain/solver/strip_cut_solver.dart`
- Modify: `test/domain/solver/strip_cut_solver_test.dart`

원리는 vertical-first의 좌표축 swap. 코드에서는 `direction == verticalFirst`인지 확인해서 동일 helper에 length/width를 swap해서 호출하는 식으로 구현.

**Step 1: 실패 테스트 작성**

```dart
test('horizontal-first mirrors vertical-first when sheet/parts swapped', () {
  // verticalFirst로 (1000x500) + (400x200) → 잘 됨.
  // horizontalFirst로 (500x1000) + (200x400) → 동일한 결과 구조.
  final h = StripCutSolver().solve(
    stocks: [
      const StockSheet(id: 's', length: 500, width: 1000, qty: 1, label: ''),
    ],
    parts: [
      const CutPart(id: 'a', length: 200, width: 400, qty: 2, label: 'A'),
    ],
    kerf: 0,
    grainLocked: true,
    direction: StripDirection.horizontalFirst,
    maxStages: 3,
    preferSameWidth: false,
    minimizeCuts: false,
    minimizeWaste: false,
  );
  expect(h.sheets.length, 1);
  expect(h.unplaced, isEmpty);
  expect(h.sheets.first.cutSequence!.verticalFirst, false);
});
```

**Step 2: fail 확인 → 3: 구현 (axis swap) → 4: PASS → 5: commit**

제안 메시지: `feat(solver): StripCutSolver horizontal-first via axis swap`

---

### Task 8: `preferSameWidth = true` 동작

**Files:** 동일 두 파일.

`preferSameWidth = true`이면 strip을 만들 때 *완전히 같은 폭의 부품들*만 한 strip에 묶어 trim 자투리를 0으로 만듦. 폭이 다르면 별도 strip. `false`이면 가장 넓은 부품의 폭으로 strip을 잡고 좁은 부품도 함께 넣음 (자투리 발생).

**Step 1: 실패 테스트 작성**

부품 두 종류 (폭 다름) — `preferSameWidth=true`이면 strip 2개, `false`이면 strip 1개로 합쳐지는 케이스.

**Step 2-5:** TDD 사이클.

제안 commit: `feat(solver): preferSameWidth toggle in StripCutSolver`

---

### Task 9: `minimizeCuts = true` 동작 (Best-Fit Decreasing)

**Files:** 동일.

ON이면 segment 채우기를 Best-Fit Decreasing으로 — 한 strip에 더 많은 부품이 들어가서 결과적으로 strip 수가 줄어든다. OFF는 First-Fit.

**Step 1:** test — 같은 입력에 대해 ON/OFF의 strip 수 차이를 보장.
**Step 2-5:** TDD 사이클.

제안: `feat(solver): minimizeCuts toggle (BFD vs FF)`

---

### Task 10: `minimizeWaste = true` post-processing

**Files:** 동일.

ON이면 풀이 끝난 뒤 unplaced의 작은 부품을 마지막 strip 자투리에 끼워넣는 1-pass local search.

**Step 1:** test — unplaced 1개 + 마지막 strip에 빈 공간 있는 케이스 → ON이면 unplaced 0, OFF면 unplaced 1.
**Step 2-5:** TDD 사이클.

제안: `feat(solver): minimizeWaste post-processing pass`

---

### Task 11: `maxStages = 2` (exact mode)

**Files:** 동일.

`maxStages == 2`이면 Stage 3 (segment 내부 trim) 금지 → 부품 width가 strip width와 *정확히* 일치해야만 배치 가능. 안 맞으면 unplaced.

**Step 1:** test — width가 살짝 어긋난 부품이 maxStages=2이면 unplaced, =3이면 placed.
**Step 2-5:** TDD 사이클.

제안: `feat(solver): maxStages=2 exact mode`

---

### Task 12: `maxStages = 4` (extra trim)

**Files:** 동일.

`maxStages == 4`이면 segment 끝의 trim 자투리에 작은 부품을 한 번 더 trim해서 끼워넣는 단계 추가. `minimizeWaste`와는 별개로, **trim의 trim**까지 허용한다는 의미.

**Step 1:** test — 4-stage에서만 들어가는 부품 1개를 만든 케이스.
**Step 2-5:** TDD 사이클.

제안: `feat(solver): maxStages=4 nested trim`

---

## Phase 4 — Auto-Recommend

### Task 13: AutoRecommend 래퍼

**Files:**
- Create: `lib/domain/solver/auto_recommend.dart`
- Test: `test/domain/solver/auto_recommend_test.dart`

목표: 두 방향 모두 풀고 metric으로 비교, 결과에 비교 정보 (`runnerUp` + 두 metric)를 함께 담아서 UI가 chip으로 보여줄 수 있게.

**Step 1: 실패 테스트 작성**

```dart
test('AutoRecommend picks lower waste when minimizeWaste=true', () {
  // 한쪽이 명백히 더 나은 입력을 만들어서 결과 검증.
  final result = AutoRecommend().solve(
    stocks: …,
    parts: …,
    kerf: …,
    grainLocked: …,
    maxStages: 3,
    preferSameWidth: true,
    minimizeCuts: true,
    minimizeWaste: true,
  );
  expect(result.winner, StripDirection.verticalFirst);
  expect(result.plan.efficiencyPercent, greaterThan(result.runnerUp.efficiencyPercent));
});
```

**Step 2-3: AutoRecommend 구현**

```dart
class AutoRecommendResult {
  final CuttingPlan plan;
  final StripDirection winner;
  /// 진 쪽 plan — UI chip에서 클릭 시 토글 표시용.
  final CuttingPlan runnerUp;
  final StripDirection runnerUpDirection;
  const AutoRecommendResult({
    required this.plan,
    required this.winner,
    required this.runnerUp,
    required this.runnerUpDirection,
  });
}

class AutoRecommend {
  AutoRecommendResult solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
    required int maxStages,
    required bool preferSameWidth,
    required bool minimizeCuts,
    required bool minimizeWaste,
  }) {
    final solver = StripCutSolver();
    final v = solver.solve(direction: StripDirection.verticalFirst, ...);
    final h = solver.solve(direction: StripDirection.horizontalFirst, ...);
    // tie-break:
    // 1) minimizeWaste ON → unplaced 면적 적은 쪽
    // 2) minimizeCuts ON → cut 수 적은 쪽
    // 3) 모두 OFF or 동률 → efficiency 높은 쪽
    final pick = _pick(v, h, minimizeWaste, minimizeCuts);
    return AutoRecommendResult(
      plan: pick == 'v' ? v : h,
      winner: pick == 'v' ? StripDirection.verticalFirst : StripDirection.horizontalFirst,
      runnerUp: pick == 'v' ? h : v,
      runnerUpDirection: pick == 'v' ? StripDirection.horizontalFirst : StripDirection.verticalFirst,
    );
  }
}
```

**Step 4-5: PASS + commit**

제안: `feat(solver): AutoRecommend wrapper with metric tie-break`

---

### Task 14: Auto-recommend short-circuit (빈 입력)

**Step 1:** test — `parts.isEmpty`이면 두 솔버를 호출하지 않고 빈 결과 반환 (런타임 절약).
**Step 2-5:** TDD 사이클.

제안: `perf(solver): AutoRecommend short-circuit on empty input`

---

## Phase 5 — Solver Dispatch + Provider

### Task 15: `solver_isolate.dart`에 mode dispatch

**Files:**
- Modify: `lib/domain/solver/solver_isolate.dart`
- Modify: `lib/ui/providers/solver_provider.dart`

`solveInIsolate`에 새 파라미터를 받아 `SolverMode`에 따라 분기:
- `ffd` → 기존 FFDSolver.
- `stripCut` + `direction != auto` → StripCutSolver.
- `stripCut` + `direction == auto` → AutoRecommend.

`runCalculate`도 새 필드를 project에서 읽어 전달.

**Step 1:** test — 기존 FFD 경로와 새 strip-cut 경로 둘 다 isolate를 통해 동작하는지. (이건 통합성 테스트 — 가능하면 `compute`를 우회해서 동기적으로 dispatch만 검증하거나, 아예 `solveInIsolate` wrapper 함수만 분리해서 테스트.)
**Step 2-5:** 구현.

추가로 `CuttingPlan`에 optional `runnerUp: CuttingPlan?`, `runnerUpDirection: StripDirection?` 필드를 둬서 자동 추천일 때 chip 표시 정보를 결과 객체로 전달. (또는 별도 `AppliedSolverResult` 래퍼.)

제안: `feat(solver): isolate dispatch by SolverMode`

---

### Task 16: `tabs_provider`에 새 필드 update 메서드 6개

**Files:**
- Modify: `lib/ui/providers/tabs_provider.dart` (line ~225 부근, 기존 update 패턴 옆)

기존 `updateKerf` 패턴 그대로 6개 추가:

```dart
void updateSolverMode(String id, SolverMode v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(solverMode: v)));

void updateStripDirection(String id, StripDirection v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(stripDirection: v)));

void updateMaxStages(String id, int v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(maxStages: v)));

void updatePreferSameWidth(String id, bool v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(preferSameWidth: v)));

void updateMinimizeCuts(String id, bool v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(minimizeCuts: v)));

void updateMinimizeWaste(String id, bool v) => _patch(
    id, (t) => t.copyWith(project: t.project.copyWith(minimizeWaste: v)));
```

**Step 1:** Provider unit test — 각 update가 active project field를 바꾸고 isDirty를 true로 만든다.
**Step 2-5:** 구현.

제안: `feat(provider): update methods for strip-cut fields`

---

## Phase 6 — UI

### Task 17: 절단 옵션 collapsible section + SolverMode radio

**Files:**
- Create: `lib/ui/widgets/cut_options_section.dart`
- Modify: `lib/ui/widgets/left_pane.dart` (OptionsSection 아래에 새 섹션 삽입)

`ExpansionTile`로 collapsible. 헤더 라벨: "절단 옵션". 안에 SolverMode 라디오 두 개:

```dart
RadioListTile<SolverMode>(
  title: const Text('FFD (자유 배치 — 최대 효율)'),
  value: SolverMode.ffd,
  groupValue: p.solverMode,
  onChanged: (v) => notifier.updateSolverMode(activeId, v!),
),
RadioListTile<SolverMode>(
  title: const Text('Strip-cut (panel saw — 실제 작업 가능)'),
  value: SolverMode.stripCut,
  groupValue: p.solverMode,
  onChanged: (v) => notifier.updateSolverMode(activeId, v!),
),
```

solverMode가 stripCut일 때만 그 아래에 placeholder `Text('TODO: strip-cut options')` 노출 (다음 task에서 채움).

**Step 1: widget test** — 라디오 클릭 → provider 메서드 호출 검증.
**Step 2-5:** 구현.

제안: `feat(ui): collapsible CutOptionsSection with SolverMode radio`

---

### Task 18: StripDirection 라디오 + maxStages 드롭다운

**Files:** `cut_options_section.dart`만 수정.

solverMode == stripCut일 때:

```dart
// 절단 방식
RadioListTile<StripDirection>(title: Text('세로 풀컷 → 가로 분할'), value: verticalFirst, …),
RadioListTile<StripDirection>(title: Text('가로 풀컷 → 세로 분할'), value: horizontalFirst, …),
RadioListTile<StripDirection>(title: Text('자동 추천'), value: auto, …),

// 최대 절단 단계
Row(children: [
  const Expanded(child: Text('최대 절단 단계')),
  DropdownButton<int>(
    value: p.maxStages,
    items: const [
      DropdownMenuItem(value: 2, child: Text('2')),
      DropdownMenuItem(value: 3, child: Text('3')),
      DropdownMenuItem(value: 4, child: Text('4')),
    ],
    onChanged: (v) => notifier.updateMaxStages(activeId, v!),
  ),
]),
```

**Step 1-5:** TDD widget test.

제안: `feat(ui): StripDirection radios + maxStages dropdown`

---

### Task 19: 세 체크박스 토글

**Files:** `cut_options_section.dart`만.

```dart
CheckboxListTile(
  title: const Text('동일 폭 우선'),
  value: p.preferSameWidth,
  onChanged: (v) => notifier.updatePreferSameWidth(activeId, v ?? true),
),
// 절단 횟수 최소
// 손실률 최소
```

**Step 1-5:** TDD.

제안: `feat(ui): three priority checkboxes in CutOptionsSection`

---

### Task 20: 자동 추천일 때 결과 비교 chip

**Files:**
- Modify: `lib/ui/widgets/cutting_result_pane.dart` (또는 결과 헤더 위젯)

자동 추천 결과면 chip 두 개를 결과 패널 상단에 표시. 클릭 시 도면을 runner-up 결과로 toggle.

```
[ ✓ 세로 풀컷 — 효율 91.2%, 절단 7회 ]   [ 가로 풀컷 — 효율 87.5%, 절단 9회 ]
```

state는 `cuttingPlanProvider`와 별개로 "지금 보고 있는 plan은 winner냐 runner-up이냐" 토글 state 추가 (`StateProvider<bool> showRunnerUpProvider`).

**Step 1-5:** TDD widget test.

제안: `feat(ui): auto-recommend comparison chips with toggle`

---

### Task 21: Edge case 경고 (모든 토글 OFF, maxStages 부족)

**Files:** `cutting_result_pane.dart` (혹은 별도 banner 위젯).

조건별 경고:
- strip-cut 모드 + 세 토글 모두 OFF → "최소 한 개 우선순위를 선택하세요" banner.
- strip-cut 모드 + unplaced > 0 + `maxStages < 4` → "최대 절단 단계를 늘리거나 동일 폭 우선을 끄면 더 많이 배치됩니다" 힌트.

**Step 1-5:** TDD widget test로 각 조건에서 banner가 보이는지 검증.

제안: `feat(ui): strip-cut edge case warnings in result pane`

---

## Phase 7 — 최종 검증

### Task 22: 통합 회귀 테스트

**Files:**
- Test: `test/integration/strip_cut_smoke_test.dart` (new, 가능하면)

**Step 1:** 실제 합판 fixture (2440x1220 + 부품 5종) 입력 → strip-cut 결과의 형식이 망가지지 않았는지 + FFD와 strip-cut 모드 둘 다 정상 plan 반환하는지.

Run: `flutter test`
Expected: 모든 테스트 PASS.

**Step 2: 수동 smoke**

Run: `flutter run -d macos`
- 새 프로젝트 → 합판 + 부품 입력 → 자동 계산 결과 확인 (FFD).
- 절단 옵션 펼치고 Strip-cut 모드로 전환 → 도면이 strip 패턴으로 바뀌는지.
- 자동 추천 모드 → 비교 chip 두 개 보이는지, runner-up 클릭 시 도면 토글되는지.
- 저장 → 닫기 → 다시 열기 → 새 옵션 필드들이 유지되는지.

**Step 3: Commit (사용자 승인 후)**

제안: `test: strip-cut integration smoke + manual verification`

---

## 완료 후

- @superpowers:requesting-code-review 로 review 요청.
- 회귀 테스트 통과 + 수동 smoke 통과 후 PR 작성.
- 사용자 명시적 승인 시에만 push/PR.
