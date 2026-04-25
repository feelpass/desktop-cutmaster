# 글로벌 프리셋 + LeftPane 편집성 개선 — 디자인

날짜: 2026-04-25
브랜치: TBD (구현 시작 시 worktree 생성)

## 배경

현재 cutmaster의 LeftPane은 부품/자재를 가로 1줄 텍스트 입력으로 편집한다.
자재 프리셋은 `preset_dialog.dart`에 한국 합판 표준 6종이 하드코딩되어
사용자가 추가/편집할 수 없다. 부품 프리셋은 아예 없다. 색상 프리셋은
`part_color.dart`에 부품 12색 + 자재 12색이 분리된 상수로 박혀 있고,
각 색에 이름이 있는데도 행 UI에는 swatch만 노출되어 가독성이 떨어진다.

친구 가구공장의 워크플로우에서 부각된 문제:

- 자기네 자주 쓰는 자재 사이즈를 직접 등록할 수 없다.
- 부품도 동일한 사이즈가 도면마다 반복되는데 매번 입력한다.
- 수량 +/- 같은 마이크로 인터랙션이 없어서 미세 조정이 답답하다.
- 색상 swatch만 보고는 "이게 호두인지 자작인지" 한 눈에 안 들어온다.
- 색상 자체를 사용자가 관리할 수 없다 (이름/색을 바꿀 방법이 없다).

## 목표

1. **글로벌 프리셋 시스템** — 색상 / 부품 / 자재 세 종류의 프리셋을
   사용자가 추가/편집/삭제할 수 있게 한다. 모든 프로젝트에서 공유한다.
2. **연동 모델** — 색상 프리셋이 부품/자재 프리셋과 실제 행에 *참조*
   관계로 연결된다. 색상 정의가 바뀌면 모든 사용처에 자동 반영된다.
3. **행 편집 UX 개선** — 1줄(편집) + 메타 줄(정보) 레이아웃, 수량
   `[-][n][+]` 스피너, 색상 이름 텍스트 표시.

## 비목표 (YAGNI)

- 프로젝트별 프리셋 오버라이드 — 글로벌 1개 풀로 충분.
- 결방향(grain) 인라인 편집 — 메타 줄에 표시만, 편집은 프리셋에서.
- 가구 키트 템플릿 (한 번에 부품 여러 줄 추가) — 프리셋은 1행 단위.
- 라벨 자동완성 — 빈 행 추가 후 라벨 입력 시 매칭 추천 등.
- 수량 스피너 long-press auto-repeat — 큰 수량은 키보드 입력이 빠르다.
- 색상 프리셋의 부품/자재 분리 — 단일 풀.
- 색상 프리셋 사용 횟수 카운팅, 정렬 옵션 등.

## 결정 사항 요약

| 영역 | 결정 |
| --- | --- |
| 부품 프리셋 의미 | 자주 쓰는 부품 1개 사이즈 (가구 키트 X) |
| 저장 위치 | 앱 글로벌 (`~/Library/Application Support/cutmaster/presets.json`) |
| 세팅 화면 형태 | 모달 다이얼로그 (좌측 리스트 + 우측 폼) |
| 진입점 | 섹션 헤더 ⚙️ + 프리셋 선택 다이얼로그 내 "관리..." |
| 사용 흐름 | 행 추가 버튼 + 별도 "프리셋" 버튼 (자재 현재 흐름 부품에도 적용) |
| 프리셋 데이터 범위 | 치수 + 색상 + 결방향 (수량 제외) |
| 행 레이아웃 | 1줄(치수+수량) + 메타 줄(색상 이름+결방향+라벨) |
| 색상 이름 노출 | 프리셋이면 진하게, 자동이면 흐린 "자동" |
| 수량 +/- | `[-][숫자][+]` inline, long-press 없음 |
| 결방향 UI | 메타 줄에 작게 표시만 (편집은 프리셋 세팅에서) |
| 시드 | 자재 6종 + 색상 24색, 부품 빈 상태 |
| 색상 ↔ 부품/자재 | 참조 모델 (`colorPresetId`) |
| 색상 풀 구조 | 단일 풀 (부품/자재 구분 없음) |
| 폼 변경 저장 | 즉시 저장 (디바운스 ~300ms) |

