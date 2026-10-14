"""Aetherfall authored male peasant refinement pass.

Runs inside Blender on the currently committed Tripo male runtime model. It
reuses authored garment geometry already embedded in the model, repairs skin
weights where needed, limits influences for mobile, attaches explicit
equipment/occlusion metadata to glTF extras, renders QA views, and exports an
authored-garment GLB for review.

This intentionally does NOT generate body-derived shell clothing.
"""
from __future__ import annotations
import argparse, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector

EXPECTED_BONES = 65

def parse_args():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--report", required=True)
    p.add_argument("--render-dir", required=True)
    return p.parse_args(raw)

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=str(path))

def world_bounds(obj):
    pts = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def object_center(obj):
    mn, mx = world_bounds(obj)
    return (mn + mx) * 0.5

def is_legacy_garment(obj):
    n = obj.name.lower()
    if n.startswith("af_peasant_") or n.startswith("af_gear_peasant_"):
        return True
    if "peasant" in n and not any(x in n for x in ("body", "head", "hair")):
        return True
    # Preserve compatibility with older embedded naming if materials carry the clue.
    for slot in obj.material_slots:
        if slot.material and any(k in slot.material.name.lower() for k in ("tunic","linen","trouser","wool","boot","leather","belt")):
            return True
    return False

def choose_rig():
    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not rigs:
        raise RuntimeError("No armature in input")
    rig = max(rigs, key=lambda o: len(o.data.bones))
    if len(rig.data.bones) != EXPECTED_BONES:
        raise RuntimeError("Expected %d bones, got %d" % (EXPECTED_BONES, len(rig.data.bones)))
    return rig

def matching_weight_ratio(obj, rig):
    bone_names = {b.name for b in rig.data.bones}
    if not obj.vertex_groups or not len(obj.data.vertices):
        return 0.0
    good = 0
    for v in obj.data.vertices:
        ok = False
        for g in v.groups:
            if g.group < len(obj.vertex_groups):
                vg = obj.vertex_groups[g.group]
                if vg.name in bone_names and g.weight > 1e-5:
                    ok = True
                    break
        good += int(ok)
    return good / max(1, len(obj.data.vertices))

def choose_body(meshes, garment_candidates, rig):
    garments = set(garment_candidates)
    candidates = [m for m in meshes if m not in garments]
    # Prefer the largest well-skinned character mesh.
    candidates.sort(key=lambda o: (matching_weight_ratio(o, rig), len(o.data.vertices)), reverse=True)
    if not candidates:
        raise RuntimeError("Could not identify character body")
    return candidates[0]

def transfer_weights(body, garment, rig):
    # Generate destination groups by name before transfer.
    for vg in list(garment.vertex_groups):
        garment.vertex_groups.remove(vg)
    for source in body.vertex_groups:
        garment.vertex_groups.new(name=source.name)
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

def clean_weights(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    except Exception:
        pass
    try:
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.0005, keep_single=True)
    except Exception:
        pass
    try:
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    except Exception:
        pass
    try:
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    except Exception:
        pass
    obj.select_set(False)

def ensure_armature(obj, rig):
    for m in list(obj.modifiers):
        if m.type == "ARMATURE":
            obj.modifiers.remove(m)
    mod = obj.modifiers.new("AF_Armature", "ARMATURE")
    mod.object = rig
    # Useful for Blender deformation QA; skin weights remain the portable glTF data.
    if hasattr(mod, "use_deform_preserve_volume"):
        mod.use_deform_preserve_volume = True

def classify_part(obj, body):
    n = obj.name.lower()
    mats = " ".join((s.material.name.lower() if s.material else "") for s in obj.material_slots)
    text = n + " " + mats
    if any(k in text for k in ("boot","shoe","foot")):
        return "Boots"
    if any(k in text for k in ("belt","waist","sash")):
        return "Belt"
    if any(k in text for k in ("trouser","pants","pant","leg")):
        return "Trousers"
    if any(k in text for k in ("tunic","shirt","linen","sleeve","cloth")):
        return "Tunic"
    b0, b1 = world_bounds(body)
    o0, o1 = world_bounds(obj)
    h = max(1e-6, b1.z - b0.z)
    cz = (((o0.z + o1.z) * 0.5) - b0.z) / h
    oh = (o1.z - o0.z) / h
    if cz < 0.22:
        return "Boots"
    if 0.39 <= cz <= 0.54 and oh < 0.13:
        return "Belt"
    if cz < 0.53:
        return "Trousers"
    return "Tunic"

PART_META = {
    "Tunic": {
        "slot": "chest", "layer": 3,
        "covered": "Torso,Pelvis,UpperArm.L,UpperArm.R",
        "material": "linen"
    },
    "Trousers": {
        "slot": "legs", "layer": 4,
        "covered": "Pelvis,Thigh.L,Thigh.R,Calf.L,Calf.R",
        "material": "wool"
    },
    "Boots": {
        "slot": "feet", "layer": 8,
        "covered": "Foot.L,Foot.R,Calf.L,Calf.R",
        "material": "leather"
    },
    "Belt": {
        "slot": "waist", "layer": 7,
        "covered": "", "material": "leather"
    },
}

