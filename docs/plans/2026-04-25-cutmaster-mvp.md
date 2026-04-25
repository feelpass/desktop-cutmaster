# Cutmaster MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 합판(plywood) 재단 최적화 데스크톱 앱의 narrowest version을 ship한다. 좌측 입력 패널 + 우측 시각화의 단일 화면 레이아웃, 한국어 UI, 자체 구현 2D guillotine + FFD 솔버. yp 본인과 가구공장 친구가 직접 사용.

**Architecture:** Flutter Desktop (macOS + Windows). 단일 MainScreen with split layout (LeftPane 380dp + RightPane flex). 상태 관리 Riverpod, 영속성 sqflite_common_ffi. 솔버는 Isolate 분리로 UI freeze 방지. 한국어 ARB 분리로 i18n 구조 준비. 시각 디자인 cutlistoptimizer.com 패턴 채용.

**Tech Stack:**
- Flutter 3.24+ / Dart 3.5+
- Riverpod 2.5+ (상태 + DI)
- sqflite_common_ffi 2.3+ (데스크톱 SQLite)
- intl + flutter_localizations (한국어 ARB)
- path_provider, file_picker (저장 경로)
- flutter_test, integration_test (테스트)

**Reference docs (read before starting):**
- Design doc: `~/.gstack/projects/feelpass-claude-coco/youngpillee-main-design-20260425-161527.md`
- Test plan: `~/.gstack/projects/feelpass-claude-coco/youngpillee-main-eng-review-test-plan-20260425-161527.md`
- Visual reference: `~/workspace/coco/.playwright-mcp/cutlistoptimizer-viewport.png`

---

## Phase 1: 프로젝트 셋업

### Task 1: Flutter 프로젝트 생성

**Files:**
- Create: `~/workspace/desktop/cutmaster/` (Flutter project root)

**Step 1: 프로젝트 생성**

```bash
cd ~/workspace/desktop
flutter create cutmaster --platforms=macos,windows --org com.coco.cutmaster --project-name cutmaster
```

Expected: `cutmaster/` 생성, `lib/main.dart`, `pubspec.yaml`, `macos/`, `windows/` 자동 생성.

**Step 2: 동작 확인**

```bash
cd ~/workspace/desktop/cutmaster
flutter run -d macos
```

Expected: 기본 Flutter 카운터 앱이 macOS 윈도우로 뜸.

**Step 3: docs/plans 보존 + git 초기화**

```bash
cp -r docs ./.docs-backup  # cutmaster/docs는 flutter create로 덮어쓰기 가능, 백업
flutter create cutmaster --platforms=macos,windows  # idempotent
mv ./.docs-backup/* docs/  # 복원
rm -rf ./.docs-backup
git init
git add -A
git commit -m "chore: flutter create cutmaster (macos+windows)"
```

**Step 4: .gitignore 보강**

`.gitignore`에 추가:
```
# IDE
.idea/
.vscode/
*.iml

# macOS
.DS_Store

# Build artifacts
build/
*.dmg
*.msi

# gstack design refs (local only)
.playwright-mcp/
```

```bash
git add .gitignore
git commit -m "chore: harden .gitignore"
```

### Task 2: 의존성 추가

**Files:**
- Modify: `pubspec.yaml`

**Step 1: pubspec.yaml에 의존성 추가**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  sqflite_common_ffi: ^2.3.3
  path_provider: ^2.1.4
  path: ^1.9.0
  file_picker: ^8.0.6
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.13

flutter:
  uses-material-design: true
  generate: true  # for l10n
```

**Step 2: 설치**

```bash
flutter pub get
```

Expected: 의존성 다운로드, `.dart_tool/` 생성.

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add riverpod, sqflite_common_ffi, intl, file_picker"
```

### Task 3: 테마 (시각 토큰)

**Files:**
- Create: `lib/ui/theme/app_colors.dart`
- Create: `lib/ui/theme/app_text_styles.dart`
- Create: `lib/ui/theme/app_theme.dart`

**Step 1: app_colors.dart 작성**

design doc의 시각 토큰 그대로:

```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const primary = Color(0xFF16A34A);          // 녹색 (계산 CTA, 효율)
  static const header = Color(0xFF1F2C3A);           // 다크 네이비 TopBar
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F5F7);          // 좌측 패널
  static const border = Color(0xFFE5E5E5);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const textOnHeader = Color(0xFFFFFFFF);
  static const sectionHeaderBg = Color(0xFFECECEE);
}
```

**Step 2: app_text_styles.dart 작성**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();
  static const topBarTitle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textOnHeader);
  static const sectionHeader = TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A5562));
  static const tableHeader = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5562));
  static const tableCell = TextStyle(fontSize: 13, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 13, color: AppColors.textPrimary);
  static const efficiencyNumber = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary);
}
```

**Step 3: app_theme.dart 작성**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
    ),
  );
}
```

**Step 4: main.dart 적용**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: CutmasterApp()));
}

class CutmasterApp extends StatelessWidget {
  const CutmasterApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cutmaster',
      theme: AppTheme.light(),
      home: const Placeholder(),  // Task 21에서 MainScreen으로 교체
    );
  }
}
```

**Step 5: 빌드 확인**

```bash
flutter run -d macos
```

Expected: 빈 Placeholder 윈도우 뜸, 에러 없음.

**Step 6: Commit**

```bash
git add lib/
git commit -m "feat(ui): add theme tokens (colors, text styles, app theme)"
```

### Task 4: l10n (한국어 ARB)

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_ko.arb`
- Create: `lib/l10n/app_en.arb` (구조 준비, 영어 번역은 follow-up)
- Modify: `lib/main.dart`

