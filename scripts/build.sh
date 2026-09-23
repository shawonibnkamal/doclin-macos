#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD_DIR="${DOCLIN_BUILD_DIR:-$ROOT/.build}"
DIST="${DOCLIN_DIST_DIR:-$ROOT/dist}"
APP="$DIST/Doclin.app"
mkdir -p "$DIST"
swift build --scratch-path "$BUILD_DIR" -c release --product Doclin
BIN="$(swift build --scratch-path "$BUILD_DIR" -c release --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Doclin" "$APP/Contents/MacOS/Doclin"
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    swift build --scratch-path "$BUILD_DIR" -c release --product Doclin --triple x86_64-apple-macosx13.0
    INTEL_BIN="$(swift build --scratch-path "$BUILD_DIR" -c release --triple x86_64-apple-macosx13.0 --show-bin-path)"
    lipo -create "$BIN/Doclin" "$INTEL_BIN/Doclin" -output "$APP/Contents/MacOS/Doclin"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Doclin</string>
<key>CFBundleIdentifier</key><string>dev.doclin.app</string>
<key>CFBundleName</key><string>Doclin</string>
<key>CFBundleDisplayName</key><string>Doclin</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.5</string>
<key>CFBundleVersion</key><string>13</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><false/>
<key>NSMicrophoneUsageDescription</key><string>Doclin records your voice only when you start dictation.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Doclin converts your speech into text using on-device recognition.</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>Doclin</string>
<key>NSHumanReadableCopyright</key><string>Doclin · doclin.dev</string>
</dict></plist>
PLIST
ICONSET="$BUILD_DIR/Doclin.iconset"
mkdir -p "$ICONSET"
swift scripts/icon.swift "$BUILD_DIR/icon.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$BUILD_DIR/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Doclin.icns"
# Bundle the offline neural voice. No runtime downloads or package managers.
mkdir -p "$APP/Contents/Frameworks" "$APP/Contents/Resources/ThirdParty"
cp "$ROOT"/vendor/voice/*LICENSE "$ROOT"/vendor/voice/*COPYING "$ROOT"/vendor/voice/*NOTICES.txt "$ROOT/vendor/voice/README.md" "$APP/Contents/Resources/ThirdParty/"
ditto "$ROOT/vendor/voice/sources" "$APP/Contents/Resources/ThirdParty/sources"
cp "$ROOT/scripts/voice/main.c" "$APP/Contents/Resources/ThirdParty/doclin-voice.c"
cp "$ROOT"/vendor/voice/lib/*.dylib "$APP/Contents/Frameworks/"
ditto "$ROOT/vendor/voice/model" "$APP/Contents/Resources/VoiceModel"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 -Wno-deprecated-declarations -I "$ROOT/vendor/voice/include" "$ROOT/scripts/voice/main.c" -L "$ROOT/vendor/voice/lib" -lsherpa-onnx-c-api -Wl,-rpath,@executable_path/../Frameworks -o "$APP/Contents/MacOS/doclin-voice"
for library in "$APP"/Contents/Frameworks/*.dylib; do
    codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$library"
done
if [[ "${SIGN_IDENTITY:--}" == "-" ]]; then
    # Ad-hoc identities have no Team ID for hardened library validation.
    codesign --force --sign - "$APP/Contents/MacOS/doclin-voice"
else
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/doclin-voice"
fi
# Ad-hoc signing runs locally; set SIGN_IDENTITY for a Developer ID distribution build.
codesign --force --options runtime --entitlements "$ROOT/scripts/entitlements.plist" --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Doclin-0.4.5-mac.zip"
echo "Built: $APP"
