# 부품 import 시 중복 처리 다이얼로그 — 디자인

## 배경

CSV/Excel 가져오기는 현재 신규 행을 무조건 기존 부품 목록에 `append`한다. 같은 파일을 두 번 임포트하거나, 비슷한 작업의 부품 목록을 추가할 때 중복 행이 그대로 쌓인다. 사용자가 임포트 시점에 "덮어쓰기 / 수량 합산 / 이름 변경 후 추가 / 취소" 중 하나를 선택할 수 있어야 한다.

## 충돌 정의

5-튜플이 모두 일치하면 충돌:

```
(label.trim(), colorPresetId, lengthMm, widthMm, thicknessMm)
```

- `grainDirection`은 키에서 제외 — 덮어쓰기 시 신규 값으로 교체된다.
- 한 incoming 행이 여러 existing 행과 매치되면 첫 번째 매치만 충돌로 본다.

## 액션 동작

| 액션 | 동작 |
|------|------|
| **덮어쓰기** | 충돌하는 기존 행을 신규 행으로 교체 (qty/grain 등 모두 신규 값). 비충돌 신규 행은 append. |
| **수량 증가** | 충돌한 기존 행의 `qty += 신규.qty`. 다른 필드는 기존 유지. 비충돌 신규 행은 append. |
| **이름 변경 후 추가** | 신규 행 label을 `"{원본} (2)"` → `"{원본} (3)"` 식으로 충돌 안 날 때까지 증가시켜 추가. 기존 행은 건드리지 않음. 같은 배치 내 동일 label 충돌도 (2), (3), ... 로 증분. base가 이미 `" (k)"`로 끝나도 base에서 떼어내고 (2)부터 시작 — 재진입 시 누적 방지. |
| **취소** | 전체 import 무산. 한 행도 추가/변경하지 않음. |

충돌이 0건이면 다이얼로그를 띄우지 않고 그대로 append (현 동작 유지).

## UI

`AlertDialog` 한 개에 충돌 목록을 표 형식으로 보여주고 4개 버튼.

```
┌─ 중복 부품이 있습니다 ─────────────────────┐
│  기존 목록과 동일한 부품 N개가 발견되었습니다.   │
│  (이름 + 자재 + 사이즈 모두 일치)             │
│                                            │
│  ┌─ 충돌 목록 (스크롤) ───────────────┐    │
│  │ • 선반_상   화이트_18T  600×300  ×3  │  │
│  │ • 측판      오크_15T    800×400  ×4  │  │
│  └────────────────────────────────────┘  │
│                                            │
│        [덮어쓰기]  [수량 증가]              │
│        [이름 변경 후 추가]  [취소]           │
└────────────────────────────────────────────┘
```

DESIGN.md 토큰 준수 (라이트 테마, 12px panel radius, brand indigo `#5e6ad2` 1차 액션, ghost 취소). `barrierDismissible: false`. Esc → cancel.

## 코드 구조

**신규 모듈:** `lib/data/import/parts_merge.dart`

```dart
enum MergeAction { overwrite, addQty, renameAndAdd, cancel }

class PartsMergeConflict {
  final int existingIndex;
  final CutPart existing;
  final CutPart incoming;
}

class PartsMergeResult {
  final List<CutPart> mergedParts;
  final int addedCount;
  final int overwrittenCount;
  final int qtyMergedCount;
  final int renamedCount;
}

List<PartsMergeConflict> detectConflicts(
  List<CutPart> existing,
  List<CutPart> incoming,
);

PartsMergeResult applyMerge(
  List<CutPart> existing,
  List<CutPart> incoming,
  MergeAction action,
);
```

순수 함수. UI 의존성 없음. CSV/Excel 두 진입점에서 공유.

**다이얼로그:** `lib/ui/dialogs/parts_merge_dialog.dart`

```dart
Future<MergeAction?> showPartsMergeDialog(
  BuildContext context,
  List<PartsMergeConflict> conflicts,
);
```

**진입점 통합:** `lib/ui/widgets/parts_table.dart`의 CSV/Excel import 핸들러 두 곳. 흐름:

1. `importer.parse(file) → incoming`
2. `detectConflicts(existing, incoming)`
3. 충돌 1건 이상이면 `showPartsMergeDialog`
4. 액션 따라 `applyMerge`
5. `tabsProvider.updateActiveProject(parts: result.mergedParts)`
6. SnackBar로 통계 표시 ("추가 N, 합산 N, 덮어쓰기 N")

## 테스트 전략 (TDD)

**단위:** `test/data/import/parts_merge_test.dart` — `detectConflicts` 7~8 케이스, `applyMerge` 액션별 + 통계 카운트.

**위젯:** `test/ui/dialogs/parts_merge_dialog_test.dart` — 4개 버튼 → 4개 액션, Esc → cancel, barrier 무시.

**통합:** `test/ui/widgets/parts_table_import_test.dart` — CSV 충돌 있을 때 다이얼로그 노출, 0건일 때 미노출.

Excel 진입점은 머지 로직 공유이므로 통합은 CSV로만.

## 검증 게이트

```bash
flutter analyze    # 0 issues (변경 영역)
flutter test       # 전 케이스 통과
```