**Step 1: l10n.yaml**

```yaml
arb-dir: lib/l10n
template-arb-file: app_ko.arb
output-localization-file: app_localizations.dart
```

**Step 2: app_ko.arb**

```json
{
  "@@locale": "ko",
  "appTitle": "합판 재단",
  "calculate": "계산",
  "save": "저장",
  "settings": "설정",
  "newProject": "새 프로젝트",
  "parts": "부품",
  "stockSheets": "자재",
  "options": "옵션",
  "kerf": "톱날 두께(mm)",
  "lockGrain": "결방향 고정",
  "showPartLabels": "부품 라벨 표시",
  "useSingleSheet": "단일 시트 사용",
  "emptyResultTitle": "자재와 부품을 입력하고",
  "emptyResultAction": "▶ 계산 버튼을 눌러주세요",
  "length": "가로",
  "width": "세로",
  "qty": "수량",
  "label": "라벨",
  "preset": "프리셋",
  "efficiency": "효율",
  "sheetUsed": "{n}장 사용",
  "@sheetUsed": {"placeholders": {"n": {"type": "int"}}},
  "unplaced": "미배치",
  "exportPng": "PNG 내보내기",
  "materialUpdatedTitle": "자재가 변경되었습니다",
  "materialUpdatedBody": "이 프로젝트도 변경된 자재로 다시 계산할까요?",
  "yes": "예",
  "no": "아니오"
}
```

**Step 3: app_en.arb (placeholder)**

```json
{
  "@@locale": "en",
  "appTitle": "Cutmaster"
}
```

**Step 4: main.dart에 localization 연결**

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

// MaterialApp에 추가:
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
locale: const Locale('ko'),
```

**Step 5: 생성 확인**

```bash
flutter gen-l10n
flutter run -d macos
```

Expected: `lib/l10n/app_localizations.dart` 자동 생성, 빌드 성공.

**Step 6: Commit**

```bash
git add l10n.yaml lib/l10n/ lib/main.dart
git commit -m "feat(l10n): add Korean ARB + l10n setup"
```

---

## Phase 2: 도메인 모델 (TDD)

### Task 5: StockSheet, CutPart, Project 모델

**Files:**
- Create: `lib/domain/models/stock_sheet.dart`
- Create: `lib/domain/models/cut_part.dart`
- Create: `lib/domain/models/project.dart`
- Create: `lib/domain/models/cutting_plan.dart`
- Create: `test/domain/models/models_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/domain/models/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/project.dart';

