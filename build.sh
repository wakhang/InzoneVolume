#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/InzoneVolume.app"
mkdir -p "$APP/Contents/MacOS"
xcrun swiftc -O -target arm64-apple-macosx14.2 Sources/*.swift -o "$APP/Contents/MacOS/InzoneVolume" -framework AppKit -framework CoreAudio -framework ApplicationServices -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>InzoneVolume</string>
<key>CFBundleIdentifier</key><string>com.wak.InzoneVolume</string>
<key>CFBundleName</key><string>InzoneVolume</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.2</string>
<key>NSAudioCaptureUsageDescription</key><string>INZONE Buds 출력의 소프트웨어 볼륨을 조절하려면 시스템 오디오 녹음 권한이 필요합니다.</string>
</dict></plist>
PLIST
codesign -s - --force --deep "$APP"
echo "설치 완료: $APP"
