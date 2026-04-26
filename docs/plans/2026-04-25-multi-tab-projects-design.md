# 멀티 탭 + 파일 기반 프로젝트 저장

날짜: 2026-04-25
상태: 디자인 확정 (구현 전)

## 배경

현재 cutmaster는 한 번에 한 프로젝트만 다룰 수 있다. 모든 프로젝트는 단일 SQLite DB(`project_db.db`)에 저장되고, 상단 dropdown 메뉴로 프로젝트를 전환하거나 이름을 변경한다. 사용자는 다음을 원했다.

- 여러 프로젝트를 탭으로 동시에 띄우기
- 탭 이름 더블클릭으로 이름 변경
- `+` 버튼으로 저장된 프로젝트 열기
- 파일 단위 저장 (Finder / 탐색기에서 직접 다룰 수 있게)

## 목표 / 비목표

**목표**
- 멀티 탭 워크스페이스 (열기 / 닫기 / 정렬 / 이름변경)
- `.cutmaster` JSON 파일 단위 저장
- 마지막 세션 복원
- 닫은 탭 복원 (`Cmd+Shift+T`)
- 기존 사용자 데이터 마이그레이션

**비목표 (이번 작업 제외)**
- Split view (한 화면에 여러 프로젝트)
- 파일 잠금 (다른 인스턴스가 같은 파일 편집)
- 클라우드 동기화 충돌 자동 머지 — 분기 저장으로 단순화
- 탭 핀 / 그룹 / 색깔

## 핵심 결정사항

| # | 항목 | 결정 |
|---|---|---|
| Q1 | 저장 방식 | 하이브리드: 프로젝트 = `.cutmaster` JSON 파일, 워크스페이스 메타 = 작은 SQLite |
| Q2 | 새 프로젝트 라이프사이클 | Untitled (in-memory) + autosave 백업, 첫 명시 저장에서 위치 지정 |
| Q3 | `+` 버튼 | 메뉴 popup: `[새 프로젝트]` / `[파일에서 열기...]` / `--- 최근 ---` |
| Q4 | 앱 시작 | 마지막 세션 복원 (열려있던 모든 탭 + 활성 탭) |
| Q5 | 탭 닫기 | 묻지 않고 즉시 닫음, autosave 30일 보관 + `Cmd+Shift+T` 복원 |
| Q6 | 이름 ↔ 파일명 | 1:1 — 탭 이름 변경 = 파일 rename |
| Q7 | 중복 열기 | 이미 열린 탭으로 포커스 이동 |
| Q8 | 첫 저장 폴더 | `~/Documents/Cutmaster/` 기본 + 파일명만 묻는 inline 다이얼로그 |
| Q9 | UX 디테일 | 인라인 편집 / 가로 스크롤 / 드래그 정렬 / 우클릭 메뉴 / 표준 단축키 |

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│ TopBar                                                  │
│ ┌──────┐ ┌──────────────────────────────┐ ┌────────┐    │
│ │ Logo │ │ TabBar  [tab][tab]●[tab][+]  │ │ ▶ 계산 │    │
│ └──────┘ └──────────────────────────────┘ └────────┘    │
├─────────────────────────────────────────────────────────┤
│  LeftPane (활성 탭의 프로젝트)        │  RightPane       │
└─────────────────────────────────────────────────────────┘
```

`ProjectDropdown` 위젯이 사라지고 그 자리에 `TabBar`가 들어온다. `LeftPane` / `RightPane`은 "활성 탭의 프로젝트" 하나만 보면 되어 거의 손대지 않는다.

## 데이터 모델

### `.cutmaster` 파일 포맷 (JSON, pretty-printed)

```jsonc
{
  "schemaVersion": 1,
  "id": "1735203412000",
  "name": "책장",
  "kerf": 3.0,
  "grainLocked": false,
  "showPartLabels": true,
  "useSingleSheet": false,
  "stocks":   [ /* StockSheet.toJson() */ ],
  "parts":    [ /* CutPart.toJson()   */ ],
  "createdAt": "2026-04-25T10:23:00.000Z",
  "updatedAt": "2026-04-25T10:45:12.000Z"
}
```

- `id`는 UUID. 파일 이동 / rename에도 안정 식별자
- `schemaVersion`으로 미래 마이그레이션 안전
- 파일 이름 = `{name}.cutmaster`

### 워크스페이스 DB 스키마

위치: `~/Library/Application Support/cutmaster/workspace.db` (macOS) / 동등 위치 (Windows)

```sql
CREATE TABLE tab (
  id TEXT PRIMARY KEY,            -- tabId (UUID)
  file_path TEXT,                 -- NULL이면 untitled
  display_name TEXT NOT NULL,
  position INTEGER NOT NULL,
  is_active INTEGER NOT NULL
);