def tag_garment(obj, part, index):
    meta = PART_META[part]
    obj.name = "AF_Gear_authored_peasant_%s_%02d" % (part, index)
    obj["aetherfall_equipment_id"] = "starter_peasant_" + part.lower()
    obj["aetherfall_equipment_slot"] = meta["slot"]
    obj["aetherfall_clothing_layer"] = int(meta["layer"])
    obj["aetherfall_covered_body_regions"] = meta["covered"]
    obj["aetherfall_material_family"] = meta["material"]
    obj["aetherfall_fit_profile"] = "male_anime_v1"
    obj["aetherfall_skeleton_profile"] = "AF_65"
    obj["aetherfall_authored_geometry"] = True
    obj["aetherfall_qa_version"] = "v65"


def _set_world_vertex(obj, vertex, p):
    vertex.co = obj.matrix_world.inverted() @ p

def _reshape_authored_garment(obj, original_name):
    """Small, reversible silhouette pass over the existing authored garment.

    Work in world axes after glTF import (Blender Z-up) so the pass is stable
    even when source node transforms differ.
    """
    mn, mx = world_bounds(obj)
    center = (mn + mx) * 0.5
    height = max(1e-6, mx.z - mn.z)
    name = original_name.lower()
    side = 1.0 if center.x >= 0.0 else -1.0
    inv = obj.matrix_world.inverted()

    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        t = max(0.0, min(1.0, (p.z - mn.z) / height))

        if "sleeve" in name:
            # The source cap sleeves read like shoulder armor. Pull them inward
            # and make the cross-section slimmer while keeping a short cloth cap.
            p.x = center.x + (p.x - center.x) * 0.80
            p.y = center.y + (p.y - center.y) * 0.82
            p.z = center.z + (p.z - center.z) * 0.92
            p.x -= side * 0.010
            p.z -= 0.004

        elif "tunic_upper" in name:
            # Narrow the shoulder line progressively while retaining waist room.
            shoulder = 0.98 - 0.13 * (t ** 1.6)
            p.x = center.x + (p.x - center.x) * shoulder
            depth = 0.94 - 0.03 * t
            p.y = center.y + (p.y - center.y) * depth

        elif "tunic_lower" in name:
            # Slight peasant-shirt flare: restrained at the belt, freer at hem.
            flare = 0.965 + (1.0 - t) * 0.075
            p.x = center.x + (p.x - center.x) * flare
            p.y = center.y + (p.y - center.y) * (0.95 + (1.0 - t) * 0.035)
            # Break the perfectly horizontal hem very subtly.
            if t < 0.16:
                phase = (p.x - center.x) * 42.0
                p.z -= (0.16 - t) * 0.010 * (0.5 + 0.5 * math.sin(phase))

        elif "trousers" in name:
            # Baggy thigh/knee volume with a deliberate taper into the boot.
            bulge = math.sin(math.pi * t)
            radial = 0.82 + 0.19 * t + 0.13 * bulge
            p.x = center.x + (p.x - center.x) * radial
            p.y = center.y + (p.y - center.y) * (radial * 0.98)
            # Tiny asymmetrical cloth undulation; this is silhouette, not a fake
            # high-frequency wrinkle substitute for the later normal bake.
            p.x += side * 0.0025 * math.sin(t * math.pi * 5.0)
            p.y += 0.0020 * math.sin(t * math.pi * 6.0 + side)

        elif "bootshaft" in name:
            p.x = center.x + (p.x - center.x) * 0.94
            p.y = center.y + (p.y - center.y) * 0.92

        elif "bootfoot" in name:
            p.x = center.x + (p.x - center.x) * 0.92
            p.y = center.y + (p.y - center.y) * 0.90
            p.z = center.z + (p.z - center.z) * 0.96

        elif "cuff" in name:
            p.x = center.x + (p.x - center.x) * 0.96
            p.y = center.y + (p.y - center.y) * 0.95
            p.z = center.z + (p.z - center.z) * 0.72

        elif "belt" in name:
            p.x = center.x + (p.x - center.x) * 0.98
            p.y = center.y + (p.y - center.y) * 0.94
            p.z = center.z + (p.z - center.z) * 0.88

        v.co = inv @ p

    obj.data.update()
    for poly in obj.data.polygons:
        poly.use_smooth = True

def _material(name, color, roughness):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat

def _apply_garment_material(obj, original_name, part):
    n = original_name.lower()
    if "cuff" in n:
        mat = _material("AF_Linen_Boot_Wrap", (0.30, 0.225, 0.16), 0.88)
    elif part == "Tunic":
        mat = _material("AF_Worn_Linen_Tunic", (0.43, 0.405, 0.345), 0.93)
    elif part == "Trousers":
        mat = _material("AF_Patched_Wool_Trousers", (0.235, 0.175, 0.125), 0.96)
    elif part == "Boots":
        mat = _material("AF_Scuffed_Leather_Boots", (0.18, 0.115, 0.075), 0.82)
    else:
        mat = _material("AF_Plain_Leather_Belt", (0.26, 0.145, 0.085), 0.76)
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

