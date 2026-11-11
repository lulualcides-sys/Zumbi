#!/usr/bin/env python3
"""Fail the build if Blender did not export the actual textured rifle and sockets."""
import hashlib
import json
import pathlib
import struct

p = pathlib.Path("assets/tactical/m4a1-ready.glb")
data = p.read_bytes()
if data[:4] != b"glTF" or len(data) < 80000:
    raise SystemExit("BLENDER_M4A1_FAILED: missing GLB mesh")
_, ver, length = struct.unpack_from("<4sII",data)
chunk_len, chunk_type = struct.unpack_from("<II",data,12)
assert ver == 2 and length == len(data) and chunk_type == 0x4e4f534a
doc=json.loads(data[20:20+chunk_len].decode())
names = {n.get("name") for n in doc.get("nodes", [])}
expected={"M4A1_PrimaryGrip","M4A1_SupportGrip","M4A1_MuzzleSocket"}
if not expected.issubset(names):
    raise SystemExit("BLENDER_M4A1_FAILED: missing sockets "+str(expected-names))
if not doc.get("meshes") or not doc.get("materials"):
    raise SystemExit("BLENDER_M4A1_FAILED: Blender removed textured geometry/materials")
print("BLENDER_M4A1_VALIDATED: meshes={} mats={} bytes={} sha256={} sockets={}".format(
    len(doc["meshes"]),len(doc["materials"]),len(data),
    hashlib.sha256(data).hexdigest(), sorted(expected)),flush=True)
