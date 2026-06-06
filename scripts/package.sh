#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
if [[ "$OUT" != /* ]]; then
  OUT="$ROOT/$OUT"
fi
PKGROOT="$ROOT/build/pkgroot"
SOURCE_STAGE="/private/tmp/AstraCreate-Finder-source-package"

"$ROOT/scripts/build.sh"

rm -rf "$OUT" "$PKGROOT"
mkdir -p "$OUT" "$PKGROOT/Applications"
COPYFILE_DISABLE=1 ditto --norsrc "$ROOT/build/AstraCreate.app" "$PKGROOT/Applications/AstraCreate.app"
xattr -cr "$PKGROOT" >/dev/null 2>&1 || true
find "$PKGROOT" -exec xattr -d com.apple.provenance {} \; >/dev/null 2>&1 || true

COPYFILE_DISABLE=1 pkgbuild \
  --root "$PKGROOT" \
  --scripts "$ROOT/packaging/scripts" \
  --identifier com.astracreate.finder.pkg \
  --version 2.14 \
  --install-location / \
  --filter '.*\._.*' \
  --filter '.*\.DS_Store' \
  "$OUT/AstraCreate-2.14.pkg"

rm -rf "$SOURCE_STAGE"
mkdir -p "$SOURCE_STAGE"
COPYFILE_DISABLE=1 ditto --norsrc "$ROOT" "$SOURCE_STAGE/AstraCreate-Finder"
rm -rf "$SOURCE_STAGE/AstraCreate-Finder/build" "$SOURCE_STAGE/AstraCreate-Finder/dist"
rm -f "$SOURCE_STAGE/AstraCreate-Finder/assets"/AppIconPreview*.png
rm -f "$SOURCE_STAGE/AstraCreate-Finder/assets"/logo-crop*.png
rm -f "$SOURCE_STAGE/AstraCreate-Finder/assets"/AppIconCrop*.png
rm -f "$SOURCE_STAGE/AstraCreate-Finder/assets"/AppIconClean*.png
rm -f "$SOURCE_STAGE/AstraCreate-Finder/assets"/AppIconSourceCropped.png

(cd "$SOURCE_STAGE" && COPYFILE_DISABLE=1 zip -qry "$OUT/AstraCreate-Finder-2.14-source.zip" "AstraCreate-Finder" \
  -x "*/.DS_Store")

echo "Package: $OUT/AstraCreate-2.14.pkg"
echo "Source:  $OUT/AstraCreate-Finder-2.14-source.zip"
