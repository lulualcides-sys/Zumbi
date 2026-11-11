#!/usr/bin/env python3
"""Lightweight GLB socket builder: zero Blender runtime needed for repeat tests.

Preserves source triangulation/material/texture/skins and adds the same socket
empties declared by the Blender lab script. Poses are sourced from GunModels.js
of the same pinned repository as the tactical soldier. Reproducible and free.
"""
from __future__ import annotations
import hashlib
import json
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/tactical/source_m4a1.glb"
DST = ROOT / "assets/tactical/m4a1-ready.glb"
SOCKETS = {
    "M4A1_PrimaryGrip": [0.0, -0.15, -0.05],
    "M4A1_SupportGrip": [0.0, 0.0, -0.58],
    "M4A1_MuzzleSocket": [0.0, 0.04, -1.09],
}

def main() -> None:
    data = SRC.read_bytes()
    if len(data) < 32 or data[:4] != b"glTF":
        raise ValueError("Invalid input GLB")
    _, version, total = struct.unpack_from("<4sII",data,0)
    if version != 2 or total != len(data):
        raise ValueError("Truncated GLB")
    json_len, tag = struct.unpack_from("<II",data,12)
    if tag != 0x4E4F534A:
        raise ValueError("No JSON chunk")
    doc = json.loads(data[20:20+json_len].decode("utf-8"))
    rest = data[20+json_len:]
    if not doc.get("meshes") or not doc.get("materials") or not doc.get("scenes"):
        raise ValueError("Weapon has no visible mesh/material/scene")
    if doc.get("extensionsRequired"):
        raise ValueError("Unsupported glTF extensions remain")
    indices = []
    for name, coords in SOCKETS.items():
        if any(node.get("name") == name for node in doc["nodes"]):
            raise ValueError("Duplicate socket: " + name)
        indices.append(len(doc["nodes"]))
        doc["nodes"].append({"name":name,"translation":coords})
    # Add sockets to the actual root scene, no hidden orphan nodes.
    index = int(doc.get("scene",0))
    scene = doc["scenes"][index]
    scene.setdefault("nodes",[]).extend(indices)
    json_bytes = json.dumps(doc,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    json_bytes += b" " * ((4-len(json_bytes)%4)%4)
    total = 12+8+len(json_bytes)+len(rest)
    result=(struct.pack("<4sII",b"glTF",2,total)
            +struct.pack("<II",len(json_bytes),0x4E4F534A)
            +json_bytes+rest)
    DST.write_bytes(result)
    audit={"meshes":len(doc["meshes"]),"materials":len(doc["materials"]),
           "output_bytes":len(result),"sockets":SOCKETS,
           "sha256":hashlib.sha256(result).hexdigest(),
           "method":"GLB metadata/scene-graph injection; meshes unchanged"}
    DST.with_suffix(".audit.json").write_text(json.dumps(audit,indent=2))
    print("COMPATIBLE_M4A1_READY:",json.dumps(audit),flush=True)

if __name__ == "__main__":
    main()
