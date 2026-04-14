#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <cache_version> <github_token>"
  exit 1
fi

VERSION="$1"
GITHUB_TOKEN="$2"
SOURCE_ROOT="$(pwd)"
OUTPUT_DIR="${SOURCE_ROOT}/out/mapgen/versions/${VERSION}/output"
TARGET_REPO="Emtec-byte/osrs-map-tiles"

if [ ! -d "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$(find "${SOURCE_ROOT}/out/mapgen/versions" -mindepth 2 -maxdepth 2 -type d -name output | sort | tail -n 1 || true)"
fi

if [ -z "${OUTPUT_DIR}" ] || [ ! -d "$OUTPUT_DIR" ]; then
  echo "Error: Could not find generated output directory."
  exit 1
fi

if [ ! -d "$OUTPUT_DIR/tiles/rendered" ] || [ ! -d "$OUTPUT_DIR/icons" ] || [ ! -f "$OUTPUT_DIR/basemaps.json" ]; then
  echo "Error: Output directory is missing required assets (tiles/rendered, icons, or basemaps.json)."
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Cloning ${TARGET_REPO}..."
git clone --depth=1 "https://x-access-token:${GITHUB_TOKEN}@github.com/${TARGET_REPO}.git" "$WORK_DIR/tiles-repo"

cd "$WORK_DIR/tiles-repo"
mkdir -p tiles/rendered icons

echo "Syncing rendered tiles..."
rsync -a --delete --checksum "$OUTPUT_DIR/tiles/rendered/" "./tiles/rendered/"

echo "Syncing icons..."
rsync -a --delete --checksum "$OUTPUT_DIR/icons/" "./icons/"

echo "Syncing basemaps metadata..."
rsync -a --checksum "$OUTPUT_DIR/basemaps.json" "./basemaps.json"

cat > cache-version.json <<EOF
{"version":"${VERSION}","updated":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"}
EOF

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add -A

if git diff --cached --quiet; then
  echo "No asset changes detected; nothing to commit."
  exit 0
fi

git commit -m "chore: update map tiles for OSRS version ${VERSION}"
git push origin main

echo "Map tiles updated for version ${VERSION}."
