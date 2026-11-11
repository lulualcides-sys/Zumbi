#!/usr/bin/env python3
"""CI inventory and licensing check for the game's downloaded 3D assets.

Grounded in the free CCGS asset-audit rubric (read-only) and Arsenal.
This is deliberately NOT an AI agent and it never estimates visual quality.
It reports observable files, sizes, embedded data and animation names.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "build" / "qa"
EXPECTED = {
    "assets/cc0/survivor.gltf": "Quaternius Zombie Apocalypse Kit — CC0",
    "assets/cc0/rifle.gltf": "Quaternius Zombie Apocalypse Kit — CC0",
    "assets/cc0/zombie_basic.gltf": "Quaternius Zombie Apocalypse Kit — CC0",
    "assets/tactical/soldier.glb": "BAMEN + animation sources — CC BY 4.0 / CC0; see assets/tactical/CREDITS.md",
}
BUDGET_BYTES = 40_000_000
MAX_SINGLE_BYTES = 12_000_000

def inspect_gltf(data: bytes, file_name: str) -> dict:
    if file_name.endswith(".glb"):
        if len(data) < 20 or data[:4] != b"glTF":
            raise ValueError("invalid GLB signature")
        _, version, declared = struct.unpack_from("<4sII", data, 0)
        if version != 2 or declared != len(data):
            raise ValueError("invalid GLB version or size")
        json_len, tag = struct.unpack_from("<II", data, 12)
        if tag != 0x4e4f534a:
            raise ValueError("GLB has no JSON chunk")
        raw = data[20:20+json_len]
    else:
        raw = data
    doc = json.loads(raw.decode("utf-8"))
    if doc.get("asset", {}).get("version") != "2.0" or not doc.get("meshes"):
        raise ValueError("glTF v2 mesh missing")
    external_uris = [part["uri"] for part in doc.get("images", [])+doc.get("buffers", [])
                     if "uri" in part and not str(part["uri"]).startswith("data:")]
    if external_uris:
        raise ValueError("unpacked glTF dependencies: " + repr(external_uris[:4]))
    return {
        "mesh_count": len(doc["meshes"]),
        "animation_count": len(doc.get("animations", [])),
        "animation_names": [str(a.get("name", "unnamed")) for a in doc.get("animations", [])],
        "material_count": len(doc.get("materials", [])),
    }

def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    problems = []
    measured = []
    for relative, license_note in EXPECTED.items():
        path = ROOT / relative
        if not path.is_file():
            problems.append("Missing required asset: " + relative)
            continue
        data = path.read_bytes()
        if len(data) > MAX_SINGLE_BYTES:
            problems.append(f"{relative}: {len(data)} bytes exceed {MAX_SINGLE_BYTES}")
        try:
            properties = inspect_gltf(data, relative)
        except (ValueError, KeyError, UnicodeDecodeError, struct.error) as error:
            problems.append(f"{relative}: {error}")
            continue
        measured.append({
            "path": relative,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "license": license_note,
            **properties,
        })
    used_bytes = sum(a["bytes"] for a in measured)
    if used_bytes > BUDGET_BYTES:
        problems.append(f"Expected core assets total {used_bytes} exceeds {BUDGET_BYTES}")

    credits = ROOT / "assets/tactical/CREDITS.md"
    if not credits.is_file():
        problems.append("Missing attribution for tactical soldier GLB")
    # The bundled upstream rubric text is evidence of a downloaded reference,
    # not proof that a paid Claude Code workflow was executed.
    references = {
        "arsenal": ROOT / ".ci-sources/arsenal/README.md",
        "ccgs": ROOT / ".ci-sources/ccgs/.claude/skills/asset-audit/SKILL.md",
        "ccgs_visual_qa": ROOT / ".ci-sources/ccgs/.claude/skills/test-evidence-review/SKILL.md",
    }
    for name, path in references.items():
        if not path.is_file():
            problems.append(f"Upstream QA reference not downloaded: {name}")
    outcome = {
        "status": "FAIL" if problems else "PASS",
        "source": "Arsenal + CCGS read-only rubric, implemented as Python checks",
        "scope": "Installed core glTF/GLB; presence, formats, bytes, SHA256, animation metadata, attribution",
        "visual_similarity_to_video": "NOT ASSESSED",
        "physical_mobile_fps": "NOT ASSESSED",
        "core_total_bytes": used_bytes,
        "core_budget_bytes": BUDGET_BYTES,
        "files": measured,
        "problems": problems,
    }
    (REPORT_DIR / "asset-audit.json").write_text(
        json.dumps(outcome, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    markdown = [
        "# Arsenal + Claude Code Game Studios — asset audit",
        "",
        f"Status: **{outcome['status']}**. Art files checked: **{len(measured)}**.",
        f"Measured core size: **{used_bytes:,} bytes** / budget {BUDGET_BYTES:,} bytes.",
        "",
        "| Asset | Bytes | Meshes | Animations | Source/license |",
        "|---|---:|---:|---:|---|",
    ]
    for a in measured:
        markdown.append(f"| {a['path']} | {a['bytes']:,} | {a['mesh_count']} "
                        f"| {a['animation_count']} | {a['license']} |")
    markdown += [
        "", "## Errors", *(["- " + x for x in problems] if problems else ["None"]),
        "", "## Not assessed",
        "Visual fidelity, arm-to-gun alignment, perceived animation quality and mobile FPS.",
        "These require real captured frames / manual review / measured on-device profiling.",
    ]
    (REPORT_DIR / "asset-audit.md").write_text("\n".join(markdown)+"\n", encoding="utf-8")
    print(f"ASSET_AUDIT_{outcome['status']}: {len(measured)} required files, {used_bytes:,} bytes")
    for issue in problems:
        print("ASSET_AUDIT_ERROR:", issue, file=sys.stderr)
    return 1 if problems else 0

if __name__ == "__main__":
    raise SystemExit(main())
