# Windows .exe 빌드 + .zip 패키징.
#
# 사용법 (PowerShell):
#   .\scripts\build-windows.ps1                # pubspec.yaml의 version
#   .\scripts\build-windows.ps1 -Version v0.2  # 명시 버전
#   .\scripts\build-windows.ps1 -NoZip         # .exe 폴더만, zip 스킵
#
# 산출물:
#   build\windows\x64\runner\Release\          (.exe + DLL들)
#   release\cutmaster-<version>-windows.zip

param(
  [string]$Version = "",
  [switch]$NoZip
)

$ErrorActionPreference = "Stop"

# 프로젝트 루트로 이동
Set-Location (Join-Path $PSScriptRoot "..")

# --- 버전 결정 ---
if (-not $Version) {
  $line = (Select-String -Path "pubspec.yaml" -Pattern "^version:").Line
  $ver = ($line -replace "version:\s*", "" -replace "\+.*", "").Trim()
  $Version = "v$ver"
}
Write-Host "==> 버전: $Version"

# --- Flutter 점검 ---
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "flutter not found. Flutter SDK가 PATH에 있어야 합니다."
  exit 1
}
flutter --version | Select-Object -First 1

# --- 의존성 + 검사 + 테스트 ---
Write-Host "==> flutter pub get"
flutter pub get

Write-Host "==> flutter analyze (informational)"
flutter analyze
if ($LASTEXITCODE -ne 0) {
  Write-Warning "analyze에 issue 있음 — 빌드는 계속."
}

Write-Host "==> flutter test"
flutter test
if ($LASTEXITCODE -ne 0) {
  Write-Error "테스트 실패. 빌드 중단."
  exit 1
}

# --- 빌드 ---
Write-Host "==> flutter build windows --release"
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
  Write-Error "빌드 실패."
  exit 1
}

$ReleaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path $ReleaseDir)) {
  Write-Error "빌드 실패: $ReleaseDir 가 생성되지 않았습니다."
  exit 1
}
Write-Host "✅ .exe 빌드 완료: $ReleaseDir"

# --- ZIP 패키징 ---
if ($NoZip) {
  Write-Host "==> -NoZip: zip 패키징 스킵."
  exit 0
}

if (-not (Test-Path "release")) {
  New-Item -ItemType Directory -Path "release" | Out-Null
}

$ZipPath = "release\cutmaster-$Version-windows.zip"
if (Test-Path $ZipPath) {
  Write-Host "==> 기존 $ZipPath 삭제"
  Remove-Item $ZipPath -Force
}

Write-Host "==> Compress-Archive $ZipPath"
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -Force

# --- 결과 요약 ---
$Size = "{0:N1} MB" -f ((Get-Item $ZipPath).Length / 1MB)
Write-Host ""
Write-Host "✅ 완료"
Write-Host "   폴더 : $ReleaseDir"
Write-Host "   zip  : $ZipPath ($Size)"
Write-Host ""
Write-Host "친구한테 .zip 전달. 압축 풀고 cutmaster.exe 더블클릭."
Write-Host "SmartScreen 차단 시 '추가 정보' → '실행' 클릭."