CREATE TABLE recent_file (
  file_path TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  last_opened_at TEXT NOT NULL    -- 최대 20개 LRU
);

CREATE TABLE closed_tab (
  tab_id TEXT PRIMARY KEY,
  file_path TEXT,
  autosave_path TEXT,
  display_name TEXT NOT NULL,
  closed_at TEXT NOT NULL         -- 30일 또는 50개 LRU
);

CREATE TABLE stock_sheet_library ( ... 기존 동일 ... );
```

### Autosave 폴더

```
~/Library/Application Support/cutmaster/
├── workspace.db
├── autosave/
│   └── <tabId>.cutmaster   ← untitled 탭의 자동 백업
└── recovery/
    └── <filename>.<timestamp>.bak  ← 손상 파일 백업
```

## 컴포넌트 / Riverpod 상태

### 위젯 트리

```
MainScreen
└── Column
    ├── TopBar (수정)
    │   ├── Logo
    │   ├── Expanded → TabBar  (⭐ ProjectDropdown 자리)
    │   │   ├── ReorderableListView (수평, 드래그 정렬)
    │   │   │   └── TabItem × N
    │   │   │       ├── Text  (또는 인라인 편집 TextField)
    │   │   │       ├── ●     (untitled 미저장 표시)
    │   │   │       └── X
    │   │   └── PlusButton  → showMenu(...)
    │   ├── ▶ Calculate
    │   └── ⚙ Settings
    ├── Expanded
    │   └── Row
    │       ├── LeftPane    ← activeProjectProvider 만 watch
    │       └── RightPane   ← 동일
```

### 새 / 변경 / 삭제 파일

```
+ lib/data/file/project_file.dart
+ lib/data/local/workspace_db.dart
+ lib/data/migration/legacy_to_files.dart
+ lib/ui/providers/tabs_provider.dart
+ lib/ui/providers/closed_tabs_provider.dart
+ lib/ui/providers/recent_files_provider.dart
+ lib/ui/widgets/tab_bar.dart
+ lib/ui/widgets/tab_item.dart
+ lib/ui/widgets/plus_button.dart
~ lib/ui/widgets/top_bar.dart       (dropdown 제거 → TabBar)
~ lib/main.dart                     (단축키 wiring)
~ lib/ui/widgets/left_pane.dart 외  (currentProjectProvider 치환)
- lib/ui/widgets/project_dropdown.dart
- lib/ui/widgets/rename_project_dialog.dart
- lib/ui/providers/current_project_provider.dart
```

### Riverpod 상태

```dart
final workspaceDbProvider = FutureProvider<WorkspaceDb>((ref) async => …);

final tabsProvider =
    StateNotifierProvider<TabsNotifier, List<TabState>>(…);

final activeTabIdProvider = StateProvider<String?>((ref) => null);

// LeftPane / RightPane이 watch하는 파생값
final activeProjectProvider = Provider<Project?>((ref) {
  final id = ref.watch(activeTabIdProvider);
  return ref.watch(tabsProvider)
      .firstWhereOrNull((t) => t.id == id)
      ?.project;
});

final recentFilesProvider = FutureProvider<List<RecentFile>>(…);

final closedTabsProvider =
    StateNotifierProvider<ClosedTabsNotifier, List<ClosedTab>>(…);

