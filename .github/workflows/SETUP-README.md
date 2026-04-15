# Automated OSRS Map Tile Pipeline Setup

## Overview

This repository can generate OSRS map assets locally or in GitHub Actions, then publish the generated tiles, icons, and basemap metadata to a separate GitHub repository for use in your own apps.

Use these placeholders throughout this guide:

- `<source-owner>/<source-repo>`: the repository running the workflow
- `<tiles-owner>/<tiles-repo>`: the repository that stores the generated assets

If you only want local output, you can stop after generation and use the files under `./out/mapgen/versions/{version_name}/output` directly.

## 3-Stage Generation Pipeline

1. **Cache download**: `python scripts/cache.py`
2. **Base tile generation**: `java -Xmx4g -Xms1g -jar ./osrs-wiki-maps/target/osrs-wiki-maps-*-shaded.jar`
3. **Final stitching + metadata/icons**: `python scripts/stitch.py`

The `osrs-wiki-maps` path in the Java command is the checked-in Java module directory, not your GitHub repository name. You only need to change that path if you rename the module directory inside this repo.

## Quick Start For A Fork

1. Fork this repository to your own GitHub account or organization.
2. Create a separate repository to hold generated tile assets.
3. If you want a step-by-step walkthrough for creating the tiles repo and token, see [TOKEN-SETUP.md](./TOKEN-SETUP.md).
4. In your source repository, add a secret named `TILES_REPO_TOKEN` with **Contents: Read and write** access to your tiles repository.
5. Update the fork-specific values listed in the next section.
6. Run the workflow manually with `force_update=true` for the first publish.
7. Point your own project at the generated `tiles/rendered`, `icons`, and `basemaps.json` output.

## Files To Review In A Fork

These are the hard-coded owner, repo, path, or identity values currently used in the codebase that you should review.

### Required Runtime Changes

- `.github/scripts/push_tiles.sh`
  - Set `TARGET_REPO` to `<tiles-owner>/<tiles-repo>`.
  - This script now clones and pushes using `https://x-access-token:${GITHUB_TOKEN}@github.com/${TARGET_REPO}.git`.
  - If you want commit history to use a different identity, also update `git config user.name` and `git config user.email` here.

- `.github/workflows/weekly-map-update.yml`
  - Set `VERSION_URL` to `https://raw.githubusercontent.com/<tiles-owner>/<tiles-repo>/main/cache-version.json`.
  - If you rename the `TILES_REPO_TOKEN` secret, update that secret reference here too.

### Only If You Rename The Java Module Directory

- `.github/workflows/weekly-map-update.yml`
  - Update `./osrs-wiki-maps/target/osrs-wiki-maps-*-shaded.jar`.

- `.github/workflows/workflow-dispatch.yml`
  - Update `./osrs-wiki-maps/target/osrs-wiki-maps-*-shaded.jar`.

- `.github/scripts/run_with_resource_monitor.sh`
  - Update `"$workspace/osrs-wiki-maps/target"`.

### Docs And Repo-Specific Guidance To Keep In Sync

- `.github/workflows/SETUP-README.md`
  - Replace example owner, repo, and URL placeholders with your own if you want the docs in your fork to be copy-paste ready.

- `.github/copilot-instructions.md`
  - Optional. Update the asset repo name there if you want Copilot guidance in your fork to match your own publish target.

## Workflow Triggers

Workflow file: `.github/workflows/weekly-map-update.yml`

- **Weekly schedule**: Wednesday at 14:00 UTC (`0 14 * * 3`)
- **Manual trigger**: `workflow_dispatch`
  - `force_update` (boolean): force regeneration and publish even when the cache version matches the currently published version

## Version Check Behavior

After downloading the latest cache, the workflow reads `./data/versions/version.txt` and compares it to:

```text
https://raw.githubusercontent.com/<tiles-owner>/<tiles-repo>/main/cache-version.json
```

- If versions match and `force_update` is `false`, generation and publish steps are skipped.
- If `cache-version.json` is missing or returns `404`, the workflow treats it as **needs update**.

## Required Secret

In `<source-owner>/<source-repo>` repository settings, add:

- `TILES_REPO_TOKEN`: fine-grained PAT with **Contents: Read and write** access to `<tiles-owner>/<tiles-repo>`

## What Gets Published

The push helper syncs only generated assets and metadata:

- `tiles/rendered/`
- `icons/`
- `basemaps.json`
- `cache-version.json` (version + timestamp)

Old generated files that no longer exist are removed with `rsync --delete`, while unchanged files are skipped with `rsync --checksum`.

## Resulting Tiles Repo Structure

Your tiles repository root will look like:

```text
README.md
cache-version.json
tiles/
  rendered/
    {mapId}/{zoom}/{plane}_{x}_{y}.png
icons/
basemaps.json
```

## Using The Output In Your Own Project

### Local Output

Generated local assets are written to:

```text
./out/mapgen/versions/{version_name}/output/
```

That directory contains everything your own project needs:

- `tiles/rendered/`
- `icons/`
- `basemaps.json`

### Hosted Tile URL Pattern

If you publish to GitHub, the raw file pattern is:

```text
https://raw.githubusercontent.com/<tiles-owner>/<tiles-repo>/main/tiles/rendered/{mapId}/{zoom}/{plane}_{x}_{y}.png
```

Basemap metadata is available at:

```text
https://raw.githubusercontent.com/<tiles-owner>/<tiles-repo>/main/basemaps.json
```

If you enable GitHub Pages for the tiles repo, you can also serve the same files from your Pages URL instead of `raw.githubusercontent.com`.

### What Your App Should Read

- Use `basemaps.json` for map bounds, centers, and map IDs.
- Load tile images from `tiles/rendered/{mapId}/{zoom}/{plane}_{x}_{y}.png`.
- Load `icons/` only if your app needs the generated icon sprites.

## Troubleshooting

- **Need a full rerun immediately**: trigger the workflow manually with `force_update=true`.
- **Workflow fails before publish**: inspect the Java and Python generation logs in the workflow run.
- **Publish fails**: verify `TARGET_REPO` in `.github/scripts/push_tiles.sh`, `VERSION_URL` in `.github/workflows/weekly-map-update.yml`, and the `TILES_REPO_TOKEN` secret permissions.
- **No publish happened**: check the version comparison output; the workflow may have skipped because the published version already matches.
