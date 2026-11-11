#!/usr/bin/env python3
"""Install an appropriately licensed animated military model for the Godot game.

Source is a pinned source repository. No scripts from the source repo execute.
Credits: BAMEN's FREE [Military Soldier] RIGGED (CC BY 4.0); remapped motion
clips from Quaternius Universal Animation Library (CC0), and 100STYLE
(Mason, Starke and Komura; CC BY 4.0). See assets/tactical/CREDITS.md.
"""
from __future__ import annotations
import hashlib
import json
import pathlib
import struct
import sys
import urllib.request

PIN = "130ac2a5c856401ec36e7d35afcfefe40c5801f4"
URL = ("https://raw.githubusercontent.com/cktang88/3d-fps/" + PIN +
       "/public/assets/models/characters/soldier.glb")
DEST = pathlib.Path(__file__).resolve().parents[1] / "assets/tactical/soldier.glb"

def inspect_glb(buf: bytes) -> dict:
    if len(buf) < 20 or buf[:4] != b"glTF":
        raise ValueError("Invalid GLB header")
    magic, version, length = struct.unpack_from("<4sII", buf, 0)
    if version != 2 or length != len(buf):
        raise ValueError("Invalid glTF 2 length/version")
    chunk_length, chunk_tag = struct.unpack_from("<II", buf, 12)
    if chunk_tag != 0x4e4f534a:
        raise ValueError("Missing JSON chunk")
    doc = json.loads(buf[20:20+chunk_length].decode("utf-8"))
    if not doc.get("meshes"):
        raise ValueError("No character meshes")
    missing = [x["uri"] for x in doc.get("images", []) + doc.get("buffers", [])
               if x.get("uri", "").startswith(("http://","https://","../"))]
    if missing:
        raise ValueError("Asset contains remote or traversal dependencies")
    animations = [str(x.get("name", "")) for x in doc.get("animations", [])]
    vertices = [x.get("min") for x in doc.get("accessors", []) if x.get("type") == "VEC3" and x.get("min") is not None]
    maxima = [x.get("max") for x in doc.get("accessors", []) if x.get("type") == "VEC3" and x.get("max") is not None]
    return {"meshes": len(doc["meshes"]), "node_count": len(doc.get("nodes", [])),
            "animations": animations[:140], "minima": vertices[:5], "maxima": maxima[:5]}

def create_infected_variant(source: bytes) -> bytes:
    """Keep only animations required by a zombie, without touching source art.

    The original soldier GLB includes dozens of expensive third-person
    locomotion/mocap clips. Importing those for every enemy is unnecessary.
    The retained track payloads are referenced in the existing BIN chunk.
    """
    _, version, _ = struct.unpack_from("<4sII", source, 0)
    first_len, first_type = struct.unpack_from("<II", source, 12)
    assert version == 2 and first_type == 0x4e4f534a
    original_doc = json.loads(source[20:20+first_len].decode("utf-8"))
    keep = {"idle", "walk", "run", "melee", "hit", "death"}
    original_doc["animations"] = [
        clip for clip in original_doc.get("animations", [])
        if str(clip.get("name", "")).lower() in keep
    ]
    if len(original_doc["animations"]) < 5:
        raise ValueError("Infected model does not preserve required animation clips")
    json_bytes = json.dumps(original_doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    rest_chunks = source[20 + first_len:]
    result_len = 12 + 8 + len(json_bytes) + len(rest_chunks)
    return (struct.pack("<4sII", b"glTF", 2, result_len)
            + struct.pack("<II", len(json_bytes), 0x4e4f534a)
            + json_bytes + rest_chunks)


def main() -> int:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    if DEST.exists():
        buf = DEST.read_bytes()
    else:
        request = urllib.request.Request(URL, headers={"User-Agent": "ZombieOutbreak-CCBY4-AssetAudit"})
        with urllib.request.urlopen(request, timeout=80) as resp:
            buf = resp.read(8_000_001)
    if len(buf) > 8_000_000 or len(buf) < 1_000:
        raise ValueError("Invalid or oversized tactical model")
    meta = inspect_glb(buf)
    if not meta["animations"]:
        raise ValueError("Animated soldier file has no animations")
    DEST.write_bytes(buf)
    infected = create_infected_variant(buf)
    infected_meta = inspect_glb(infected)
    enemy_path = DEST.with_name("infected.glb")
    enemy_path.write_bytes(infected)
    print("INFECTED_VARIANT_OK: {} bytes, {} animations".format(
        len(infected), infected_meta["animations"]), flush=True)
    print("TACTICAL_SOLDIER_OK: size={} sha256={} meshes={} nodes={} animations={}".format(
        len(buf), hashlib.sha256(buf).hexdigest(), meta["meshes"], meta["node_count"], meta["animations"]), flush=True)
    print("TACTICAL_BOUNDS minima={} maxima={}".format(meta["minima"], meta["maxima"]), flush=True)
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print("TACTICAL_SOLDIER_ERROR: {}".format(exc), file=sys.stderr)
        sys.exit(1)
