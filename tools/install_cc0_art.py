#!/usr/bin/env python3
"""Download pinned CC0 Quaternius characters and props before the Godot import.

Use only trusted, known files from the public Quaternius mirror. No external
scripts, packages, binaries or runtime requests are executed.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OWNER = "agentkaerf"
REPO = "FreeModels"
REVISION = "db3df04d1e4714298a09510b26fb6de6645138a2"
BASE = "Zombie Apocalypse Kit - March 2024"
DESTINATION = pathlib.Path(__file__).resolve().parent.parent / "assets" / "cc0"

ASSETS = {
    "survivor.gltf": "Characters/glTF/Characters_Matt_SingleWeapon.gltf",
    "zombie_basic.gltf": "Characters/glTF/Zombie_Basic.gltf",
    "zombie_chubby.gltf": "Characters/glTF/Zombie_Chubby.gltf",
    "zombie_ribcage.gltf": "Characters/glTF/Zombie_Ribcage.gltf",
    "barrel.gltf": "Environment/glTF/Barrel.gltf",
    "pallet.gltf": "Environment/glTF/Pallet.gltf",
    "traffic_barrier.gltf": "Environment/glTF/TrafficBarrier_1.gltf",
    "container_green.gltf": "Environment/glTF/Container_Green.gltf",
}


def asset_url(relative: str) -> str:
    # Pin to a known upstream commit, not a mutable branch.
    repo_path = urllib.parse.quote(f"{BASE}/{relative}", safe="/")
    return f"https://raw.githubusercontent.com/{OWNER}/{REPO}/{REVISION}/{repo_path}"


def download(url: str) -> bytes:
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "ZombieOutbreakGodot-CC0AssetFetcher/1.0"},
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read(30_000_001)
            if len(data) > 30_000_000:
                raise ValueError("Asset exceeds 30 MB; do not embed.")
            return data
        except (urllib.error.URLError, TimeoutError) as error:
            last_error = error
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Download failed: {url}: {last_error}")


def validate_gltf(data: bytes, name: str) -> dict:
    doc = json.loads(data.decode("utf-8"))
    if doc.get("asset", {}).get("version") != "2.0" or not doc.get("meshes"):
        raise ValueError(f"{name}: Not a valid glTF 2.0 mesh")
    # All buffer/image files must be embedded. Never silently accept a missing
    # dependency: the browser export would otherwise load an invisible character.
    externals = [
        p.get("uri") for p in doc.get("buffers", []) + doc.get("images", [])
        if "uri" in p and not p["uri"].startswith("data:")
    ]
    if externals:
        raise ValueError(f"{name}: external buffer/image files not packaged: {externals}")
    return doc


def main() -> int:
    DESTINATION.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for filename, source in ASSETS.items():
        target = DESTINATION / filename
        data = target.read_bytes() if target.exists() else download(asset_url(source))
        doc = validate_gltf(data, filename)
        target.write_bytes(data)
        animations = [x.get("name", "") for x in doc.get("animations", [])]
        manifest[filename] = {
            "source": source,
            "sha256": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
            "animations": animations,
        }
        print(f"ASSET_OK: {filename} {len(data):,} bytes animations={animations[:20]}", flush=True)
    (DESTINATION / "manifest.json").write_text(
        json.dumps({"source_commit": REVISION, "license": "CC0-1.0", "assets": manifest},
                   indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"CC0_ASSETS_READY: {len(ASSETS)} glTF scenes ready for Godot import")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"ASSET_DOWNLOAD_ERROR: {error}", file=sys.stderr)
        sys.exit(1)
