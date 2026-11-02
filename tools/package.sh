#!/bin/sh
# Build the release zips (dt_release, Q4). Run from the repo root: sh tools/package.sh
# Needs zip (and git, to read the card-1 and probe folders from their branches).
#   dist/DeadTired-0.1.0-rc1.zip      DeadTired/ from this checkout, without tests/
#   dist/DeadTired-0.1.0-card1.zip    DeadTired/ from card/dt_foundation alone, without tests/
#   dist/DeadTiredProbe-0.1.0.zip     DeadTiredProbe/ from card/dt_probe, without tests/
# Each zip unzips to Interface\AddOns\<Folder>\<Folder>.toc. Refs can be overridden:
#   CARD1_REF=origin/card/dt_foundation PROBE_REF=origin/card/dt_probe sh tools/package.sh
set -e
[ -f DeadTired/DeadTired.toc ] || { echo "package: run from the repo root"; exit 2; }
command -v zip >/dev/null 2>&1 || { echo "package: zip not found"; exit 2; }
CARD1_REF="${CARD1_REF:-origin/card/dt_foundation}"
PROBE_REF="${PROBE_REF:-origin/card/dt_probe}"
ROOT=$(pwd)
mkdir -p dist
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# stage <ref or "."> <folder> <stage dir>: the folder as it is at ref (or in this checkout),
# minus tests/
stage() {
  mkdir -p "$3"
  if [ "$1" = "." ]; then
    cp -R "$2" "$3/"
  else
    GIT_INDEX_FILE="$TMP/index" git --work-tree="$3" read-tree "$1"
    GIT_INDEX_FILE="$TMP/index" git --work-tree="$3" checkout-index -a -f --prefix="$3/"
    rm -f "$TMP/index"
    # keep only the folder asked for
    find "$3" -mindepth 1 -maxdepth 1 ! -name "$2" -exec rm -rf {} +
  fi
  rm -rf "$3/$2/tests"
}

pack() {   # pack <zip name> <stage dir> <folder>
  rm -f "dist/$1"
  (cd "$2" && zip -q -X -r "$ROOT/dist/$1" "$3")
  echo "== dist/$1 ($(wc -c < "dist/$1" | tr -d ' ') bytes)"
  zip -sf "dist/$1" | sed -n '2,$p' | grep -v '^Total' | sed 's/^ */   /'
}

stage . DeadTired "$TMP/rc1"
pack DeadTired-0.1.0-rc1.zip "$TMP/rc1" DeadTired
stage "$CARD1_REF" DeadTired "$TMP/card1"
pack DeadTired-0.1.0-card1.zip "$TMP/card1" DeadTired
stage "$PROBE_REF" DeadTiredProbe "$TMP/probe"
pack DeadTiredProbe-0.1.0.zip "$TMP/probe" DeadTiredProbe
