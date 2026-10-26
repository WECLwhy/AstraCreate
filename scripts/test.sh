#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/tests"
xcrun clang -target arm64-apple-macos13.0 -isysroot "$(xcrun --sdk macosx --show-sdk-path)" -fobjc-arc -fmodules -Wno-incompatible-pointer-types \
  -fmodules-cache-path="$ROOT/build/tests/module-cache" \
  -framework Cocoa -framework FinderSync \
  "$ROOT/tests/MenuTests.m" -o "$ROOT/build/tests/MenuTests"
"$ROOT/build/tests/MenuTests"
mkdir -p "$ROOT/build/tests/settings"
sed '/^final class SettingsWindowController/,$d' "$ROOT/src/Main.swift" > "$ROOT/build/tests/settings/main.swift"
cat "$ROOT/tests/SettingsTests.swift" >> "$ROOT/build/tests/settings/main.swift"
xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/SourceFileTemplates.swift" "$ROOT/build/tests/settings/main.swift" "$ROOT/src/Diagnostics.swift" "$ROOT/src/AppearancePreferences.swift" -o "$ROOT/build/tests/SettingsTests" -framework AppKit -framework FinderSync
"$ROOT/build/tests/SettingsTests"
xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/FileMoveClipboard.swift" "$ROOT/tests/FileMoveTests.swift" \
  -o "$ROOT/build/tests/FileMoveTests"
"$ROOT/build/tests/FileMoveTests"

python3 "$ROOT/tests/DocxTests.py"

xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/FinderIntegration.swift" "$ROOT/src/Diagnostics.swift" "$ROOT/tests/FinderIntegrationTests.swift" \
  -o "$ROOT/build/tests/FinderIntegrationTests"
"$ROOT/build/tests/FinderIntegrationTests"
python3 "$ROOT/tests/InstallerTests.py"

xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/Diagnostics.swift" "$ROOT/tests/DiagnosticsTests.swift" \
  -o "$ROOT/build/tests/DiagnosticsTests"
"$ROOT/build/tests/DiagnosticsTests"
xcrun clang -fobjc-arc -framework Foundation \
  "$ROOT/tests/ExtensionDiagnosticsTests.m" -o "$ROOT/build/tests/ExtensionDiagnosticsTests"
"$ROOT/build/tests/ExtensionDiagnosticsTests"

xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/SettingsAppearance.swift" "$ROOT/src/AppearancePreferences.swift" "$ROOT/tests/SettingsAppearanceTests.swift" \
  -framework AppKit -o "$ROOT/build/tests/SettingsAppearanceTests"
"$ROOT/build/tests/SettingsAppearanceTests"

xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/GitHubUpdater.swift" "$ROOT/tests/UpdaterTests.swift" \
  -o "$ROOT/build/tests/UpdaterTests"
"$ROOT/build/tests/UpdaterTests"


xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/SourceFileTemplates.swift" "$ROOT/tests/SourceFileTests.swift" \
  -o "$ROOT/build/tests/SourceFileTests"
"$ROOT/build/tests/SourceFileTests"

python3 "$ROOT/tests/DeveloperRoutingTests.py"