class TabState {
  final String id;          // UUID
  final String? filePath;   // null = untitled
  final Project project;
  final bool isDirty;
}
```

기존 `currentProjectProvider`는 삭제, 모든 사용처를 `activeProjectProvider`로 치환한다. 변경 메서드(`updateName`, `updateStocks`, …)는 `TabsNotifier`로 이전하며 시그니처는 "활성 탭 기준" 그대로 유지해 호출처 변경을 최소화한다.

## 라이프사이클 시퀀스

### 앱 시작
1. `workspaceDbProvider` 열고 `tab` 테이블 `position ASC`로 탭 복원
2. 탭마다: `file_path` → 파일 read → `Project`. NULL이면 `autosave/<tabId>.cutmaster`에서 복원
3. 파일 누락된 탭은 빠지고 토스트 노출. 다른 탭은 정상 진행
4. 탭이 0개면 빈 untitled 탭 1개 생성
5. `is_active=1`인 탭으로 포커스 (없으면 첫 탭)

### 입력 변경 (자동 저장, 500ms debounce)
- TabsNotifier가 변경 받으면 `state[i].isDirty = true`
- debounce 후 `_persist(tab)`:
  - `filePath != null` → 그 파일에 atomic write (`.tmp` → rename)
  - `filePath == null` → `autosave/<tabId>.cutmaster`에 쓰기
- 성공 후 `isDirty = false`

### Cmd+S — Untitled 첫 저장
1. inline 다이얼로그 `[파일 이름: 새 프로젝트] [저장] [다른 위치에 저장...]`
2. `~/Documents/Cutmaster/{name}.cutmaster`에 atomic write. 충돌 시 `(2)` suffix
3. `tab.file_path` 업데이트 + autosave 파일 삭제
4. `recent_file`에 등록

### 더블클릭 → 이름 변경
- 인라인 TextField로 변신 (현재 이름 미리 선택)
- `Enter` 확정, `Esc` 취소, focus 이탈도 확정
- 저장된 탭: 같은 폴더 내 파일 rename. 충돌 시 자동 suffix. `project.name` 동기 업데이트
- Untitled 탭: 메모리 이름만 변경 (autosave 파일명은 `<tabId>` 그대로)
- 파일명 금지 문자(`/ \ : * ? " < > |`)는 입력 차단
- 빈 이름은 reject (원래 이름 유지)
- rename 실패 시 토스트 + 원래 이름 복구

### 탭 닫기 (X 버튼 / Cmd+W)
1. 묻지 않고 즉시 닫음
2. `closed_tab` 행 추가 (file_path 또는 autosave_path, display_name, closed_at)
3. UI 제거. 활성 탭이었으면 인접 탭으로 포커스
4. 백그라운드: `closed_tab` 30일 / 50개 초과 시 LRU 정리 + autosave 파일 삭제

### Cmd+Shift+T — 닫은 탭 복원
- `closed_tab` 가장 최근 row pop → 새 탭으로 재오픈

### `+` → 파일에서 열기
- OS file picker → `.cutmaster` 선택 → 이미 열린 탭이면 포커스 이동, 아니면 새 탭

### `+` → 최근에서 선택
- 같음. 파일 사라졌으면 토스트 + `recent_file`에서 자동 제거

### 앱 종료
- 자동 저장 debounce 즉시 flush (await)
- `tab` 테이블 동기화 (순서 / 활성)
- DB close

## 에러 처리 / 엣지 케이스

### 파일 누락
- 시작 시: 그 탭만 빠짐. 토스트 `책장.cutmaster를 찾을 수 없어요`
- 자동 저장 중 발견: `다시 저장하기` 다이얼로그. autosave에 임시 보존
- `recent_file`에서 LRU pop

### 파일 손상 (JSON parse 실패 / 미래 schemaVersion)
- `recovery/<filename>.<timestamp>.bak`로 원본 백업
- 토스트로 경로 안내. 그 탭은 안 열림. 다른 탭 영향 없음

### 파일 권한 없음 (read-only / 잠금)
- read 실패 → 손상과 동일 처리
- write 실패 → `다른 이름으로 저장...` 다이얼로그. 메모리 상태 유지, autosave에 임시 백업

### 외부에서 파일 변경 (Dropbox / iCloud sync)
- 자동 저장 시 mtime 비교. 디스크 mtime > 마지막 우리 쓴 mtime → conflict
- **1차 단순화**: 자동으로 `책장 (충돌 사본).cutmaster`로 분기 저장 + 토스트 알림. 사용자가 직접 비교
- 추후 `[디스크 다시 불러오기] / [내 변경사항으로 덮어쓰기] / [복사본으로 저장]` 다이얼로그 도입

### 디스크 공간 / IO 실패
- autosave 폴더에라도 시도. 실패 시 토스트 + `isDirty=true` 유지

### 갑작스러운 종료 (전원 / 크래시)
- 워크스페이스 DB의 `tab`이 진실. 마지막 정상 종료 상태에서 시작
- atomic write이라 부분 쓰기로 인한 파일 손상 없음
- 시작 시 고아 autosave 파일 정리 (연결된 `tab` 없음)

### 같은 파일 두 번 열기 (같은 인스턴스)
- 기존 탭으로 포커스 이동 (Q7)