def setup_render(body, garments, out_dir):
    scene = bpy.context.scene
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.020, 0.026, 0.038)

    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        try:
            scene.render.engine = "BLENDER_EEVEE"
        except Exception:
            pass

    b0, b1 = world_bounds(body)
    target = (b0 + b1) * 0.5
    height = max(0.1, b1.z - b0.z)
    dist = height * 2.15

    # Ground gives the boots a readable contact point.
    bpy.ops.mesh.primitive_plane_add(size=height * 4.0, location=(target.x, target.y, b0.z))
    floor = bpy.context.object
    mat = bpy.data.materials.new("AF_QA_Floor")
    mat.diffuse_color = (0.08, 0.09, 0.11, 1.0)
    floor.data.materials.append(mat)

    bpy.ops.object.light_add(type="AREA", location=(target.x - height, target.y - height, target.z + height))
    key = bpy.context.object
    key.data.energy = 310
    key.data.shape = "DISK"
    key.data.size = height * 1.2
    look_at(key, target)

    bpy.ops.object.light_add(type="AREA", location=(target.x + height, target.y + height * 0.3, target.z + height * 0.45))
    fill = bpy.context.object
    fill.data.energy = 145
    fill.data.size = height
    look_at(fill, target)

    bpy.ops.object.camera_add()
    cam = bpy.context.object
    scene.camera = cam

    views = {
        "front": Vector((target.x, target.y - dist, target.z + height * 0.02)),
        "front34": Vector((target.x + dist * 0.52, target.y - dist * 0.86, target.z + height * 0.02)),
        "side": Vector((target.x + dist, target.y, target.z + height * 0.02)),
        "back": Vector((target.x, target.y + dist, target.z + height * 0.02)),
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, pos in views.items():
        cam.location = pos
        look_at(cam, target)
        scene.render.filepath = str(out_dir / (name + ".png"))
        bpy.ops.render.render(write_still=True)

def main():
    a = parse_args()
    reset()
    import_glb(Path(a.input).resolve())
    rig = choose_rig()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.vertices)]
    garment_candidates = [m for m in meshes if is_legacy_garment(m)]
    if not garment_candidates:
        raise RuntimeError("No authored peasant garment candidates found in runtime model")
    body = choose_body(meshes, garment_candidates, rig)
    body.name = "AF_Body"
    rig.name = "AF_Armature"

    report_items = []
    counters = {"Tunic": 0, "Trousers": 0, "Boots": 0, "Belt": 0}
    for garment in garment_candidates:
        original_name = garment.name
        part = classify_part(garment, body)
        _reshape_authored_garment(garment, original_name)
        _apply_garment_material(garment, original_name, part)
        before = matching_weight_ratio(garment, rig)
        if before < 0.98:
            transfer_weights(body, garment, rig)
        clean_weights(garment)
        ensure_armature(garment, rig)
        counters[part] += 1
        tag_garment(garment, part, counters[part])
        after = matching_weight_ratio(garment, rig)
        garment.hide_viewport = False
        garment.hide_render = False
        garment["aetherfall_weight_coverage"] = float(after)
        report_items.append({
            "name": garment.name,
            "source_name": original_name,
            "part": part,
            "vertices": len(garment.data.vertices),
            "weight_ratio_before": before,
            "weight_ratio_after": after,
        })

    # Keep metadata on the character as well for Godot import tooling.
    body["aetherfall_body_profile"] = "male_anime_v1"
    body["aetherfall_body_regions"] = "Head,Neck,Torso,Pelvis,UpperArm.L,UpperArm.R,Forearm.L,Forearm.R,Hand.L,Hand.R,Thigh.L,Thigh.R,Calf.L,Calf.R,Foot.L,Foot.R"
    body["aetherfall_skeleton_profile"] = "AF_65"

    setup_render(body, garment_candidates, Path(a.render_dir).resolve())

    output = Path(a.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        export_apply=False,
        export_animations=True,
        export_skins=True,
        export_materials="EXPORT",
        export_extras=True,
        export_yup=True,
    )

    data = {
        "version": "v65",
        "input": str(Path(a.input).resolve()),
        "output": str(output),
        "armature_bones": len(rig.data.bones),
        "body": body.name,
        "authored_garment_objects": len(garment_candidates),
        "parts": counters,
        "garments": report_items,
        "uses_body_derived_shells": False,
        "mobile_influence_limit": 4,
        "metadata_in_gltf_extras": True,
    }
    report = Path(a.report).resolve()
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("AETHERFALL_MALE_PEASANT_V65_OK")
    print(json.dumps(data, indent=2))

if __name__ == "__main__":
    main()
