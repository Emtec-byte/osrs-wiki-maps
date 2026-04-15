# Token Setup

Use these placeholders throughout this guide:

- `<source-owner>/<source-repo>`: the repository running the workflow
- `<tiles-owner>/<tiles-repo>`: the repository that will store generated assets

## Step 1: Create the Tiles Hosting Repo

Create a new **public** GitHub repository under your own account or organization for generated tile assets.

Example placeholder name:

- `<tiles-repo>` = `osrs-map-tiles`

In that repository, create a minimal placeholder so GitHub Pages or raw file hosting has something to serve:

```bash
# Locally or via GitHub web UI
mkdir <tiles-repo> && cd <tiles-repo>
git init
echo '{"version": 0, "updated": "never"}' > cache-version.json
echo "# OSRS Map Tiles" > README.md
git add .
git commit -m "init"
git branch -M main
git remote add origin https://github.com/<tiles-owner>/<tiles-repo>.git
git push -u origin main
```

Then in that repository's settings, enable **Pages** if you want a Pages URL for the generated assets:

- **Settings → Pages**
- **Source:** Deploy from a branch
- **Branch:** `main` / root

That will give you a Pages URL shaped like:

```text
https://<tiles-owner>.github.io/<tiles-repo>/
```

## Step 2: Create a Personal Access Token

Go to:

- **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**

Generate a new token with:

- **Resource owner:** `<tiles-owner>`
- **Repository access:** Only selected repositories → choose `<tiles-repo>`
- **Permissions:**
  - `Contents` → Read and write
  - `Pages` → Read and write (optional, only needed if you want to manage Pages-related operations)

Copy the token value.

## Step 3: Add The Token To Your Source Repo

In `<source-owner>/<source-repo>`, go to:

- **Settings → Secrets and variables → Actions → New repository secret**

Create this secret:

| Secret Name | Value |
|---|---|
| `TILES_REPO_TOKEN` | The fine-grained token you just generated |

## What This Token Is Used For

The workflow uses `TILES_REPO_TOKEN` to:

- clone your tiles repository in `.github/scripts/push_tiles.sh`
- push updated `tiles/rendered`, `icons`, `basemaps.json`, and `cache-version.json`

If the token is missing, points at the wrong repository, or does not have write access, the workflow will usually complete generation and then fail in the publish step.
