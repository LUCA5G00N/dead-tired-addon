#!/bin/sh
# Build the release zip (copied in shape from rc3's tools/package.sh). From the repo root:
#   sh tools/package.sh
#   dist/DeadTired-<version>.zip: DeadTired/ from this checkout, without tests/. It unzips to
#   Interface\AddOns\DeadTired\DeadTired.toc. The version is read from the .toc.
# Then unzips it to a scratch folder and diff -r's it against the checkout (tests/ excluded).
set -e
[ -f DeadTired/DeadTired.toc ] || { echo "package: run from the repo root"; exit 2; }
command -v zip >/dev/null 2>&1 || { echo "package: zip not found"; exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "package: unzip not found"; exit 2; }
VERSION=$(sed -n 's/^## Version: *//p' DeadTired/DeadTired.toc | tr -d '\r')
NAME="DeadTired-$VERSION.zip"
ROOT=$(pwd)
mkdir -p dist
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/stage"
cp -R DeadTired "$TMP/stage/"
rm -rf "$TMP/stage/DeadTired/tests"
rm -f "dist/$NAME"
(cd "$TMP/stage" && zip -q -X -r "$ROOT/dist/$NAME" DeadTired)
echo "== dist/$NAME ($(wc -c < "dist/$NAME" | tr -d ' ') bytes)"
zip -sf "dist/$NAME" | sed -n '2,$p' | grep -v '^Total' | sed 's/^ */   /'

mkdir -p "$TMP/check"
(cd "$TMP/check" && unzip -q "$ROOT/dist/$NAME")
if diff -r -x tests "$TMP/check/DeadTired" DeadTired; then echo "diff -r: clean"; else echo "diff -r: DIFFERS"; exit 1; fi
