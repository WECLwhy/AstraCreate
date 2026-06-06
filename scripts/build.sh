#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/AstraCreate.app"
APPEX="$APP/Contents/PlugIns/AstraCreateFinderExtension.appex"
MODULE_CACHE="$BUILD/module-cache"

rm -rf "$APP" "$MODULE_CACHE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$BUILD" "$MODULE_CACHE"

cp "$ROOT/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$ROOT/ExtensionInfo.plist" "$APPEX/Contents/Info.plist"
cp "$ROOT/Resources/blank.pptx" "$APP/Contents/Resources/blank.pptx"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  cp "$ROOT/Resources/AppIcon.icns" "$ROOT/assets/AppIcon.icns"
else
  sips -c 700 700 --cropOffset -35 45 "$ROOT/Resources/SoftwareLogo.png" --out "$BUILD/AppIcon-cropped.png" >/dev/null
  sips -z 1024 1024 "$BUILD/AppIcon-cropped.png" --out "$BUILD/AppIcon.png" >/dev/null
  rm -rf "$BUILD/AppIcon.iconset"
  mkdir -p "$BUILD/AppIcon.iconset"
  sips -z 16 16 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_16x16.png" >/dev/null
  sips -z 32 32 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_32x32.png" >/dev/null
  sips -z 64 64 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_128x128.png" >/dev/null
  sips -z 256 256 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_256x256.png" >/dev/null
  sips -z 512 512 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
  xattr -cr "$BUILD/AppIcon.iconset" >/dev/null 2>&1 || true
  find "$BUILD/AppIcon.iconset" -exec xattr -d com.apple.provenance {} \; >/dev/null 2>&1 || true
  if ! iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
    sips -s format tiff "$BUILD/AppIcon.png" --out "$BUILD/AppIcon.tiff" >/dev/null
    tiff2icns "$BUILD/AppIcon.tiff" "$APP/Contents/Resources/AppIcon.icns"
  fi
  cp "$APP/Contents/Resources/AppIcon.icns" "$ROOT/assets/AppIcon.icns"
fi

env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/AstraCreate" \
  "$ROOT/src/Main.swift" \
  -framework AppKit

env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/AstraCreateHelper" \
  "$ROOT/src/Helper.swift" \
  -framework Foundation

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun clang \
  -target arm64-apple-macos13.0 \
  -isysroot "$SDKROOT" \
  -fobjc-arc \
  -fmodules \
  -framework Cocoa \
  -framework FinderSync \
  -Xlinker -e \
  -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/AstraCreateFinderExtension" \
  "$ROOT/src/FinderSyncObjC.m"

codesign --force --sign - --entitlements "$ROOT/Extension.entitlements" "$APPEX"
codesign --force --sign - "$APP"

echo "Built: $APP"
