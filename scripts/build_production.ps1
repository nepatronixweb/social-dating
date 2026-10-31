# Production-shaped release binaries. Does not enable debug mocks.
# Host comes from API_BASE_URL (default: local API). Do not commit secrets.
# SMS, card payments, push, CDN and payouts are still not wired.

param(
    [string]$ApiBaseUrl = "http://localhost:5088"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    throw "API_BASE_URL is required for a production build."
}

$defines = @(
    "--dart-define=APP_ENV=production",
    "--dart-define=DATA_SOURCE=api",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=API_NETWORK=true"
)

Write-Host "Publishing API (Release)..."
dotnet publish "backend/src/SocialDating.Api/SocialDating.Api.csproj" -c Release -o "build/api-release"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building Flutter web (Release)..."
flutter build web --release @defines
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path "windows") {
    Write-Host "Building Flutter Windows (Release)..."
    flutter build windows --release @defines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host "Building Flutter Android APK (Release)..."
flutter build apk --release --obfuscate --split-debug-info=build/symbols @defines
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Android APK build failed. Web and API artifacts are still in build/."
}

Write-Host "Done. Artifacts:"
Write-Host "  API:      build/api-release"
Write-Host "  Web:      build/web"
if (Test-Path "windows") {
    Write-Host "  Windows:  build/windows/x64/runner/Release"
}
Write-Host "  Android:  build/app/outputs/flutter-apk/app-release.apk"
Write-Host "Pointed at $ApiBaseUrl. This is not a store submission: SMS, card checkout, push and payouts are still off."
