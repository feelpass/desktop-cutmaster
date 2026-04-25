# macOS 설치 가이드

## yp가 빌드할 때

### 사전 셋업 (1회만)

CocoaPods가 깨진 상태이므로 한 번 재설치 필요:

```bash
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup
```

또는 Homebrew로:

```bash
brew install cocoapods
```

### 빌드

```bash
cd ~/workspace/desktop/cutmaster
flutter build macos --release
```

산출물: `build/macos/Build/Products/Release/cutmaster.app`

### .dmg 패키징

```bash
hdiutil create \
  -volname Cutmaster \
  -srcfolder build/macos/Build/Products/Release/cutmaster.app \
  -ov -format UDZO \
  build/cutmaster-v0.1.dmg
```

이 .dmg를 친구한테 전달.

## 친구가 받았을 때

### 설치

1. 받은 `cutmaster-v0.1.dmg` 더블클릭
2. 열린 창에서 `cutmaster.app` 아이콘을 `/Applications` 폴더로 드래그

### 첫 실행 (unsigned app 우회)

서명되지 않은 앱이라 macOS가 차단할 수 있음. 한 번만 우회하면 됨.

1. `/Applications/cutmaster.app` 우클릭 → "열기"
2. "확인되지 않은 개발자가 만든 앱..." 경고 → "열기" 버튼 클릭

또는 시스템 환경설정 → 개인정보 보호 및 보안 → 보안 섹션 → "이대로 열기" 버튼.

### 두 번째 실행부터

그냥 Launchpad나 Spotlight에서 "cutmaster" 검색해 클릭.

## 사용법

### 1. 자재 추가
- 좌측 패널 "자재" 섹션 펼침
- "프리셋" 버튼 → 합판 규격 선택 (2440×1220 12T 등)
- 또는 "행 추가"로 직접 가로/세로/수량/라벨 입력

### 2. 부품 입력
- 좌측 패널 "부품" 섹션 펼침
- "행 추가"로 자르고 싶은 부품의 가로/세로/수량/라벨 입력
- Tab 키로 다음 셀, Enter로 확정

### 3. 옵션 조정
- 좌측 패널 "옵션" 섹션
- 톱날 두께(kerf): 보통 3mm
- 결방향 고정: 합판 결 방향 유지하려면 ON
- 부품 라벨 표시: 결과 도면에 라벨 보이려면 ON
- 단일 시트 사용: 한 장으로만 자르려면 ON

### 4. 계산
- 상단 우측 ▶ 계산 버튼 (또는 Cmd+Enter)
- 우측 패널에 시트별 도면 + 효율% 표시

### 5. PNG 내보내기
- 결과 화면 우상단 "PNG 내보내기" 버튼
- 저장 폴더 선택 → 시트별로 .png 파일 저장됨

## 문제 해결

- **"앱이 손상되었습니다" 메시지**: `xattr -cr /Applications/cutmaster.app` 실행 후 다시 시도.
- **결과가 안 나옴**: 자재와 부품 둘 다 1개 이상 입력했는지 확인.
- **부품이 미배치로 표시됨**: 부품이 시트보다 크거나, 결방향 고정 시 회전 못해서 안 들어가는 경우. 옵션 조정 시도.