void main() {
  test('StockSheet equality and copyWith', () {
    const a = StockSheet(id: '1', length: 2440, width: 1220, qty: 5, label: '12T');
    final b = a.copyWith(qty: 3);
    expect(b.qty, 3);
    expect(b.length, 2440);
    expect(a == b, false);
  });

  test('CutPart toJson roundtrip', () {
    const p = CutPart(id: 'p1', length: 600, width: 400, qty: 4, label: '문짝', grainDirection: GrainDirection.lengthwise);
    final json = p.toJson();
    final p2 = CutPart.fromJson(json);
    expect(p2, p);
  });

  test('Project default options', () {
    final proj = Project.create(id: 'proj1', name: '테스트');
    expect(proj.kerf, 3);
    expect(proj.grainLocked, false);
    expect(proj.parts, isEmpty);
    expect(proj.stocks, isEmpty);
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/domain/models/models_test.dart
```

Expected: 컴파일 에러 (모델 없음).

**Step 3: 모델 구현**

`lib/domain/models/stock_sheet.dart`:

```dart
class StockSheet {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final GrainDirection grainDirection;

  const StockSheet({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
  });

  StockSheet copyWith({String? id, double? length, double? width, int? qty, String? label, GrainDirection? grainDirection}) =>
      StockSheet(
        id: id ?? this.id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        grainDirection: grainDirection ?? this.grainDirection,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'length': length, 'width': width, 'qty': qty,
        'label': label, 'grain': grainDirection.name,
      };

  factory StockSheet.fromJson(Map<String, dynamic> j) => StockSheet(
        id: j['id'], length: (j['length'] as num).toDouble(), width: (j['width'] as num).toDouble(),
        qty: j['qty'], label: j['label'] ?? '',
        grainDirection: GrainDirection.values.byName(j['grain'] ?? 'none'),
      );

  @override
  bool operator ==(Object o) => o is StockSheet && o.id == id && o.length == length && o.width == width && o.qty == qty && o.label == label && o.grainDirection == grainDirection;
  @override
  int get hashCode => Object.hash(id, length, width, qty, label, grainDirection);
}

enum GrainDirection { none, lengthwise, widthwise }
```

`lib/domain/models/cut_part.dart`:

```dart
import 'stock_sheet.dart' show GrainDirection;

class CutPart {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final GrainDirection grainDirection;

  const CutPart({
    required this.id, required this.length, required this.width, required this.qty,
    this.label = '', this.grainDirection = GrainDirection.none,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'length': length, 'width': width, 'qty': qty,
        'label': label, 'grain': grainDirection.name,
      };

  factory CutPart.fromJson(Map<String, dynamic> j) => CutPart(
        id: j['id'], length: (j['length'] as num).toDouble(), width: (j['width'] as num).toDouble(),
        qty: j['qty'], label: j['label'] ?? '',
        grainDirection: GrainDirection.values.byName(j['grain'] ?? 'none'),
      );

  @override
  bool operator ==(Object o) => o is CutPart && o.id == id && o.length == length && o.width == width && o.qty == qty && o.label == label && o.grainDirection == grainDirection;
  @override
  int get hashCode => Object.hash(id, length, width, qty, label, grainDirection);
}
```

`lib/domain/models/project.dart`:

```dart
import 'stock_sheet.dart';
import 'cut_part.dart';

class Project {
  final String id;
  final String name;
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf;
  final bool grainLocked;
  final bool showPartLabels;
  final bool useSingleSheet;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id, required this.name,
    this.stocks = const [], this.parts = const [],
    this.kerf = 3, this.grainLocked = false,
    this.showPartLabels = true, this.useSingleSheet = false,
    required this.createdAt, required this.updatedAt,
  });

  factory Project.create({required String id, required String name}) {
    final now = DateTime.now();
    return Project(id: id, name: name, createdAt: now, updatedAt: now);
  }

  Project copyWith({
    String? name, List<StockSheet>? stocks, List<CutPart>? parts,
    double? kerf, bool? grainLocked, bool? showPartLabels, bool? useSingleSheet,
  }) => Project(
        id: id, name: name ?? this.name,
        stocks: stocks ?? this.stocks, parts: parts ?? this.parts,
        kerf: kerf ?? this.kerf, grainLocked: grainLocked ?? this.grainLocked,
        showPartLabels: showPartLabels ?? this.showPartLabels,
        useSingleSheet: useSingleSheet ?? this.useSingleSheet,
        createdAt: createdAt, updatedAt: DateTime.now(),
      );
}
```

`lib/domain/models/cutting_plan.dart`:

```dart
import 'cut_part.dart';

class CuttingPlan {
  final List<SheetLayout> sheets;
  final List<CutPart> unplaced;
  final double efficiencyPercent;

  const CuttingPlan({required this.sheets, required this.unplaced, required this.efficiencyPercent});
}

class SheetLayout {
  final String stockSheetId;
  final List<PlacedPart> placed;
  final double sheetLength;
  final double sheetWidth;

  const SheetLayout({
    required this.stockSheetId, required this.placed,
    required this.sheetLength, required this.sheetWidth,
  });
}

class PlacedPart {
  final CutPart part;
  final double x;
  final double y;
  final bool rotated;

  const PlacedPart({required this.part, required this.x, required this.y, this.rotated = false});
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/domain/models/models_test.dart
```

Expected: PASS (3 tests).

**Step 5: Commit**

```bash
git add lib/domain/models/ test/domain/models/
git commit -m "feat(domain): add StockSheet, CutPart, Project, CuttingPlan models with tests"
```

---

## Phase 3: 솔버 (TDD - 핵심)

### Task 6: 솔버 테스트 1 — 정상 입력

**Files:**
- Create: `lib/domain/solver/ffd_solver.dart`
- Create: `test/domain/solver/ffd_solver_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/domain/solver/ffd_solver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/solver/ffd_solver.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  test('정상 입력: 자재 1개 + 부품 5개 → 효율 90% 이상', () {
    const stocks = [StockSheet(id: 's1', length: 2440, width: 1220, qty: 1)];
    const parts = [
      CutPart(id: 'p1', length: 1200, width: 600, qty: 1, label: 'A'),
      CutPart(id: 'p2', length: 1200, width: 600, qty: 1, label: 'B'),
      CutPart(id: 'p3', length: 1200, width: 600, qty: 1, label: 'C'),
      CutPart(id: 'p4', length: 1200, width: 600, qty: 1, label: 'D'),
      CutPart(id: 'p5', length: 600, width: 400, qty: 1, label: 'E'),
    ];
    final plan = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: false);
    expect(plan.unplaced, isEmpty);
    expect(plan.efficiencyPercent, greaterThanOrEqualTo(90));
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/domain/solver/ffd_solver_test.dart
```

Expected: 컴파일 에러 (FFDSolver 없음).

**Step 3: FFDSolver 최소 구현**

`lib/domain/solver/ffd_solver.dart`:

```dart
import '../models/stock_sheet.dart';
import '../models/cut_part.dart';
import '../models/cutting_plan.dart';

class FFDSolver {
  CuttingPlan solve({
    required List<StockSheet> stocks,
    required List<CutPart> parts,
    required double kerf,
    required bool grainLocked,
  }) {
    // 부품을 면적 큰 순서로 expand (qty 만큼)
    final expandedParts = <CutPart>[];
    for (final p in parts) {
      for (int i = 0; i < p.qty; i++) {
        expandedParts.add(p);
      }
    }
    expandedParts.sort((a, b) => (b.length * b.width).compareTo(a.length * a.width));

    final sheets = <SheetLayout>[];
    final unplaced = <CutPart>[];
    final stockQueue = <StockSheet>[];
    for (final s in stocks) {
      for (int i = 0; i < s.qty; i++) {
        stockQueue.add(s);
      }
    }

    int stockIdx = 0;
    var currentSheet = stockQueue.isEmpty ? null : stockQueue[stockIdx];
    var freeRects = currentSheet == null ? <_Rect>[] : [_Rect(0, 0, currentSheet.length, currentSheet.width)];
    var placed = <PlacedPart>[];
    double usedArea = 0;
    double totalSheetArea = 0;

    for (final part in expandedParts) {
      final fit = _findFit(freeRects, part, kerf, grainLocked);
      if (fit != null) {
        placed.add(PlacedPart(part: part, x: fit.x, y: fit.y, rotated: fit.rotated));
        usedArea += part.length * part.width;
        freeRects = _splitRects(freeRects, fit, part, kerf);
      } else {
        // 시트 가득 → 다음 시트
        if (currentSheet != null) {
          sheets.add(SheetLayout(stockSheetId: currentSheet.id, placed: placed, sheetLength: currentSheet.length, sheetWidth: currentSheet.width));
          totalSheetArea += currentSheet.length * currentSheet.width;
        }
        stockIdx++;
        if (stockIdx >= stockQueue.length) {
          unplaced.add(part);
          continue;
        }
        currentSheet = stockQueue[stockIdx];
        freeRects = [_Rect(0, 0, currentSheet.length, currentSheet.width)];
        placed = [];
        final retry = _findFit(freeRects, part, kerf, grainLocked);
        if (retry != null) {
          placed.add(PlacedPart(part: part, x: retry.x, y: retry.y, rotated: retry.rotated));
          usedArea += part.length * part.width;
          freeRects = _splitRects(freeRects, retry, part, kerf);
        } else {
          unplaced.add(part);
        }
      }
    }

    if (currentSheet != null && placed.isNotEmpty) {
      sheets.add(SheetLayout(stockSheetId: currentSheet.id, placed: placed, sheetLength: currentSheet.length, sheetWidth: currentSheet.width));
      totalSheetArea += currentSheet.length * currentSheet.width;
    }

    final efficiency = totalSheetArea == 0 ? 0.0 : (usedArea / totalSheetArea) * 100;
    return CuttingPlan(sheets: sheets, unplaced: unplaced, efficiencyPercent: efficiency);
  }

  _Fit? _findFit(List<_Rect> rects, CutPart part, double kerf, bool grainLocked) {
    for (final r in rects) {
      // 정방향
      if (part.length <= r.w && part.width <= r.h) {
        return _Fit(x: r.x, y: r.y, rotated: false);
      }
      // 회전
      if (!grainLocked && part.width <= r.w && part.length <= r.h) {
        return _Fit(x: r.x, y: r.y, rotated: true);
      }
    }
    return null;
  }

  List<_Rect> _splitRects(List<_Rect> rects, _Fit fit, CutPart part, double kerf) {
    final pl = fit.rotated ? part.width : part.length;
    final pw = fit.rotated ? part.length : part.width;
    final result = <_Rect>[];
    for (final r in rects) {
      if (r.x == fit.x && r.y == fit.y) {
        // guillotine: split into right + bottom
        if (r.w - pl - kerf > 0) {
          result.add(_Rect(r.x + pl + kerf, r.y, r.w - pl - kerf, pw));
        }
        if (r.h - pw - kerf > 0) {
          result.add(_Rect(r.x, r.y + pw + kerf, r.w, r.h - pw - kerf));
        }
      } else {
        result.add(r);
      }
    }
    return result;
  }
}

class _Rect {
  final double x, y, w, h;
  _Rect(this.x, this.y, this.w, this.h);
}

class _Fit {
  final double x, y;
  final bool rotated;
  _Fit({required this.x, required this.y, required this.rotated});
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/domain/solver/ffd_solver_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/domain/solver/ test/domain/solver/
git commit -m "feat(solver): FFD 2D guillotine solver with first happy path test"
```

### Task 7: 솔버 테스트 2-8 — Edge cases

각 테스트는 작은 step. 같은 파일에 추가.

**Step 1: 빈 자재 테스트**

`test/domain/solver/ffd_solver_test.dart`에 추가:

```dart
test('빈 자재: stocks=[] → unplaced=parts 전체', () {
  const parts = [CutPart(id: 'p1', length: 100, width: 100, qty: 3)];
  final plan = FFDSolver().solve(stocks: [], parts: parts, kerf: 0, grainLocked: false);
  expect(plan.unplaced.length, 3);
  expect(plan.sheets, isEmpty);
});
```

**Step 2: 빈 부품**

```dart
test('빈 부품: parts=[] → 빈 결과', () {
  const stocks = [StockSheet(id: 's1', length: 2440, width: 1220, qty: 1)];
  final plan = FFDSolver().solve(stocks: stocks, parts: [], kerf: 0, grainLocked: false);
  expect(plan.sheets, isEmpty);
  expect(plan.unplaced, isEmpty);
});
```

**Step 3: 오버사이즈 부품**

```dart
test('오버사이즈: 부품 > 시트 → unplaced 분리', () {
  const stocks = [StockSheet(id: 's1', length: 1000, width: 500, qty: 1)];
  const parts = [
    CutPart(id: 'p1', length: 500, width: 400, qty: 1),  // 들어감
    CutPart(id: 'p2', length: 2000, width: 1000, qty: 1),  // 너무 큼
  ];
  final plan = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: false);
  expect(plan.unplaced.length, 1);
  expect(plan.unplaced.first.id, 'p2');
});
```

**Step 4: 결방향 ON + 회전 강제**

```dart
test('결방향 ON: 회전해야 들어가는 부품 → unplaced', () {
  const stocks = [StockSheet(id: 's1', length: 1000, width: 100, qty: 1)];
  const parts = [
    CutPart(id: 'p1', length: 50, width: 200, qty: 1),  // 회전 시 50x200 → 200x50, 시트 100 width 안 들어감 (회전해도 안 됨, 사실 grainLocked로 회전 금지)
  ];
  final plan = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: true);
  expect(plan.unplaced.length, 1);
});
```

**Step 5: 결방향 OFF + 회전 활용**

```dart
test('결방향 OFF: 회전으로 더 많이 배치', () {
  const stocks = [StockSheet(id: 's1', length: 1000, width: 100, qty: 1)];
  const parts = [
    CutPart(id: 'p1', length: 50, width: 100, qty: 5),  // 회전 안 해도 들어감
  ];
  final plan = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: false);
  expect(plan.unplaced, isEmpty);
});
```

**Step 6: kerf 반영**

```dart
test('kerf: kerf=0 vs kerf=10 결과 다름', () {
  const stocks = [StockSheet(id: 's1', length: 1000, width: 100, qty: 1)];
  const parts = [CutPart(id: 'p1', length: 200, width: 100, qty: 5)];
  final p0 = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: false);
  final p10 = FFDSolver().solve(stocks: stocks, parts: parts, kerf: 10, grainLocked: false);
  expect(p0.unplaced.length <= p10.unplaced.length, true);
});
```

**Step 7: 결정성**

```dart
test('결정성: 같은 입력 5회 → 동일 결과', () {
  const stocks = [StockSheet(id: 's1', length: 2440, width: 1220, qty: 1)];
  const parts = [
    CutPart(id: 'p1', length: 600, width: 400, qty: 4),
    CutPart(id: 'p2', length: 300, width: 200, qty: 2),
  ];
  final results = List.generate(5, (_) => FFDSolver().solve(stocks: stocks, parts: parts, kerf: 0, grainLocked: false));
  for (int i = 1; i < 5; i++) {
    expect(results[i].efficiencyPercent, results[0].efficiencyPercent);
    expect(results[i].unplaced.length, results[0].unplaced.length);
  }
});
```

**Step 8: 모든 솔버 테스트 통과 확인**

```bash
flutter test test/domain/solver/
```

Expected: 7 tests PASS.

**Step 9: Commit**

```bash
git add test/domain/solver/
git commit -m "test(solver): edge cases (empty, oversized, grain, kerf, determinism)"
```

### Task 8: 솔버 Isolate 분리

**Files:**
- Modify: `lib/domain/solver/ffd_solver.dart`
- Create: `lib/domain/solver/solver_isolate.dart`

**Step 1: solver_isolate.dart**

```dart
import 'package:flutter/foundation.dart';
import '../models/stock_sheet.dart';
import '../models/cut_part.dart';
import '../models/cutting_plan.dart';
import 'ffd_solver.dart';

class _SolverInput {
  final List<StockSheet> stocks;
  final List<CutPart> parts;
  final double kerf;
  final bool grainLocked;
  _SolverInput(this.stocks, this.parts, this.kerf, this.grainLocked);
}

Future<CuttingPlan> solveInIsolate({
  required List<StockSheet> stocks,
  required List<CutPart> parts,
  required double kerf,
  required bool grainLocked,
}) {
  return compute(_solveSync, _SolverInput(stocks, parts, kerf, grainLocked));
}

CuttingPlan _solveSync(_SolverInput input) {
  return FFDSolver().solve(
    stocks: input.stocks, parts: input.parts,
    kerf: input.kerf, grainLocked: input.grainLocked,
  );
}
```

**Step 2: Commit**

```bash
git add lib/domain/solver/solver_isolate.dart
git commit -m "feat(solver): wrap FFDSolver in compute() for isolate execution"
```

---

## Phase 4: DB Layer

### Task 9: ProjectDb 스키마 + 마이그레이션

**Files:**
- Create: `lib/data/local/project_db.dart`
- Create: `test/data/local/project_db_test.dart`

**Step 1: 실패하는 테스트**

`test/data/local/project_db_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/local/project_db.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Project save → load roundtrip', () async {
    final db = await ProjectDb.openInMemory();
    final orig = Project.create(id: 'p1', name: '테스트').copyWith(
      stocks: [const StockSheet(id: 's1', length: 2440, width: 1220, qty: 1, label: '12T')],
      parts: [const CutPart(id: 'pa1', length: 600, width: 400, qty: 4, label: '문짝')],
      kerf: 5, grainLocked: true,
    );
    await db.upsertProject(orig);
    final loaded = await db.loadProject('p1');
    expect(loaded?.name, '테스트');
    expect(loaded?.stocks.length, 1);
    expect(loaded?.parts.length, 1);
    expect(loaded?.kerf, 5);
    expect(loaded?.grainLocked, true);
    await db.close();
  });
}
```

**Step 2: 테스트 실패 확인**

```bash
flutter test test/data/local/project_db_test.dart
```

Expected: 컴파일 에러.

**Step 3: ProjectDb 구현**

```dart
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../domain/models/project.dart';
import '../../domain/models/stock_sheet.dart';
import '../../domain/models/cut_part.dart';

