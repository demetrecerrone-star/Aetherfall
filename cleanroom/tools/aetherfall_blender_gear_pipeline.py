"""Aetherfall Blender gear fitter for Blender 4.5 LTS+.

Imports one 65-joint playable body plus unrigged gear, normalizes the gear to
body height, centers it, transfers body vertex-group weights to every gear
piece, attaches the existing armature, validates deformation coverage, and
exports a game-ready GLB without changing the character skeleton.
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
import bpy
from mathutils import Vector

EXPECTED_JOINTS = 65

def args():
    a = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--character", required=True)
    p.add_argument("--gear", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--blend")
    p.add_argument("--report")
    p.add_argument("--clearance", type=float, default=0.010)
    p.add_argument("--min-scale", type=float, default=0.90)
    p.add_argument("--max-scale", type=float, default=1.10)
    return p.parse_args(a)

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]

def bbox(objs):
    pts = []
    for o in objs:
        if o.type == "MESH" and len(o.data.vertices):
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    if not pts:
        raise RuntimeError("No mesh geometry")
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def armature(objs):
    arms = [o for o in objs if o.type == "ARMATURE"]
    if not arms:
        raise RuntimeError("Character has no armature")
    rig = max(arms, key=lambda o: len(o.data.bones))
    if len(rig.data.bones) != EXPECTED_JOINTS:
        raise RuntimeError(f"Expected {EXPECTED_JOINTS} bones, got {len(rig.data.bones)}")
    return rig

def body_mesh(objs):
    meshes = [o for o in objs if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("Character has no body mesh")
    return max(meshes, key=lambda o: len(o.data.vertices))

def fit_to_body(gear, body, min_scale, max_scale):
    b0, b1 = bbox([body])
    g0, g1 = bbox(gear)
    bh, gh = b1.y-b0.y, g1.y-g0.y
    if gh <= 1e-6:
        raise RuntimeError("Gear has invalid height")
    s = max(min(bh/gh, max_scale), min_scale)
    for o in gear:
        o.scale *= s
    bpy.context.view_layer.update()
    g0, g1 = bbox(gear)
    bc, gc = (b0+b1)*0.5, (g0+g1)*0.5
    d = Vector((bc.x-gc.x, b0.y-g0.y, bc.z-gc.z))
    for o in gear:
        o.location += d
    bpy.context.view_layer.update()
    return s

def apply_transforms(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")

def transfer_weights(body, garment, rig):
    for vg in list(garment.vertex_groups):
        garment.vertex_groups.remove(vg)
    for source in body.vertex_groups:
        garment.vertex_groups.new(name=source.name)
    for m in list(garment.modifiers):
        if m.type in {"DATA_TRANSFER", "ARMATURE"}:
            garment.modifiers.remove(m)
    dt = garment.modifiers.new("AF_WeightTransfer", "DATA_TRANSFER")
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    dt.mix_mode = "REPLACE"
    bpy.context.view_layer.objects.active = garment
    garment.select_set(True)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    garment.select_set(False)
    arm = garment.modifiers.new("AF_Armature", "ARMATURE")
    arm.object = rig
    arm.use_deform_preserve_volume = True

def clearance(garment, amount):
    if amount <= 0:
        return
    m = garment.modifiers.new("AF_ClothClearance", "DISPLACE")
    m.strength = amount
    m.mid_level = 0.0
    m.direction = "NORMAL"

def validate(garment, rig):
    names = {b.name for b in rig.data.bones}
    weighted = 0
    for v in garment.data.vertices:
        good = False
        for g in v.groups:
            if g.group < len(garment.vertex_groups):
                vg = garment.vertex_groups[g.group]
                if vg.name in names and g.weight > 1e-5:
                    good = True
                    break
        weighted += int(good)
    ratio = weighted / max(1, len(garment.data.vertices))
    return {"name": garment.name, "vertices": len(garment.data.vertices), "weighted_ratio": ratio}

def main():
    a = args()
    character, gear_path = Path(a.character).resolve(), Path(a.gear).resolve()
    out = Path(a.output).resolve()
    if not character.is_file() or not gear_path.is_file():
        raise FileNotFoundError("Character or gear GLB missing")

    reset()
    char_objs = import_glb(character)
    rig = armature(char_objs)
    body = body_mesh(char_objs)
    body.name, rig.name = "AF_Body", "AF_Armature"

    gear_objs = import_glb(gear_path)
    gear = [o for o in gear_objs if o.type == "MESH" and len(o.data.vertices)]
    if not gear:
        raise RuntimeError("Gear contains no mesh")
    scale = fit_to_body(gear, body, a.min_scale, a.max_scale)
    apply_transforms(gear)

    report = []
    for i, garment in enumerate(gear):
        garment.name = f"AF_Gear_{i:03d}"
        transfer_weights(body, garment, rig)
        clearance(garment, a.clearance)
        report.append(validate(garment, rig))

    bad = [r for r in report if r["weighted_ratio"] < 0.98]
    if bad:
        raise RuntimeError("Incomplete weight transfer: " + ", ".join(f'{r["name"]}={r["weighted_ratio"]:.1%}' for r in bad[:8]))

    if a.blend:
        Path(a.blend).resolve().parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(a.blend).resolve()))
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                              export_apply=False, export_animations=True,
                              export_skins=True, export_materials="EXPORT",
                              export_yup=True)

    result = {
        "character": str(character), "gear": str(gear_path), "output": str(out),
        "armature_bones": len(rig.data.bones), "gear_parts": len(gear),
        "fit_scale": scale, "clearance": a.clearance,
        "weight_validation": report
    }
    if a.report:
        rp = Path(a.report).resolve()
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("AETHERFALL_GEAR_PIPELINE_OK")
    print(json.dumps({"bones": 65, "gear_parts": len(gear), "fit_scale": scale}, indent=2))

if __name__ == "__main__":
    main()
