# Automated OSRS Map Tile Pipeline Setup

## Overview
This repository runs an automated CI/CD pipeline that generates OSRS map assets and publishes them to `Emtec-byte/osrs-map-tiles`, which can be served as a CDN via GitHub Pages.

## 3-Stage Generation Pipeline
1. **Cache download**: `python scripts/cache.py`
2. **Base tile generation (Java/Maven build output JAR)**: `java -Xmx6g -Xms2g -jar ./osrs-wiki-maps/target/osrs-wiki-maps-*-shaded.jar` (the pattern should resolve to exactly one shaded JAR from the current Maven build)
3. **Final stitching + metadata/icons**: `python scripts/stitch.py`

## Workflow Triggers
Workflow file: `.github/workflows/weekly-map-update.yml`

- **Weekly schedule**: Wednesday at 14:00 UTC (`0 14 * * 3`)
- **Manual trigger**: `workflow_dispatch`
  - `force_update` (boolean): force regeneration and publish even when cache version matches the currently published version

## Version Check Behavior
After downloading the latest cache, the workflow reads `./data/versions/version.txt` and compares it to:

`https://raw.githubusercontent.com/Emtec-byte/osrs-map-tiles/main/cache-version.json`

- If versions match and `force_update` is `false`, generation/publish steps are skipped.
- If `cache-version.json` is missing (first run / 404), the workflow treats it as **needs update**.

## Required Secret
In `Emtec-byte/osrs-wiki-maps` repository settings, add:

- `TILES_REPO_TOKEN`: fine-grained PAT with **Contents: Read and write** access to `Emtec-byte/osrs-map-tiles`

## What Gets Pushed to `osrs-map-tiles`
The push helper syncs only generated assets and metadata:

- `tiles/rendered/`
- `icons/`
- `basemaps.json`
- `cache-version.json` (version + timestamp)

Old generated files that no longer exist are removed using `rsync --delete`, while unchanged files are skipped using `rsync --checksum`.

## Resulting Tiles Repo Structure
`osrs-map-tiles` root will look like:

```text
README.md
cache-version.json
tiles/
  rendered/
    {mapId}/{zoom}/{plane}_{x}_{y}.png
icons/
basemaps.json
```

## Leaflet Usage (Basic URL Pattern)
Use the published tiles base URL pattern from GitHub Pages raw files:

```text
https://raw.githubusercontent.com/Emtec-byte/osrs-map-tiles/main/tiles/rendered/{mapId}/{zoom}/{plane}_{x}_{y}.png
```

Metadata can be read from:

```text
https://raw.githubusercontent.com/Emtec-byte/osrs-map-tiles/main/basemaps.json
```

## GitHub Pages Requirement
Enable GitHub Pages on `Emtec-byte/osrs-map-tiles` (Settings → Pages) if you want it to act as a CDN endpoint from that repository.

## Troubleshooting
- **Need a full rerun immediately**: trigger workflow manually with `force_update=true`
- **Workflow fails before push**: inspect Java/Python generation logs in `weekly-map-update` run
- **Push fails**: verify `TILES_REPO_TOKEN` still has write access to `osrs-map-tiles`
- **No publish happened**: check version comparison output; it may have skipped because version is unchanged
