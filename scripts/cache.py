from os import makedirs
import os.path
from io import BytesIO
import json
import datetime as dt
from zipfile import ZipFile
from string import ascii_lowercase
from dateutil.parser import isoparse
import requests


CACHE_URL_BASE = "https://archive.openrs2.org"
UTC = dt.timezone.utc


def make_output_folder(date_str: str, version_dir: str) -> tuple[str, str]:
    version_name = date_str
    out_folder = os.path.join(version_dir, version_name)
    tries = 0
    while os.path.exists(out_folder):
        version_name = date_str + f"_{ascii_lowercase[tries]}"
        out_folder = os.path.join(version_dir, version_name)
        tries += 1
    makedirs(out_folder)
    return version_name, out_folder


def get_cache_info() -> tuple[int, str, int | None]:
    MIN_VALID_KEYS = 100
    cache_list = requests.get(CACHE_URL_BASE + "/caches.json", timeout=15).json()
    latest = dt.datetime(1970, 1, 1, tzinfo=UTC)
    cache_id = -1
    build_number = None
    for cache in cache_list:
        if (cache["scope"] != "runescape"
                or cache["game"] != "oldschool"
                or cache["environment"] != "live"
                or cache.get("language", "en") != "en"):
            continue

        timestamp = cache["timestamp"]
        if not timestamp:
            continue

        valid_keys = cache.get("valid_keys")
        if valid_keys is None or valid_keys < MIN_VALID_KEYS:
            continue

        date = isoparse(timestamp)
        if date > latest:
            latest = date
            cache_id = cache["id"]
            builds = cache.get("builds") or []
            build_number = builds[0].get("major") if builds else None

    if cache_id == -1:
        raise RuntimeError("No suitable OSRS cache found with sufficient XTEA keys")

    date_str = latest.strftime("%Y-%m-%d")
    print(f"Selected cache id={cache_id}, build={build_number}, "
          f"timestamp={latest.isoformat()}, valid_keys filter>={MIN_VALID_KEYS}")
    return cache_id, date_str, build_number


def download_xteas(cache_id, out_folder):
    keys_path = os.path.join(out_folder, "xteas.json")

    response = requests.get(CACHE_URL_BASE + f"/caches/runescape/{cache_id}/keys.json", timeout=30)
    response.raise_for_status()

    raw_entries = response.json()
    print(f"Fetched {len(raw_entries)} raw key entries from OpenRS2")

    key_list = []
    for xtea in raw_entries:
        mapsquare = xtea.get("mapsquare")
        keys = xtea.get("key")

        # Skip entries without a valid map region or missing key data
        if mapsquare is None or keys is None:
            continue

        key_list.append({"region": mapsquare, "keys": keys})

    print(f"Loaded {len(key_list)} valid XTEA keys (filtered from {len(raw_entries)} raw entries)")

    if len(key_list) == 0:
        raise RuntimeError("No XTEA keys were loaded — aborting to prevent downstream failures")

    with open(keys_path, "w", encoding="utf-8") as file:
        json.dump(key_list, file)


def download_cache(cache_id, out_folder):
    # print("Downloading cache...")
    # start = dt.datetime.now()
    raw = requests.get(CACHE_URL_BASE + f"/caches/runescape/{cache_id}/disk.zip", timeout=300).content
    # end = dt.datetime.now()
    # print(f"{int((end-start).total_seconds())}s elapsed.\n")

    z = ZipFile(BytesIO(raw))
    z.extractall(out_folder)


def write_version_txt(version_name, cache_dir):
    txt_path = os.path.join(cache_dir, "version.txt")
    if os.path.exists(txt_path):
        os.remove(txt_path)

    with open(txt_path, "wt") as file:
        file.write(version_name)


def download():
    cache_id, date_str, build_number = get_cache_info()
    cache_dir = "./data/versions"
    version_name, out_folder = make_output_folder(date_str, cache_dir)

    download_xteas(cache_id, out_folder)
    download_cache(cache_id, out_folder)
    write_version_txt(version_name, cache_dir)

    return version_name


if __name__ == "__main__":
    version = download()
    print(version)