## 데이터 모델

### 신규 타입

```dart
class ColorPreset {
  final String id;     // "cp_xxx"
  final String name;   // "호두", "빨강"
  final int argb;
}

class DimensionPreset {  // 부품/자재 공통
  final String id;
  final double length;
  final double width;
  final String label;
  final String? colorPresetId;   // null = 자동
  final GrainDirection grain;
}
```

### 변경되는 기존 타입

```dart
class CutPart {
  // BEFORE: int? colorArgb
  // AFTER:  String? colorPresetId
  ...
}

class StockSheet {
  // 동일 변경
}
```

수량(`qty`)은 프리셋에서 의도적으로 제외한다 — 도면마다 다르므로
프리셋 적용 시 항상 `qty = 1`로 새 행이 추가된다.

### 저장 포맷

`~/Library/Application Support/cutmaster/presets.json`:

```json
{
  "version": 1,
  "colorPresets": [
    { "id": "cp_red",    "name": "빨강", "argb": 4293467204 },
    { "id": "cp_walnut", "name": "호두", "argb": 4287324736 },
    ...
  ],
  "partPresets": [],
  "stockPresets": [
    {
      "id": "sp_ply12",
      "length": 2440, "width": 1220,
      "label": "12T 합판",
      "colorPresetId": null,
      "grain": "lengthwise"
    },
    ...
  ]
}
```

### 시드 데이터

- **colorPresets** — 현재 `partColorPresets` 12색 + `stockColorPresets`
  12색을 합쳐 24개. 이름 그대로 (빨강/주황/.../호두/자작/...).
- **partPresets** — 빈 배열.
- **stockPresets** — 현재 `_presets` 6종 (2440×1220 12T/15T/18T/MDF 9T/
  MDF 18T, 1220×2440 12T 가로형). `colorPresetId`는 null.

### 참조 무결성

- 색상 프리셋 삭제 시 그걸 쓰던 부품/자재 프리셋과 실제 행은
  `colorPresetId = null`로 떨어지면서 "자동" 색으로 표시된다.
- 삭제 전에 confirmation: "이 색상은 N개 부품/자재에서 쓰이는 중입니다.
  삭제하시겠어요?"

## 마이그레이션

### .cutmaster 파일 호환

기존 `.cutmaster` 파일은 부품/자재의 `color` 필드에 ARGB int를 가지고
있다. fromJson에서:

1. `color: int` 필드 발견 시 → 글로벌 색상 프리셋에서 가장 가까운 ARGB
   매칭 (정확 매칭 우선, 없으면 RGB 거리 최소).
2. 매칭이 너무 멀면(임계 이상) 임시 `ColorPreset` 자동 생성 후 풀에
   추가하고 그 id 반환. 이름은 `"가져온 색 #1"` 같은 자동 이름.
3. 부품/자재 모델 `version` 1→2 bump.

### 코드 마이그레이션

- `ui/utils/part_color.dart`
  - `partColorPresets`, `stockColorPresets` 상수 → 시드 데이터로 이전,
    상수 제거.
  - `presetsFor()` 함수 → 사용자 데이터 기반으로 재작성 (또는 호출처
    수정으로 전부 provider 사용).
  - `autoColorFor()`, `resolveColor()` — 자동 색상 fallback용으로 유지.
  - `presetNameOf()` → 글로벌 색상 프리셋 lookup으로 재작성.

## UI 설계

### 프리셋 세팅 다이얼로그 (3종 공통 패턴)

