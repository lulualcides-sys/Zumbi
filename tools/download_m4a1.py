#!/usr/bin/env python3
"""Fetch the same M4A1 used with the licensed tactical character source.

Pin source for reproducibility. Audit format and licensing; Blender does not
run code from any external repo, only reads the weapon GLB as data.
"""
from __future__ import annotations
import hashlib
import json
import pathlib
import struct
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
PIN = "130ac2a5c856401ec36e7d35afcfefe40c5801f4"
SOURCE = "https://raw.githubusercontent.com/cktang88/3d-fps/" + PIN + "/public/assets/models/weapons/m4a1.glb"
DEST = ROOT / "assets/tactical/source_m4a1.glb"

def inspect(data: bytes) -> dict:
    if len(data) < 20 or data[:4] != b"glTF":
        raise ValueError("M4A1 is not GLB 2")
    _, version, length = struct.unpack_from("<4sII", data, 0)
    if version != 2 or length != len(data):
        raise ValueError("Invalid GLB length")
    chunk_len, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError("Missing GLB JSON")
    document = json.loads(data[20:20+chunk_len].decode("utf-8"))
    if not document.get("meshes"):
        raise ValueError("Weapon has no meshes")
    if document.get("extensionsRequired"):
        raise ValueError("Unsupported required GLB extensions: " + repr(document["extensionsRequired"]))
    if any(str(x.get("uri", "")).startswith(("http:", "https:", "../"))
           for x in document.get("buffers", [])+document.get("images", [])):
        raise ValueError("External dependencies forbidden")
    return {"mesh_count": len(document["meshes"]),
            "material_count": len(document.get("materials", [])),
            "nodes": len(document.get("nodes", [])),
            "sha256": hashlib.sha256(data).hexdigest()}

def main() -> None:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    if not DEST.is_file():
        req = urllib.request.Request(SOURCE, headers={"User-Agent": "Zumbi-Godot-M4A1-licensed-asset-builder"})
        with urllib.request.urlopen(req, timeout=80) as response:
            data = response.read(4_000_001)
    else:
        data = DEST.read_bytes()
    if not 30_000 < len(data) < 4_000_000:
        raise ValueError("Oversized or incomplete M4A1 GLB")
    metadata = inspect(data)
    DEST.write_bytes(data)
    print("M4A1_SOURCE_OK", json.dumps({"bytes":len(data), **metadata, "source":SOURCE}), flush=True)

if __name__ == "__main__":
    main()
