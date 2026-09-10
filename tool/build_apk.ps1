# tool/build_apk.ps1
#
# Builds the release APK for sideloading onto a test device, with the Maps
# web-services key compiled in.
#
#   tool/build_apk.ps1
#   tool/build_apk.ps1 --split-per-abi     # extra args are forwarded to flutter
#
# This script exists because `flutter build apk --release` on its own produces
# a working, installable, *silently broken* APK. MapsConfig.apiKey is a
# compile-time String.fromEnvironment, so without
# --dart-define-from-file=dart_defines.json it compiles to the empty string and
# the build still succeeds. Venue search, the map picker's address lookup and
# the venue locator's directions then all fail on the device, while the map
# tiles keep drawing normally — the Maps SDK for Android key is a separate key
# injected from android/local.properties, so it is unaffected. That mix of
# working and broken maps reads like a Google outage and sends you looking in
# entirely the wrong place.
#
# The VS Code launch configurations already pass the flag, but they only cover
# `flutter run`. A build typed in a terminal inherits nothing from them.
#
# The Play Store bundle is a different, less frequent command and stays in the
# README: flutter build appbundle --release --dart-define-from-file=dart_defines.json

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$defines = Join-Path $repoRoot 'dart_defines.json'

# Checked before the build rather than after, because a release build takes
# minutes and the whole point is to not discover the problem on the phone.
if (-not (Test-Path $defines)) {
    # Write-Host rather than Write-Error: $ErrorActionPreference is Stop, so
    # Write-Error would throw and bury the instructions in a stack trace.
    Write-Host @"
dart_defines.json not found at $defines

It holds the Google Maps web-services key and is deliberately gitignored, so a
fresh clone will not have it. Create it from the tracked template:

    cp dart_defines.example.json dart_defines.json

then paste your key. See "First-time setup" in README.md.
"@ -ForegroundColor Red
    exit 1
}

$mapsApiKey = (Get-Content $defines -Raw | ConvertFrom-Json).MAPS_API_KEY

if ([string]::IsNullOrWhiteSpace($mapsApiKey)) {
    Write-Host @"
MAPS_API_KEY is missing or empty in $defines

Building now would produce an APK whose venue search, map-picker address lookup
and directions all fail on the device. Paste the web-services key and re-run.
"@ -ForegroundColor Red
    exit 1
}

Write-Host "Maps key found (length $($mapsApiKey.Length)). Building release APK..." -ForegroundColor Green

Push-Location $repoRoot
try {
    & flutter build apk --release --dart-define-from-file=dart_defines.json @args
    $buildExit = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($buildExit -ne 0) {
    Write-Host "flutter build apk failed with exit code $buildExit" -ForegroundColor Red
    exit $buildExit
}

Write-Host ""
Write-Host "Built build/app/outputs/flutter-apk/app-release.apk" -ForegroundColor Green
exit 0
