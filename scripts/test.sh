#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/tests"
xcrun clang -fobjc-arc -fmodules -Wno-incompatible-pointer-types \
  -fmodules-cache-path="$ROOT/build/tests/module-cache" \
  -framework Cocoa -framework FinderSync \
  "$ROOT/tests/MenuTests.m" -o "$ROOT/build/tests/MenuTests"
"$ROOT/build/tests/MenuTests"
sed '/^final class SettingsWindowController/,$d' "$ROOT/src/Main.swift" > "$ROOT/build/tests/SettingsTests.swift"
cat "$ROOT/tests/SettingsTests.swift" >> "$ROOT/build/tests/SettingsTests.swift"
xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/build/tests/SettingsTests.swift" -o "$ROOT/build/tests/SettingsTests" -framework AppKit
"$ROOT/build/tests/SettingsTests"
xcrun swiftc -module-cache-path "$ROOT/build/tests/module-cache" \
  "$ROOT/src/FileMoveClipboard.swift" "$ROOT/tests/FileMoveTests.swift" \
  -o "$ROOT/build/tests/FileMoveTests"
"$ROOT/build/tests/FileMoveTests"
