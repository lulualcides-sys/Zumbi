"""Blender-only offline asset prep — align a licensed M4A1 to dual hand grips.

Import actual Firewarden M4A1 (CC BY 4.0, via pinned repository), preserve its
materials, add grip and barrel sockets, then export one Godot-friendly GLB.
No source scripts are executed and no other game repositories are modified.

Run:
  blender -b --factory-startup --python tools/blender/prepare_m4a1.py -- \
      assets/tactical/source_m4a1.glb assets/tactical/m4a1-ready.glb
"""
import bpy
import json
import pathlib
import sys

def main() -> None:
    argv = sys.argv[sys.argv.index("--")+1:]
    if len(argv) != 2:
        raise RuntimeError("expected input.glb output.glb")
    input_file, output_file = map(lambda v: pathlib.Path(v).resolve(), argv)
    if not input_file.is_file():
        raise RuntimeError("M4A1 source missing")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(input_file))
    meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
    if not meshes:
        raise RuntimeError("Import produced no mesh")

    # glTF input is Y-up, Blender works in Z-up. The source M4A1 points along
    # negative glTF Z. Grip locations are grounded in the source game's
    # POSES.m4a1 (GunModels.js) and converted to Blender's coordinates.
    def from_gltf(v):
        x,y,z=v
        return (x,-z,y)

    sockets = {
        "M4A1_PrimaryGrip": (0.0,-0.15,-0.05),
        "M4A1_SupportGrip": (0.0,0.0,-0.58),
        "M4A1_MuzzleSocket": (0.0,0.04,-1.09),
    }
    for label, xyz in sockets.items():
        bpy.ops.object.empty_add(type='PLAIN_AXES', location=from_gltf(xyz))
        node=bpy.context.object
        node.name=label
        node.empty_display_size=0.05

    output_file.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(output_file),export_format='GLB',
                              export_yup=True,export_apply=False,
                              export_extras=True)
    if not output_file.is_file() or output_file.stat().st_size<40000:
        raise RuntimeError("Calibrated GLB missing or truncated")
    report={
        "meshes":len(meshes), "output_bytes":output_file.stat().st_size,
        "sockets_gltf":sockets, "source_asset":"Firewarden M4A1, CC BY 4.0",
        "process":"Blender import, grip/muzzle socket markers, GLB export"
    }
    output_file.with_suffix(".audit.json").write_text(json.dumps(report,indent=2))
    print("BLENDER_M4A1_READY:", json.dumps(report),flush=True)

if __name__=="__main__":
    main()
