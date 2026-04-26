#!/usr/bin/env bash
# macOS / Linux에서 Windows 빌드 만들기.
# (Flutter는 cross-compile 미지원 → GitHub Actions의 windows-latest runner로 빌드)
#
# 동작:
#   1. 현재 main에 commit된 상태 확인 (push 필요)
#   2. gh workflow run으로 Build Windows workflow 트리거
#   3. 새 실행이 끝날 때까지 watch (성공/실패 노출)
#   4. artifact (.zip) 다운로드 → release/cutmaster-<version>-windows.zip
#
# 사용법:
#   ./scripts/build-windows.sh              # 현재 main HEAD로 빌드
#   ./scripts/build-windows.sh v0.2         # 다운받은 zip 파일명에 버전 반영
#
# 사전 요구:
#   - gh CLI (`brew install gh`)
#   - gh auth login 완료
#   - 현재 commit이 origin/main에 push된 상태

set -euo pipefail

cd "$(dirname "$0")/.."

# --- 인자 파싱 ---
VERSION=""
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) VERSION="$arg" ;;
  esac
done
if [[ -z "$VERSION" ]]; then
  VERSION="v$(grep -E '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//; s/+.*//')"
fi

# --- 사전 점검 ---
if ! command -v gh >/dev/null 2>&1; then
  echo "❌ gh CLI not found. 설치: brew install gh" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "❌ gh 인증 안 됨. 실행: gh auth login" >&2
  exit 1
fi

# 현재 commit이 origin에 push 됐는지 확인
LOCAL_HEAD=$(git rev-parse HEAD)
if ! git fetch origin --quiet; then
  echo "⚠️  git fetch 실패 — 네트워크 문제일 수 있음. 계속 진행."
fi
REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null || echo "")
if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
  echo "⚠️  로컬 HEAD($LOCAL_HEAD)와 origin/main($REMOTE_HEAD)가 다릅니다."
  echo "   GitHub Actions는 origin/main을 빌드하므로, 최신 변경사항을 push 후 다시 실행하세요."
  read -p "그래도 진행? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

# --- workflow 트리거 ---
echo "==> Build Windows workflow 트리거..."
gh workflow run build-windows.yml

# 새 run이 등록될 때까지 잠시 대기 (gh API에 visibility 늦을 수 있음)
sleep 5

RUN_ID=$(gh run list --workflow=build-windows.yml --limit=1 --json databaseId --jq '.[0].databaseId')
if [[ -z "$RUN_ID" ]]; then
  echo "❌ 새 run을 찾지 못함." >&2
  exit 1
fi
echo "==> Run ID: $RUN_ID"
echo "    URL: https://github.com/feelpass/desktop-cutmaster/actions/runs/$RUN_ID"

# --- 완료까지 watch (실패 시 exit 1) ---
echo "==> 빌드 진행 중... (보통 5~10분)"
gh run watch "$RUN_ID" --exit-status

# --- artifact 다운로드 ---
echo "==> Artifact 다운로드..."
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
gh run download "$RUN_ID" -D "$TMPDIR"

ZIP=$(find "$TMPDIR" -name "cutmaster-windows.zip" -type f | head -1)
if [[ -z "$ZIP" ]]; then
  echo "❌ artifact 안에서 cutmaster-windows.zip을 찾지 못함." >&2
  echo "   다운로드 결과: $TMPDIR" >&2
  ls -laR "$TMPDIR" >&2
  exit 1
fi

mkdir -p release
DEST="release/cutmaster-${VERSION}-windows.zip"
mv "$ZIP" "$DEST"

SIZE=$(du -h "$DEST" | cut -f1)
echo ""
echo "✅ 완료"
echo "   .zip : $DEST ($SIZE)"
echo ""
echo "친구한테 .zip 전달. 압축 풀고 cutmaster.exe 더블클릭."
echo "SmartScreen 차단 시 '추가 정보' → '실행' 클릭."