```
┌─ 부품 프리셋 관리 ──────────────────────────┐
│ ┌─리스트──────┐  ┌─편집 폼──────────────┐ │
│ │ 호두 18T  ▶ │  │ 라벨   [호두 18T   ] │ │
│ │ 자작 12T    │  │ 길이   [    600   ] │ │
│ │ MDF 9T      │  │ 폭     [    300   ] │ │
│ │             │  │ 색상   [● 호두  ▼] │ │
│ │             │  │ 결방향 [↔ ↕ —    ] │ │
│ │ [+ 추가]    │  │                      │ │
│ │             │  │ [삭제]      [닫기]  │ │
│ └─────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────┘
```

- **좌측 리스트** — 프리셋 `label`로 표시. 선택 항목 하이라이트.
  하단 `+ 추가` 버튼 → 빈 프리셋 생성 후 우측 폼 포커스.
- **우측 폼** — 모든 필드 편집. 변경은 ~300ms 디바운스 후 즉시 저장
  (별도 저장 버튼 없음, 멀티 탭 자동저장과 동일 철학).
- **삭제** — confirmation dialog 띄움.
- **닫기** — 다이얼로그만 닫음 (변경은 이미 저장됨).

색상 필드는 드롭다운: 펼치면 글로벌 색상 프리셋 + "자동" + 하단
`색상 프리셋 관리...` 버튼 (= 색상 프리셋 세팅 진입점 중 하나).

결방향 필드는 segmented toggle: `↔ 가로결` / `↕ 세로결` / `— 무관`.

### 색상 프리셋 관리 다이얼로그

같은 좌측 리스트 + 우측 폼 패턴. 폼은 단순:

```
이름   [호두            ]
색상   [● ARGB 입력 또는 swatch 클릭]
```

색상 swatch 클릭 시 `flutter_colorpicker` 패키지 기반 sub-dialog (hex/
HSV/팔레트 모두 지원).

### 부품/자재 행 (EditableDimensionTable 재구성)

```
┌─ 1줄 (편집 가능) ──────────────────────────┐
│ ●  [600 ] × [300 ] | [-][3][+] | ✕      │
└─────────────────────────────────────────────┘
┌─ 메타 줄 (대부분 읽기 전용) ─────────────┐
│   호두  ↔  · 호두 18T                     │
└─────────────────────────────────────────────┘
```

**1줄 컬럼 정렬**:
- 색상 swatch: 28px 고정
- 길이: Expanded(2)
- × 구분자: 12px 고정
- 폭: Expanded(2)
- 수량 spinner: 80px 고정
- 삭제: 28px 고정

**메타 줄**:
- 색상 이름: `colorPresetId`로 lookup. 프리셋이면 `호두` 진하게,
  자동이면 `자동` 흐리게(italic).
- 결방향: `↔` (lengthwise) / `↕` (widthwise) / 표시 없음 (none).
  작은 아이콘.
- 라벨: `· 호두 18T` 작은 글씨로 inline. 클릭 시 인라인 편집(텍스트
  필드로 변환, Enter/포커스 아웃 시 저장).

**헤더** — 1줄용만 남김 (`길이 × 폭   수량`). 메타 줄은 헤더 없음.

**수량 stepper (`qty_stepper.dart` 신규)**:
- `[-][숫자입력][+]` 가로 inline, 전체 ~80px.
- - / + 는 28×28 IconButton, 가운데 32px 숫자 입력 (오른쪽 정렬).
- 1 미만은 클램프, 999 상한.
- long-press auto-repeat는 도입하지 않음.

### 진입점 정리

| 진입 | 도착 |
| --- | --- |
| 부품 섹션 헤더 ⚙️ | 부품 프리셋 관리 다이얼로그 |
| 자재 섹션 헤더 ⚙️ | 자재 프리셋 관리 다이얼로그 |
| 부품/자재 "프리셋" 버튼 → 다이얼로그 하단 "관리..." | 동일 |
| 색상 swatch 클릭 → picker 하단 "관리..." | 색상 프리셋 관리 다이얼로그 |
| 부품/자재 프리셋 편집 폼 → 색상 드롭다운 하단 "관리..." | 동일 |

