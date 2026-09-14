#!/bin/zsh
set -euo pipefail
setopt NULL_GLOB

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
if [[ "$OUT" != /* ]]; then
  OUT="$ROOT/$OUT"
fi
PKGROOT="$ROOT/build/pkgroot"
SOURCE_STAGE="$(mktemp -d "${TMPDIR:-/private/tmp}/AstraCreate-source.XXXXXX")"
trap 'rm -rf "$SOURCE_STAGE"' EXIT

"$ROOT/scripts/build.sh"

rm -rf "$PKGROOT"
mkdir -p "$OUT" "$PKGROOT/Applications"
COPYFILE_DISABLE=1 ditto --norsrc "$ROOT/build/AstraCreate.app" "$PKGROOT/Applications/AstraCreate.app"
xattr -cr "$PKGROOT" >/dev/null 2>&1 || true
find "$PKGROOT" -exec xattr -d com.apple.provenance {} \; >/dev/null 2>&1 || true

COPYFILE_DISABLE=1 pkgbuild \
  --root "$PKGROOT" \
  --scripts "$ROOT/packaging/scripts" \
  --identifier com.astracreate.finder.pkg \
  --version 2.16 \
  --install-location / \
  --filter '.*\._.*' \
  --filter '.*\.DS_Store' \
  "$OUT/AstraCreate-2.16.pkg"

mkdir -p "$SOURCE_STAGE/AstraCreate-Finder"
# Copy release inputs explicitly so packaging also works from a source ZIP.
# Never include repository metadata, build caches or local configuration.
for entry in src Resources assets scripts packaging tests AppInfo.plist ExtensionInfo.plist Extension.entitlements README.md CHANGELOG.md RELEASE_NOTES.md PRIVACY.md LICENSE .gitignore; do
  COPYFILE_DISABLE=1 ditto --norsrc "$ROOT/$entry" "$SOURCE_STAGE/AstraCreate-Finder/$entry"
done

(cd "$SOURCE_STAGE" && COPYFILE_DISABLE=1 zip -qyrX "$SOURCE_STAGE/source.zip" "AstraCreate-Finder" \
  -x "*/.DS_Store" "*/._*" "*/.env" "*/.env.*" "*.log" "*.pem" "*.key" "*.p12" "*/clipboard.json" "*/settings.json")

# Replace the archive instead of updating it, so removed private entries cannot survive.
mv -f "$SOURCE_STAGE/source.zip" "$OUT/AstraCreate-Finder-2.16-source.zip"

echo "Package: $OUT/AstraCreate-2.16.pkg"
echo "Source:  $OUT/AstraCreate-Finder-2.16-source.zip"

(cd "$OUT" && shasum -a 256 AstraCreate-2.16.pkg AstraCreate-Finder-2.16-source.zip > AstraCreate-2.16-SHA256SUMS.txt)