### 다른 인스턴스 / 외부 편집기에서 같은 파일
- 1차에서는 OS 잠금 미사용. mtime conflict 처리로 충분
- 추후 `.cutmaster.lock` 도입 — YAGNI

### 마이그레이션 실패
- 옛 DB는 read-only로 두고 옮기 → 실패해도 옛 데이터 안전
- `recovery/migration-<timestamp>.log`에 성공/실패 기록
- 다음 시작 시 미마이그레이션 항목 재시도

## 마이그레이션 (옛 사용자)

1. 첫 실행 시 옛 `project_db.db` 발견되면 `~/Documents/Cutmaster/`로 export
2. 충돌 시 `책장 (2).cutmaster` suffix
3. `recent_file`에 모두 등록, 가장 최근 1개를 활성 탭으로 시작
4. 옛 DB는 read-only로 보존. 다음 메이저 버전에서 삭제

## 키보드 단축키

| Shortcut | Action |
|---|---|
| `Cmd/Ctrl + N` | 새 untitled 탭 |
| `Cmd/Ctrl + O` | 파일 열기 다이얼로그 |
| `Cmd/Ctrl + W` | 현재 탭 닫기 |
| `Cmd/Ctrl + Shift + T` | 방금 닫은 탭 복원 |
| `Cmd/Ctrl + Tab` | 다음 탭 |
| `Cmd/Ctrl + S` | 저장 (untitled는 첫 저장 다이얼로그) |

## 우클릭 컨텍스트 메뉴

- 이름 변경 (= 더블클릭)
- 복사본 만들기 (`책장.cutmaster` → `책장 사본.cutmaster`)
- Finder/탐색기에서 보기
- 다른 이름으로 저장...
- 닫기
- 다른 탭 모두 닫기

## 테스트 전략

| 레벨 | 대상 | 핵심 케이스 |
|---|---|---|
| Unit | `ProjectFileService` | atomic write, JSON round-trip, `(2)` suffix, schemaVersion 검증 |
| Unit | `WorkspaceDb` | tab CRUD, recent_file LRU 20개, closed_tab 30일 만료 |
| Unit | `Migrator` | 옛 SQLite 5개 → 파일 5개. 충돌 / 부분 실패 |
| Unit | `TabsNotifier` | 새 탭 / 닫기 / 활성 변경 / 같은 파일 재오픈 → 포커스 이동 |
| Widget | `TabItem` | 더블클릭 인라인 편집, Enter/Esc, 빈 이름 reject |
| Widget | `TabBar` | 드래그 정렬, 가로 스크롤, untitled `●` 표시 |
| Widget | `PlusButton` | 메뉴 항목 / 최근 파일 / 사라진 파일 → 토스트 |
| E2E | flow | 시작 → `+` → 새 프로젝트 → 입력 → `Cmd+S` → 종료 → 재시작 → 복원 |
| E2E | recovery | 탭 닫기 → `Cmd+Shift+T` → 그대로 복원 |

## 구현 순서 (의존성 순, 작은 단위 commit)

1. **데이터 레이어**
   - `ProjectFileService` (read/write `.cutmaster`, atomic, suffix)
   - `WorkspaceDb` (스키마 v1)
   - 각각 Unit 테스트
2. **마이그레이션**
   - 옛 `project_db.db` → `~/Documents/Cutmaster/*.cutmaster` + recent 등록
   - 옛 DB는 read-only 보존
3. **상태 레이어**
   - `TabsNotifier` + `TabState`
   - `closedTabsProvider`, `recentFilesProvider`
   - `activeProjectProvider`
   - 기존 `currentProjectProvider` 호출 일괄 치환
4. **UI 레이어**
   - `TabItem` (정적 + 더블클릭 편집 + 닫기 X)
   - `TabBar` (가로 스크롤 + Reorderable)
   - `PlusButton` + 메뉴
   - `TopBar`에서 `ProjectDropdown` 제거 → `TabBar`
5. **단축키 / 컨텍스트 메뉴**
   - `Cmd+N/O/W/Shift+T/S/Tab` shortcut wiring
   - 우클릭 컨텍스트 메뉴
6. **마무리**
   - 외부 conflict 감지 (mtime 비교) → 충돌 사본 분기 저장
   - 누락 / 손상 파일 토스트
   - 옛 위젯 (`project_dropdown.dart`, `rename_project_dialog.dart`) 삭제
   - README / docs 업데이트
