#!/usr/bin/env python3
"""Fetch and normalize the licensed M4A1 for Blender/Godot.

The source model requires EXT_texture_webp; convert embedded WebP textures to
PNG before Blender import. Keep geometry untouched, preserve attribution and
record both SHA256 hashes. Reject unsupported extensions or external URIs.
"""
from __future__ import annotations

import hashlib
import io
import json
import pathlib
import struct
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
PIN = "130ac2a5c856401ec36e7d35afcfefe40c5801f4"
SOURCE = "https://raw.githubusercontent.com/cktang88/3d-fps/" + PIN + "/public/assets/models/weapons/m4a1.glb"
DEST = ROOT / "assets/tactical/source_m4a1.glb"

def chunks(data: bytes) -> tuple[dict, bytes]:
    if len(data) < 32 or data[:4] != b"glTF":
        raise ValueError("M4A1 is not GLB 2")
    _, version, declared_len = struct.unpack_from("<4sII", data, 0)
    if version != 2 or declared_len != len(data):
        raise ValueError("Invalid GLB length")
    json_len, json_tag = struct.unpack_from("<II", data, 12)
    if json_tag != 0x4E4F534A:
        raise ValueError("Missing JSON chunk")
    doc = json.loads(data[20:20 + json_len].decode("utf-8"))
    at = 20 + json_len
    bin_len, bin_tag = struct.unpack_from("<II", data, at)
    if bin_tag != 0x004E4942:
        raise ValueError("Missing binary buffer chunk")
    binary = data[at + 8:at + 8 + bin_len]
    if len(binary) != bin_len:
        raise ValueError("Truncated binary buffer")
    return doc, binary

def convert_webp(data: bytes) -> tuple[bytes, dict]:
    doc, rawbin = chunks(data)
    unsupported = set(doc.get("extensionsRequired", [])) - {"EXT_texture_webp"}
    if unsupported:
        raise ValueError("Unsupported glTF extensions " + repr(sorted(unsupported)))
    if not doc.get("meshes"):
        raise ValueError("GLB lacks weapon meshes")
    if any(str(part.get("uri", "")).startswith(("http:", "https:", "../"))
           for part in doc.get("buffers", []) + doc.get("images", [])):
        raise ValueError("External URI/traversal prohibited")
    binbuf = bytearray(rawbin)
    converted = {}
    for idx, image in enumerate(doc.get("images", [])):
        if image.get("mimeType") != "image/webp":
            continue
        view = doc["bufferViews"][image["bufferView"]]
        if view.get("buffer", 0) != 0:
            raise ValueError("Only GLB buffer 0 supported")
        offset = int(view.get("byteOffset", 0))
        size = int(view["byteLength"])
        raw = rawbin[offset:offset+size]
        if len(raw) != size:
            raise ValueError("Bad WebP buffer view")
        with Image.open(io.BytesIO(raw)) as raster:
            original_dimensions = raster.size
            # Top-down mobile WebGL rarely displays a gun texture beyond 1K.
            # Keep channels lossless (normal/metallic maps also use RGB).
            raster.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
            prepared_dimensions = raster.size
            png = io.BytesIO()
            raster.convert("RGBA").save(png, format="PNG", optimize=True)
        while len(binbuf) % 4:
            binbuf.append(0)
        new_at = len(binbuf)
        binbuf.extend(png.getvalue())
        new_idx = len(doc["bufferViews"])
        doc["bufferViews"].append({
            "buffer": 0, "byteOffset": new_at, "byteLength": len(png.getvalue())
        })
        image["bufferView"] = new_idx
        image["mimeType"] = "image/png"
        converted[idx] = {
            "bytes": len(png.getvalue()),
            "original_size": original_dimensions,
            "prepared_size": prepared_dimensions
        }
    for tex in doc.get("textures", []):
        ext = tex.get("extensions", {})
        if "EXT_texture_webp" in ext:
            tex["source"] = ext.pop("EXT_texture_webp")["source"]
            if not ext:
                tex.pop("extensions", None)
    for key in ["extensionsUsed", "extensionsRequired"]:
        doc[key] = [name for name in doc.get(key, []) if name != "EXT_texture_webp"]
        if not doc[key]:
            doc.pop(key, None)
    if doc.get("buffers"):
        doc["buffers"][0]["byteLength"] = len(binbuf)
    jsondata = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    jsondata += b" " * ((4 - len(jsondata) % 4) % 4)
    binbuf.extend(b"\0" * ((4-len(binbuf)%4)%4))
    length = 12 + 8 + len(jsondata) + 8 + len(binbuf)
    result = (struct.pack("<4sII", b"glTF", 2, length) +
              struct.pack("<II", len(jsondata), 0x4E4F534A) + jsondata +
              struct.pack("<II", len(binbuf), 0x004E4942) + bytes(binbuf))
    updated, _ = chunks(result)
    if updated.get("extensionsRequired"):
        raise ValueError("Failed to normalize required GLB extensions")
    return result, {"converted_webp_images": converted, "meshes": len(doc["meshes"]),
                    "materials": len(doc.get("materials", []))}

def main() -> None:
    DEST.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(SOURCE, headers={"User-Agent":"ZombieOutbreak-M4A1-Audit"})
    with urllib.request.urlopen(request, timeout=80) as response:
        original = response.read(4_000_001)
    if not 30_000 < len(original) < 4_000_000:
        raise ValueError("Oversized or incomplete source rifle")
    ready, metadata = convert_webp(original)
    DEST.write_bytes(ready)
    report = {
        "source": SOURCE,
        "original_sha256": hashlib.sha256(original).hexdigest(),
        "prepared_sha256": hashlib.sha256(ready).hexdigest(),
        "original_bytes": len(original),
        "prepared_bytes": len(ready),
        **metadata
    }
    DEST.with_suffix(".source.json").write_text(json.dumps(report, indent=2))
    print("M4A1_SOURCE_OK", json.dumps(report), flush=True)

if __name__ == "__main__":
    main()
