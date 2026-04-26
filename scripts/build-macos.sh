#!/usr/bin/env bash
# macOS .app 빌드 + .dmg 패키징.
#
# 사용법:
#   ./scripts/build-macos.sh             # pubspec.yaml의 version으로 빌드
#   ./scripts/build-macos.sh v0.2.1      # 명시 버전으로 빌드 (.dmg 파일명에 사용)
#   ./scripts/build-macos.sh --no-dmg    # .app만 빌드, .dmg 패키징 스킵
#
# 산출물:
#   build/macos/Build/Products/Release/cutmaster.app
#   release/cutmaster-<version>-macos.dmg

set -euo pipefail

# 프로젝트 루트로 이동 (스크립트 위치 기준)
cd "$(dirname "$0")/.."

# --- 인자 파싱 ---
VERSION=""
SKIP_DMG=0
for arg in "$@"; do
  case "$arg" in
    --no-dmg)   SKIP_DMG=1 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)          VERSION="$arg" ;;
  esac
done

# 버전 미지정 시 pubspec.yaml에서 추출 (예: "0.1.0+1" → "0.1.0")
if [[ -z "$VERSION" ]]; then
  VERSION="v$(grep -E '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')"
fi

echo "==> 버전: $VERSION"

# --- Flutter 환경 점검 ---
if ! command -v flutter >/dev/null 2>&1; then
  echo "❌ flutter not found. Flutter SDK가 PATH에 있어야 합니다." >&2
  exit 1
fi

flutter --version | head -1

# --- 의존성 ---
echo "==> flutter pub get"
flutter pub get

# --- 정적 분석 (실패해도 빌드는 진행하되, 경고로만) ---
echo "==> flutter analyze (informational)"
flutter analyze || echo "⚠️  analyze에 issue 있음 — 빌드는 계속."

# --- 테스트 (실패하면 중단) ---
echo "==> flutter test"
flutter test

# --- 빌드 ---
echo "==> flutter build macos --release"
flutter build macos --release

APP_PATH="build/macos/Build/Products/Release/cutmaster.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 빌드 실패: $APP_PATH 가 생성되지 않았습니다." >&2
  exit 1
fi

echo "✅ .app 빌드 완료: $APP_PATH"

# --- DMG 패키징 ---
if [[ "$SKIP_DMG" -eq 1 ]]; then
  echo "==> --no-dmg: .dmg 패키징 스킵."
  exit 0
fi

mkdir -p release
DMG_PATH="release/cutmaster-${VERSION}-macos.dmg"

if [[ -f "$DMG_PATH" ]]; then
  echo "==> 기존 $DMG_PATH 삭제"
  rm -f "$DMG_PATH"
fi

echo "==> hdiutil create $DMG_PATH"
hdiutil create \
  -volname "Cutmaster" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# --- 결과 요약 ---
SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "✅ 완료"
echo "   .app : $APP_PATH"
echo "   .dmg : $DMG_PATH ($SIZE)"
echo ""
echo "친구한테 .dmg 파일 전달하세요. (서명 없는 앱이라 첫 실행 시 우클릭 → 열기)"
