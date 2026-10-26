#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/build/AppIcon.iconset"
mkdir -p "$ICONSET"
# Only resize the approved source. Keep composition and transparency intact.
for spec in '16 icon_16x16' '32 icon_16x16@2x' '32 icon_32x32' '64 icon_32x32@2x' '128 icon_128x128' '256 icon_128x128@2x' '256 icon_256x256' '512 icon_256x256@2x' '512 icon_512x512' '1024 icon_512x512@2x'; do
  size="${spec%% *}"
  name="${spec#* }"
  sips -z "$size" "$size" "$ROOT/assets/AppIconSource1024.png" --out "$ICONSET/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
cp "$ROOT/Resources/AppIcon.icns" "$ROOT/assets/AppIcon.icns"
