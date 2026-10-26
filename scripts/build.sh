#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Relative compiler inputs also keep runtime source-location strings anonymous.
cd "$ROOT"
BUILD="$ROOT/build"
APP="$BUILD/AstraCreate.app"
APPEX="$APP/Contents/PlugIns/AstraCreateFinderExtension.appex"
MODULE_CACHE="$BUILD/module-cache"

ASTRA_APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/AppInfo.plist")"
ASTRA_EXTENSION_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/ExtensionInfo.plist")"
ASTRA_APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/AppInfo.plist")"
ASTRA_EXTENSION_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/ExtensionInfo.plist")"
if [[ "$ASTRA_APP_VERSION" != "$ASTRA_EXTENSION_VERSION" || "$ASTRA_APP_BUILD" != "$ASTRA_EXTENSION_BUILD" ]]; then
  echo "App and Finder extension versions must match before building." >&2
  exit 1
fi

rm -rf "$APP" "$MODULE_CACHE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$BUILD" "$MODULE_CACHE"

cp "$ROOT/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$ROOT/ExtensionInfo.plist" "$APPEX/Contents/Info.plist"
cp "$ROOT/Resources/blank.pptx" "$APP/Contents/Resources/blank.pptx"
cp "$ROOT/Resources/FrostedBackdrop.png" "$APP/Contents/Resources/FrostedBackdrop.png"

"$ROOT/scripts/build-icon.sh"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -file-prefix-map "$ROOT=." -debug-prefix-map "$ROOT=." \
  -o "$APP/Contents/MacOS/AstraCreate" \
  src/SourceFileTemplates.swift src/Main.swift src/FileMoveClipboard.swift src/FinderIntegration.swift src/Diagnostics.swift src/SettingsAppearance.swift src/AppearancePreferences.swift src/GitHubUpdater.swift src/UpdateUI.swift \
  -framework AppKit -framework FinderSync

env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -file-prefix-map "$ROOT=." -debug-prefix-map "$ROOT=." \
  -o "$APP/Contents/MacOS/AstraCreateHelper" \
  src/SourceFileTemplates.swift src/Helper.swift src/Diagnostics.swift \
  -framework Foundation

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
env CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun clang \
  -target arm64-apple-macos13.0 \
  "-ffile-prefix-map=$ROOT=." "-fdebug-prefix-map=$ROOT=." \
  -isysroot "$SDKROOT" \
  -fobjc-arc \
  -fmodules \
  -framework Cocoa \
  -framework FinderSync \
  -Xlinker -e \
  -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/AstraCreateFinderExtension" \
  src/FinderSyncObjC.m

codesign --force --sign - --entitlements "$ROOT/Extension.entitlements" "$APPEX"
codesign --force --sign - "$APP"

echo "Built: $APP"
