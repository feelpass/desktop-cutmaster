# Cutmaster

합판 재단 최적화 데스크톱 앱.

좌측 패널에서 자재와 부품을 입력하고 ▶ 계산 버튼을 누르면 우측에 최적 재단 도면이 표시됩니다. PNG로 내보내서 작업장에서 인쇄해 사용 가능.

## 핵심 기능

- 한국 합판 표준 규격 프리셋 (2440×1220 12T/15T/18T, MDF 9T/18T)
- 2D guillotine cutting + First Fit Decreasing 알고리즘
- 톱날 두께(kerf) 반영, 결방향 고정 옵션
- 효율% 자동 계산
- **멀티 탭 워크스페이스** — 여러 프로젝트를 탭으로 동시에 열기, 드래그로 순서 바꾸기
- **`.cutmaster` 파일 단위 저장** — Finder/탐색기에서 직접 다루고 클라우드 동기화 가능
- 프로젝트 자동 저장 (입력 변경 후 500ms debounce, atomic write)
- 마지막 세션 복원 + 닫은 탭 복원
- macOS / Windows 데스크톱

## 멀티 탭 사용법

- **새 프로젝트**: 탭바 끝의 `+` 버튼 → `[새 프로젝트]`
- **저장된 프로젝트 열기**: `+` 버튼 → `[파일에서 열기...]` 또는 `--- 최근 ---` 목록
- **이름 변경**: 탭 이름을 더블클릭 (저장된 탭은 파일도 함께 rename)
- **탭 순서 바꾸기**: 탭을 길게 눌러 드래그
- **우클릭 메뉴**: 이름 변경 / 복사본 만들기 / Finder에서 보기 / 다른 이름으로 저장 / 닫기 / 다른 탭 모두 닫기

## 키보드 단축키

| 단축키 | 동작 |
|---|---|
| `Cmd/Ctrl + N` | 새 untitled 탭 |
| `Cmd/Ctrl + O` | 파일 열기 다이얼로그 |
| `Cmd/Ctrl + W` | 현재 탭 닫기 |
| `Cmd/Ctrl + Shift + T` | 방금 닫은 탭 복원 |
| `Cmd/Ctrl + Tab` | 다음 탭으로 이동 |
| `Cmd/Ctrl + S` | 저장 (untitled는 첫 저장 다이얼로그) |

## 파일 위치

- 프로젝트 파일: `~/Documents/Cutmaster/<name>.cutmaster` (사람이 읽을 수 있는 JSON)
- 워크스페이스 메타 (열린 탭, 최근 파일, 닫힌 탭): `~/Library/Application Support/cutmaster/workspace.db` (macOS) — Windows는 동등 위치
- Untitled 자동 백업: `~/Library/Application Support/cutmaster/autosave/`

옛 버전 사용자: 첫 실행 시 기존 `cutmaster.db`의 모든 프로젝트가 자동으로 `~/Documents/Cutmaster/`에 export됩니다.

## 빌드 / 설치

- macOS: [docs/INSTALL_MACOS.md](docs/INSTALL_MACOS.md)
- Windows: [docs/INSTALL_WINDOWS.md](docs/INSTALL_WINDOWS.md)

### Windows 자동 빌드 (GitHub Actions)

- `git tag v0.x && git push --tags` → Windows runner가 자동 빌드 → Releases 페이지에 `cutmaster-windows.zip` 업로드.
- Actions 탭 → "Build Windows" → "Run workflow"로 수동 트리거도 가능.

## 개발

```bash
flutter pub get
flutter test
flutter run -d macos
```

## 구조

- `lib/domain/` — 모델 + 솔버 (FFD 2D guillotine)
- `lib/data/file/` — `.cutmaster` JSON 파일 IO (atomic write, mtime 충돌 감지)
- `lib/data/local/` — workspace SQLite (열린 탭, 최근 파일, 닫힌 탭)
- `lib/data/migration/` — 옛 ProjectDb → 파일 마이그레이션
- `lib/ui/providers/` — Riverpod (`tabsProvider`, `activeProjectProvider` 등)
- `lib/ui/widgets/` — Material 3 위젯 (TabBar, TabItem, PlusButton, ...)

## Stack

- Flutter 3.24+ / Dart 3.5+
- Riverpod 2.5+
- sqflite_common_ffi 2.3+
- file_picker 8+
- 한국어 ARB
