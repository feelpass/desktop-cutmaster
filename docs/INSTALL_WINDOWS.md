# Windows 설치 가이드

## yp가 빌드할 때

Windows 머신 또는 VM(UTM/Parallels) 필요.

### Windows 환경 셋업 (1회)

1. Flutter SDK 설치 (https://docs.flutter.dev/get-started/install/windows)
2. Visual Studio Build Tools 설치 ("Desktop development with C++" workload)
3. 프로젝트 폴더에서 `flutter doctor`로 환경 확인

### 빌드

```cmd
cd path\to\cutmaster
flutter build windows --release
```

산출물: `build\windows\x64\runner\Release\` 폴더 전체

### 배포 (간단 zip)

```cmd
cd build\windows\x64\runner\Release
powershell Compress-Archive -Path .\* -DestinationPath cutmaster-v0.1-windows.zip
```

이 zip을 친구한테 전달.

### 배포 (.msi 정식)

Inno Setup (https://jrsoftware.org/isinfo.php) 또는 MSIX 패키징 (https://docs.flutter.dev/deployment/windows#msix-packaging).

## 친구가 받았을 때

### 설치 (zip 버전)

1. `cutmaster-v0.1-windows.zip` 압축 해제
2. 압축 해제한 폴더 안의 `cutmaster.exe` 더블클릭

### 첫 실행 (SmartScreen 우회)

서명되지 않은 앱이라 Windows Defender가 차단할 수 있음.

1. "Windows에서 PC를 보호했습니다" 메시지 → "추가 정보" 클릭
2. "실행" 버튼 클릭

### 시작 메뉴 등록 (선택)

1. `cutmaster.exe` 우클릭 → "시작 화면에 고정" 또는 바로가기 만들기

## 사용법

INSTALL_MACOS.md의 사용법 섹션 참고 (동일).

## 문제 해결

- **MSVCP140.dll 없음 오류**: Microsoft Visual C++ Redistributable 설치 (https://aka.ms/vs/17/release/vc_redist.x64.exe).
- **부품이 미배치로 표시됨**: 부품이 시트보다 크거나, 결방향 고정 시 회전 못해서 안 들어가는 경우.