class ProjectDb {
  final Database _db;
  ProjectDb._(this._db);

  static Future<ProjectDb> openInMemory() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
      version: 1, onCreate: _onCreate,
    ));
    return ProjectDb._(db);
  }

  static Future<ProjectDb> open(String path) async {
    final db = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(
      version: 1, onCreate: _onCreate, onUpgrade: _onUpgrade,
    ));
    return ProjectDb._(db);
  }

  static Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE project (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kerf REAL NOT NULL,
        grain_locked INTEGER NOT NULL,
        show_part_labels INTEGER NOT NULL,
        use_single_sheet INTEGER NOT NULL,
        stocks_json TEXT NOT NULL,
        parts_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_sheet_library (
        id TEXT PRIMARY KEY,
        length REAL NOT NULL,
        width REAL NOT NULL,
        qty INTEGER NOT NULL,
        label TEXT NOT NULL,
        grain TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // v2+ 마이그레이션은 여기에 추가
  }

  Future<void> upsertProject(Project p) async {
    await _db.insert('project', {
      'id': p.id, 'name': p.name, 'kerf': p.kerf,
      'grain_locked': p.grainLocked ? 1 : 0,
      'show_part_labels': p.showPartLabels ? 1 : 0,
      'use_single_sheet': p.useSingleSheet ? 1 : 0,
      'stocks_json': jsonEncode(p.stocks.map((s) => s.toJson()).toList()),
      'parts_json': jsonEncode(p.parts.map((c) => c.toJson()).toList()),
      'created_at': p.createdAt.toIso8601String(),
      'updated_at': p.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Project?> loadProject(String id) async {
    final rows = await _db.query('project', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Project(
      id: r['id'] as String, name: r['name'] as String,
      stocks: (jsonDecode(r['stocks_json'] as String) as List).map((j) => StockSheet.fromJson(j)).toList(),
      parts: (jsonDecode(r['parts_json'] as String) as List).map((j) => CutPart.fromJson(j)).toList(),
      kerf: (r['kerf'] as num).toDouble(),
      grainLocked: r['grain_locked'] == 1,
      showPartLabels: r['show_part_labels'] == 1,
      useSingleSheet: r['use_single_sheet'] == 1,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    );
  }

  Future<List<Project>> listProjects() async {
    final rows = await _db.query('project', orderBy: 'updated_at DESC');
    return rows.map((r) => Project(
      id: r['id'] as String, name: r['name'] as String,
      stocks: (jsonDecode(r['stocks_json'] as String) as List).map((j) => StockSheet.fromJson(j)).toList(),
      parts: (jsonDecode(r['parts_json'] as String) as List).map((j) => CutPart.fromJson(j)).toList(),
      kerf: (r['kerf'] as num).toDouble(),
      grainLocked: r['grain_locked'] == 1,
      showPartLabels: r['show_part_labels'] == 1,
      useSingleSheet: r['use_single_sheet'] == 1,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    )).toList();
  }

  Future<void> close() async => _db.close();
}
```

**Step 4: 테스트 통과 확인**

```bash
flutter test test/data/local/project_db_test.dart
```

Expected: PASS.

**Step 5: Commit**

```bash
git add lib/data/ test/data/
git commit -m "feat(data): ProjectDb with sqflite_common_ffi + roundtrip test"
```

---

## Phase 5: Riverpod Providers

### Task 10: Providers 설정

**Files:**
- Create: `lib/ui/providers/db_provider.dart`
- Create: `lib/ui/providers/current_project_provider.dart`
- Create: `lib/ui/providers/solver_provider.dart`

**Step 1: db_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/local/project_db.dart';

final dbProvider = FutureProvider<ProjectDb>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'cutmaster.db');
  return ProjectDb.open(path);
});
```

**Step 2: current_project_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/project.dart';
import '../../domain/models/stock_sheet.dart';
import '../../domain/models/cut_part.dart';
import 'db_provider.dart';

class CurrentProjectNotifier extends StateNotifier<Project> {
  final Ref ref;
  CurrentProjectNotifier(this.ref) : super(Project.create(id: _newId(), name: '새 프로젝트'));

  static String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

  void setProject(Project p) => state = p;
  void updateStocks(List<StockSheet> stocks) => _save(state.copyWith(stocks: stocks));
  void updateParts(List<CutPart> parts) => _save(state.copyWith(parts: parts));
  void updateKerf(double kerf) => _save(state.copyWith(kerf: kerf));
  void updateGrainLocked(bool v) => _save(state.copyWith(grainLocked: v));
  void updateShowPartLabels(bool v) => _save(state.copyWith(showPartLabels: v));

  void _save(Project p) {
    state = p;
    // debounce 자동 저장
    Future.delayed(const Duration(milliseconds: 500), () async {
      final db = await ref.read(dbProvider.future);
      await db.upsertProject(state);
    });
  }
}

final currentProjectProvider = StateNotifierProvider<CurrentProjectNotifier, Project>(
  (ref) => CurrentProjectNotifier(ref),
);
```

**Step 3: solver_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/cutting_plan.dart';
import '../../domain/solver/solver_isolate.dart';
import 'current_project_provider.dart';

final cuttingPlanProvider = StateProvider<CuttingPlan?>((ref) => null);
final isCalculatingProvider = StateProvider<bool>((ref) => false);

Future<void> runCalculate(WidgetRef ref) async {
  final p = ref.read(currentProjectProvider);
  ref.read(isCalculatingProvider.notifier).state = true;
  try {
    final plan = await solveInIsolate(
      stocks: p.stocks, parts: p.parts,
      kerf: p.kerf, grainLocked: p.grainLocked,
    );
    ref.read(cuttingPlanProvider.notifier).state = plan;
  } finally {
    ref.read(isCalculatingProvider.notifier).state = false;
  }
}
```

**Step 4: Commit**

```bash
git add lib/ui/providers/
git commit -m "feat(state): Riverpod providers for db, current project, solver"
```

---

## Phase 6: UI

### Task 11: MainScreen 스캐폴드

**Files:**
- Create: `lib/ui/main_screen.dart`
- Modify: `lib/main.dart`

**Step 1: MainScreen 작성**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_colors.dart';
import 'widgets/top_bar.dart';
import 'widgets/left_pane.dart';
import 'widgets/right_pane.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const TopBar(),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 380, child: LeftPane()),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: const RightPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: 빈 위젯 stub**

3개 빈 위젯 stub 생성 (TopBar, LeftPane, RightPane) — 다음 task에서 채움.

`lib/ui/widgets/top_bar.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) => Container(
    height: 48, color: AppColors.header,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.centerLeft,
    child: const Text('Cutmaster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
  );
}
```

비슷하게 LeftPane, RightPane stub 작성.

**Step 3: main.dart 교체**

```dart
home: const MainScreen(),
```

**Step 4: 빌드 확인**

```bash
flutter run -d macos
```

Expected: 다크 네이비 헤더 + 좌측 빈 패널 + 우측 빈 영역 보임.

**Step 5: Commit**

```bash
git add lib/ui/
git commit -m "feat(ui): MainScreen scaffold with TopBar + LeftPane + RightPane"
```

### Task 12: TopBar 완성

**Files:**
- Modify: `lib/ui/widgets/top_bar.dart`
- Create: `lib/ui/widgets/project_dropdown.dart`

TopBar에 프로젝트 dropdown + 계산 버튼 + 저장 + 설정 추가. 계산 버튼은 primary green, "▶ 계산" 라벨. 클릭 시 `runCalculate(ref)` 호출.

(코드는 design doc 참조해서 풀 구현)

**Step: Commit**

```bash
git commit -m "feat(ui): TopBar with project dropdown, calculate, save, settings"
```

### Task 13: LeftPane — 부품 inline editable table

**Files:**
- Modify: `lib/ui/widgets/left_pane.dart`
- Create: `lib/ui/widgets/parts_table.dart`

3개 collapsible section (ExpansionTile). 부품 table은 4개 컬럼 (가로/세로/수량/라벨), 인라인 편집, 마지막 행에 "+" 추가 행. 변경 시 `currentProjectProvider`의 `updateParts` 호출.

**Step: Commit**

```bash
git commit -m "feat(ui): parts table with inline editing"
```

### Task 14: LeftPane — 자재 table + 프리셋

**Files:**
- Create: `lib/ui/widgets/stocks_table.dart`
- Create: `lib/ui/widgets/preset_dialog.dart`

자재 table은 부품과 동일 패턴 + "프리셋" 버튼. 프리셋 다이얼로그에 한국 합판 표준 규격 (2440×1220 등) 5-6개 표시.

**Step: Commit**

```bash
git commit -m "feat(ui): stocks table with Korean plywood presets"
```

### Task 15: LeftPane — 옵션 섹션

**Files:**
- Create: `lib/ui/widgets/options_section.dart`

kerf numeric input (TextField with NumericInputFormatter), 3개 toggle switch (결방향 고정, 부품 라벨 표시, 단일 시트 사용). `currentProjectProvider` 업데이트.

**Step: Commit**

```bash
git commit -m "feat(ui): options section with kerf input + toggles"
```

### Task 16: RightPane — Empty state

**Files:**
- Create: `lib/ui/widgets/empty_result.dart`
- Modify: `lib/ui/widgets/right_pane.dart`

`cuttingPlanProvider`가 null이면 EmptyResultPane 표시 (아이콘 + 안내 문구), 아니면 CuttingResultPane 표시.

**Step: Commit**

```bash
git commit -m "feat(ui): empty state for results pane"
```

### Task 17: RightPane — 시각화 (CustomPainter)

**Files:**
- Create: `lib/ui/widgets/cutting_canvas.dart`
- Create: `lib/ui/widgets/cutting_result_pane.dart`

CustomPainter로 시트별 도면. 각 시트는 2440×1220 비율로 그리되 화면 너비에 맞춰 scale. 부품은 라벨과 함께 표시 (showPartLabels이 true일 때). 자투리는 회색 hatch 패턴. 시트 헤더에 시트 번호 + 사용률.

상단에 효율% 큰 숫자 (32sp Bold green), "X장 / Y개 / Z개 미배치" 요약, PNG export 버튼.

**Step: Commit**

```bash
git commit -m "feat(ui): cutting result pane with CustomPainter visualization"
```

### Task 18: 자재 수정 다이얼로그 (snapshot 정책 [A1])

**Files:**
- Create: `lib/ui/widgets/material_update_dialog.dart`
- Create: `test/ui/material_update_dialog_test.dart`

**Step 1: 다이얼로그 widget test 먼저**

```dart
testWidgets('자재 수정 시 다이얼로그 → 예 누르면 onConfirm', (tester) async {
  bool confirmed = false;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) {
    return ElevatedButton(
      onPressed: () => showMaterialUpdateDialog(ctx, onConfirm: () { confirmed = true; }),
      child: const Text('open'),
    );
  }))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('자재가 변경되었습니다'), findsOneWidget);
  await tester.tap(find.text('예'));
  await tester.pumpAndSettle();
  expect(confirmed, true);
});
```

**Step 2: 다이얼로그 구현**

```dart
import 'package:flutter/material.dart';

void showMaterialUpdateDialog(BuildContext context, {required VoidCallback onConfirm}) {
  showDialog(context: context, builder: (c) => AlertDialog(
    title: const Text('자재가 변경되었습니다'),
    content: const Text('이 프로젝트도 변경된 자재로 다시 계산할까요?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('아니오')),
      ElevatedButton(onPressed: () { Navigator.pop(c); onConfirm(); }, child: const Text('예')),
    ],
  ));
}
```

**Step 3: 테스트 통과 확인 + Commit**

```bash
flutter test test/ui/material_update_dialog_test.dart
git add lib/ui/widgets/material_update_dialog.dart test/ui/
git commit -m "feat(ui): material update dialog with widget test"
```

### Task 19: PNG export

**Files:**
- Create: `lib/ui/utils/png_export.dart`

`RepaintBoundary` + `boundary.toImage()`으로 시트별 PNG 생성. file_picker로 저장 경로 선택. 시트가 큰 경우 75dpi로 시작.

**Step: Commit**

```bash
git commit -m "feat(ui): PNG export with file picker"
```

---

## Phase 7: 통합 테스트 (E2E)

### Task 20: First-run flow E2E

**Files:**
- Create: `integration_test/first_run_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cutmaster/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first-run flow: 자재 + 부품 → 계산 → 시각화', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 자재 섹션 확장
    await tester.tap(find.text('자재'));
    await tester.pumpAndSettle();

    // 프리셋 추가
    await tester.tap(find.text('프리셋'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2440 × 1220 (12T)'));
    await tester.pumpAndSettle();

    // 부품 입력 (인라인)
    // ... TODO: 인라인 편집 UI에 따라 구체화

    // 계산 클릭
    await tester.tap(find.byTooltip('계산'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 결과 확인
    expect(find.textContaining('%'), findsOneWidget);  // 효율 표시
  });
}
```

**Step: Commit**

```bash
flutter test integration_test/first_run_test.dart -d macos
git add integration_test/
git commit -m "test(e2e): first-run flow integration test"
```

---

## Phase 8: 빌드 + 배포

### Task 21: macOS .dmg 빌드

**Step 1: Release 빌드**

```bash
flutter build macos --release
```

Expected: `build/macos/Build/Products/Release/cutmaster.app` 생성.

**Step 2: .dmg 패키징** (간단 방법)

```bash
hdiutil create -volname Cutmaster -srcfolder build/macos/Build/Products/Release/cutmaster.app -ov -format UDZO build/cutmaster-v0.1.dmg
```

**Step 3: 친구한테 보내기 안내**

설치 가이드 문서 (`docs/INSTALL_MACOS.md`) 작성:
1. .dmg 더블클릭 → /Applications으로 드래그
2. 첫 실행 시 우클릭 → "열기" (unsigned 우회)
3. 시스템 환경설정 → 보안 → "이대로 열기"

### Task 22: Windows .msi 빌드 (선택)

Windows 머신 또는 VM에서:

```bash
flutter build windows --release
```

Inno Setup으로 .msi 생성 — 또는 그냥 `cutmaster.exe`와 `data/` 폴더 zip으로 보내도 됨.

### Task 23: 친구한테 ship

- .dmg 또는 .zip 친구한테 메시지로 전달
- 1주일 후 옆에서 사용 보면서 "특별 기능" 후보 발굴
- v0.2 계획 수립

---

## Done criteria

- [ ] 12개 테스트 모두 통과 (`flutter test`)
- [ ] macOS에서 빌드 + 실행 성공
- [ ] yp 본인이 한 사이클 동작 확인 (자재 → 부품 → 계산 → 시각화 → export)
- [ ] 친구한테 .dmg 보내고 설치/실행 확인
- [ ] design doc의 Success Criteria 6개 모두 체크

총 예상: **6-8일 (CC pace)** / 1.5-2주 (human pace).

---

## Notes for Claude executing this plan

- TDD 디시플린 유지: 테스트 먼저, 그 다음 구현.
- 각 task 끝에 commit. push는 사용자가 명시 요청 시에만.
- design doc과 test plan이 single source of truth — 충돌 시 design doc 우선.
- Task 11-19 (UI)는 시각 토큰을 정확히 따라야 함 — 색상/타이포 임의 변경 금지.
- 솔버 (Task 6-8)는 가장 회귀 위험 높음 — edge case 테스트 다 통과해야 다음 task로.
- 막히면 design doc + test plan 다시 읽기. 추측하지 말고 사용자한테 확인.