## 디렉터리 구조

### 신규

```
lib/
  data/
    preset/
      preset_models.dart            # ColorPreset / DimensionPreset
      preset_seeds.dart             # 시드 24색 + 자재 6종
      preset_repository.dart        # JSON I/O (Application Support)
  ui/
    providers/
      preset_provider.dart          # 3개 StateNotifierProvider
    widgets/
      preset_management_dialog.dart        # 부품/자재 공용
      color_preset_management_dialog.dart  # 색상 전용
      qty_stepper.dart                     # [-][n][+]
```

### 변경

| 파일 | 변경 |
| --- | --- |
| `domain/models/cut_part.dart` | `colorArgb` → `colorPresetId` |
| `domain/models/stock_sheet.dart` | 동일 |
| `ui/utils/part_color.dart` | 상수 제거, `presetNameOf` 글로벌 lookup |
| `ui/widgets/color_picker_dialog.dart` | 글로벌 색상 프리셋 사용, 하단 "관리..." |
| `ui/widgets/preset_dialog.dart` | 하드코딩 제거, 글로벌 자재 프리셋 사용, 하단 "관리..." |
| `ui/widgets/parts_table.dart` | 자재처럼 "프리셋" 버튼 추가 |
| `ui/widgets/editable_dimension_table.dart` | 1줄+메타 줄 레이아웃 재구성 |
| `ui/widgets/left_pane.dart` | 섹션 헤더에 ⚙️ 아이콘 |

## 구현 순서

각 단계는 독립적으로 commit + 테스트 가능.

1. **데이터 레이어** — `ColorPreset`/`DimensionPreset` 모델, repository,
   provider, 시드 JSON.
2. **모델 마이그레이션** — `CutPart`/`StockSheet`의 `colorArgb` →
   `colorPresetId`. `.cutmaster` fromJson 호환 코드.
3. **색상 프리셋 관리 다이얼로그** — 가장 leaf, 단독 테스트 가능.
4. **부품/자재 프리셋 관리 다이얼로그** — 색상 드롭다운에서 (3) 진입.
5. **기존 picker/preset 다이얼로그 hookup** — 글로벌 프리셋 사용으로 전환.
6. **행 레이아웃 재구성** — 1줄+메타 줄, `qty_stepper`, 색상 이름.
7. **섹션 헤더 ⚙️**, **부품 "프리셋" 버튼** 추가.
8. **E2E 테스트** — 색상 추가 → 부품 프리셋 사용 → 행 적용 → 색상 이름
   변경 시 자동 반영, 색상 삭제 시 fallback.

## 테스트 전략

- **단위** — `PresetRepository` round-trip(JSON ↔ 객체), 시드 적용 시
  파일 생성, 색상 매칭 마이그레이션 (기존 `colorArgb` → 가장 가까운
  프리셋 id).
- **위젯** — 관리 다이얼로그(추가/편집/삭제), color picker hookup,
  `qty_stepper` 1/999 클램프, 인라인 라벨 편집.
- **E2E** — 마이그레이션 시나리오(`color`만 있는 옛 .cutmaster 열기),
  색상 프리셋 이름 변경 시 모든 행/프리셋에 자동 반영, 색상 삭제 시
  사용처 경고 + fallback.

## 열린 질문

- 색상 프리셋 ARGB가 *기존 24색과 정확 매칭이 안 될 만큼* 다른 .cutmaster
  파일이 있을 때 자동 생성 임계는? (RGB 거리 < N) — 구현 단계에서 결정.
- 색상 프리셋 풀 크기가 너무 커지면 picker가 답답해지는데, 검색 박스를
  넣을지는 일단 보류. 24개 시드 + 사용자 추가 N개 정도로는 충분히
  스크롤 가능.
