# osrs-wiki-maps

Fork of the OSRS map generation toolkit used to download the live cache, generate base tiles, and stitch final map assets.

For setup, CI/CD configuration, forking instructions, publishing to your own tiles repository, and consuming the generated tiles in your own project, see [Automated OSRS Map Tile Pipeline Setup](./.github/workflows/SETUP-README.md).

For creating the token and adding it as a GitHub Actions secret, see [Token Setup](./.github/workflows/TOKEN-SETUP.md).

Local generated output is written under `./out/mapgen/versions/{version_name}/output`.

---


## original README

## osrs-wiki-maps
A set of tools for generating map images for the OSRS wiki.

## Setup
1. Install JDK 11
2. Install Python 3.x.
3. `pip3 install -r requirements.txt`

## Generating maps
The files all assume your current working directory is the root of this repository.
1. `cache.py` runs first (no arguments), downloading the latest live oldschool cache from https://archive.openrs2.org.
    - Cache files are stored in  in `./data/versions/{version_name}`
    - The auto-generated version name is used to (over)write `./data/versions/version.txt` containing just the version name.
2. `MapExport.java` runs next (no arguments), reading the version name from the .txt. It generates:
    - Imagery tiles (no labels or map icons) go in `./out/mapgen/versions/{version_name}/tiles/rendered`
    - `minimapIcons.json` and `worldMapDefinitions.json` go in `./out/mapgen/versions/{version_name}`
3. `stitch.py` runs last (no arguments), again reading the version name from the file, and rendering maps from the tiles in step 2.
    - Output images stored in `./out/mapgen/versions/{version_name}/output/tiles/rendered`
    - Output icons stored in `./out/mapgen/versions/{version_name}/output/icons`
    - Wiki basemap definitions go in `./out/mapgen/versions/{version_name}/output/basemaps.json`
4. The directory `./out/mapgen/versions/{version_name}/output` can then be zipped and uploaded to map server.
