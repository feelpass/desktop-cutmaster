# Cutmaster

합판 재단 최적화 데스크톱 앱.

좌측 패널에서 자재와 부품을 입력하고 ▶ 계산 버튼을 누르면 우측에 최적 재단 도면이 표시됩니다. PNG로 내보내서 작업장에서 인쇄해 사용 가능.

## 핵심 기능

- 한국 합판 표준 규격 프리셋 (2440×1220 12T/15T/18T, MDF 9T/18T)
- 2D guillotine cutting + First Fit Decreasing 알고리즘
- 톱날 두께(kerf) 반영, 결방향 고정 옵션
- 효율% 자동 계산
- 프로젝트 자동 저장 (입력 변경 후 500ms)
- macOS / Windows 데스크톱

## 빌드 / 설치

- macOS: [docs/INSTALL_MACOS.md](docs/INSTALL_MACOS.md)
- Windows: [docs/INSTALL_WINDOWS.md](docs/INSTALL_WINDOWS.md)

## 개발

```bash
flutter pub get
flutter test
flutter run -d macos
```

## 구조

- `lib/domain/` — 모델 + 솔버 (FFD 2D guillotine)
- `lib/data/` — sqflite_common_ffi 영속화
- `lib/ui/` — Material 3 + Riverpod, 단일 MainScreen + 좌우 split

## Stack

- Flutter 3.24+ / Dart 3.5+
- Riverpod 2.5+
- sqflite_common_ffi 2.3+
- 한국어 ARB
