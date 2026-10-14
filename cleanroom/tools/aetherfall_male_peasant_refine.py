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
    # Weight transfer must happen in bind/rest space. If the imported GLB has
    # an active action, evaluating the source through its Armature modifier and
    # then adding another Armature to the new garment effectively double-poses
    # the generated mesh.
    previous_pose_position = getattr(rig.data, "pose_position", "POSE")
    rig.data.pose_position = "REST"
    source_armatures = [m for m in body.modifiers if m.type == "ARMATURE"]
    source_visibility = [(m, m.show_viewport, m.show_render) for m in source_armatures]
    for m, _, _ in source_visibility:
        m.show_viewport = False
        m.show_render = False
    bpy.context.view_layer.update()
    try:
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
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = garment
        garment.select_set(True)
        bpy.ops.object.modifier_apply(modifier=dt.name)
        garment.select_set(False)
    finally:
        for m, vp, rd in source_visibility:
            m.show_viewport = vp
            m.show_render = rd
        rig.data.pose_position = previous_pose_position
        bpy.context.view_layer.update()

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
    obj["aetherfall_qa_version"] = "v82"


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
            # Preserve the connected sleeve tube and only soften the cap.
            p.x = center.x + (p.x - center.x) * 0.90
            p.y = center.y + (p.y - center.y) * 0.91
            p.z = center.z + (p.z - center.z) * 0.95
            p.x -= side * 0.006
            p.z -= 0.002

        elif "tunic_upper" in name:
            # Narrow the shoulder line progressively while retaining waist room.
            shoulder = 0.98 - 0.13 * (t ** 1.6)
            p.x = center.x + (p.x - center.x) * shoulder
            depth = 0.94 - 0.03 * t
            p.y = center.y + (p.y - center.y) * depth
            # Turn the hard rectangular top edge into a softer cloth shoulder.
            halfw = max(1e-6, (mx.x - mn.x) * 0.5)
            edge = abs(p.x - center.x) / halfw
            if t > 0.72 and edge > 0.50:
                shoulder_edge = min(1.0, (edge - 0.50) / 0.50) * min(1.0, (t - 0.72) / 0.28)
                p.z -= 0.018 * shoulder_edge
                p.x = center.x + (p.x - center.x) * (1.0 - 0.055 * shoulder_edge)
            # Lower the front-center neckline into a shallow anime-fantasy scoop.
            if p.y < center.y and t > 0.78:
                neck = max(0.0, 1.0 - abs(p.x - center.x) / max(0.055, halfw * 0.48))
                p.z -= 0.018 * neck * min(1.0, (t - 0.78) / 0.22)

        elif "tunic_lower" in name:
            # Slight peasant-shirt flare: restrained at the belt, freer at hem.
            flare = 0.965 + (1.0 - t) * 0.075
            p.x = center.x + (p.x - center.x) * flare
            p.y = center.y + (p.y - center.y) * (0.95 + (1.0 - t) * 0.035)
            # Break the perfectly horizontal hem very subtly.
            # Close the old upper/lower tunic gap without moving the hem.
            p.z += 0.026 * t
            if t < 0.16:
                phase = (p.x - center.x) * 42.0
                p.z -= (0.16 - t) * 0.010 * (0.5 + 0.5 * math.sin(phase))

        elif "trousers" in name:
            # The source trouser mesh is already a connected tube. Keep it
            # outside the body and add only restrained peasant-style bunching.
            bulge = math.sin(math.pi * t)
            knee_bunch = math.exp(-((t - 0.34) / 0.18) ** 2)
            radial = 1.015 + 0.045 * bulge + 0.040 * knee_bunch
            p.x = center.x + (p.x - center.x) * radial
            p.y = center.y + (p.y - center.y) * (1.010 + 0.035 * bulge + 0.030 * knee_bunch)
            p.x += side * 0.0018 * knee_bunch * math.sin(t * math.pi * 5.0)
            p.y += 0.0018 * knee_bunch * math.sin(t * math.pi * 6.0 + side)

        elif "bootshaft" in name:
            # Source shaft is a complete tube: preserve coverage and taper gently.
            shaft_scale = 0.97 + 0.05 * t
            p.x = center.x + (p.x - center.x) * shaft_scale
            p.y = center.y + (p.y - center.y) * (0.98 + 0.04 * t)

        elif "bootfoot" in name:
            half_y = max(1e-6, (mx.y - mn.y) * 0.5)
            toe = max(0.0, min(1.0, (center.y - p.y) / half_y))
            toe_width = 1.04 - 0.02 * toe
            p.x = center.x + (p.x - center.x) * toe_width
            p.y = center.y + (p.y - center.y) * (1.03 + 0.015 * toe)
            p.z = center.z + (p.z - center.z) * 1.02
            if toe > 0.35:
                p.z -= 0.004 * toe

        elif "cuff" in name:
            p.x = center.x + (p.x - center.x) * 0.96
            p.y = center.y + (p.y - center.y) * 0.95
            p.z = center.z + (p.z - center.z) * 0.84

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
    if hasattr(mat, "use_backface_culling"):
        mat.use_backface_culling = False
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = 0.0
    return mat

def _apply_garment_material(obj, original_name, part):
    n = original_name.lower()
    if "cuff" in n:
        mat = _material("AF_Linen_Boot_Wrap", (0.115, 0.075, 0.045), 0.88)
    elif part == "Tunic":
        mat = _material("AF_Worn_Linen_Tunic", (0.300, 0.270, 0.215), 0.94)
    elif part == "Trousers":
        mat = _material("AF_Patched_Wool_Trousers", (0.125, 0.078, 0.045), 0.96)
    elif part == "Boots":
        mat = _material("AF_Scuffed_Leather_Boots", (0.070, 0.036, 0.018), 0.84)
    else:
        mat = _material("AF_Plain_Leather_Belt", (0.105, 0.050, 0.023), 0.78)
    obj.data.materials.clear()
    obj.data.materials.append(mat)



def _combined_bounds(objects):
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for obj in objects:
        mn, mx = world_bounds(obj)
        mins.x = min(mins.x, mn.x); mins.y = min(mins.y, mn.y); mins.z = min(mins.z, mn.z)
        maxs.x = max(maxs.x, mx.x); maxs.y = max(maxs.y, mx.y); maxs.z = max(maxs.z, mx.z)
    return mins, maxs

def _elliptic_tube(name, rings, segments=24):
    """Create an open quad tube from world-space elliptical rings."""
    verts = []
    faces = []
    for z, cx, cy, rx, ry in rings:
        for i in range(segments):
            a = (i / segments) * math.tau
            verts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry, z))
    for r in range(len(rings) - 1):
        base = r * segments
        nxt = (r + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base + i, nxt + i, nxt + j, base + j))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def _assign_rigid_weight(obj, rig, bone_name):
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    if rig.data.bones.get(bone_name) is None:
        raise RuntimeError("Rigid garment bone not found: " + bone_name)
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")

def _back_panel(name, rows, cols=7):
    """Create a cloth back panel. Each row is (z, cx, y, half_width, neck_dip)."""
    verts = []
    faces = []
    for row_index, (z, cx, y, halfw, dip) in enumerate(rows):
        for col in range(cols):
            nx = -1.0 + 2.0 * col / (cols - 1)
            local_z = z
            if row_index == 0:
                local_z -= dip * max(0.0, 1.0 - abs(nx) * 1.75)
            verts.append((cx + halfw * nx, y, local_z))
    for r in range(len(rows)-1):
        for col in range(cols-1):
            a = r * cols + col
            b = a + 1
            c2 = (r + 1) * cols + col + 1
            d = (r + 1) * cols + col
            # Winding points toward +Y (the character's back).
            faces.append((a, b, c2, d))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj

def _ellipsoid(name, center, scale, segments=20, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj



def _styled_tube(name, rings, segments=28, fold_strength=0.018, hem_wobble=0.0):
    """Build a complete low-poly cloth tube with authored broad folds.

    rings: (z, cx, cy, rx, ry, phase)
    """
    verts = []
    faces = []
    last = len(rings) - 1
    for r, (z, cx, cy, rx, ry, phase) in enumerate(rings):
        vertical = r / max(1, last)
        for i in range(segments):
            a = (i / segments) * math.tau
            # Large, readable cloth folds rather than noisy micro-displacement.
            wave = (
                math.sin(a * 3.0 + phase) * fold_strength +
                math.sin(a * 5.0 - phase * 0.7) * fold_strength * 0.42
            )
            # Folds gather more strongly through waist/mid sections.
            gather = 0.45 + 0.55 * math.sin(math.pi * vertical)
            radial = 1.0 + wave * gather
            px = cx + math.cos(a) * rx * radial
            py = cy + math.sin(a) * ry * (1.0 + wave * gather * 0.75)
            pz = z
            if r == last and hem_wobble:
                pz += hem_wobble * (
                    0.55 * math.sin(a * 2.0 + 0.65) +
                    0.35 * math.sin(a * 5.0 - 0.3)
                )
            verts.append((px, py, pz))
    for r in range(len(rings)-1):
        a0 = r * segments
        b0 = (r + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((a0 + i, b0 + i, b0 + j, a0 + j))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def _build_clean_tunic(body, part_objects):
    """Build one complete deformation-friendly tunic body.

    The imported Tunic_Upper/Lower meshes are dozens of disconnected fragments,
    so they are fit references only. Sleeves remain as their connected source
    tubes; this new torso provides continuous front/back/side cloth.
    """
    sources=[o for o in part_objects.get("Tunic",[])
             if "tunic_upper" in str(o.get("aetherfall_source_name","")).lower()
             or "tunic_lower" in str(o.get("aetherfall_source_name","")).lower()]
    if not sources:
        return []
    mn,mx=_combined_bounds(sources)
    bmn,bmx=world_bounds(body)
    cx=(mn.x+mx.x)*0.5
    cy=(bmn.y+bmx.y)*0.5
    hx=(mx.x-mn.x)*0.5
    source_hy=(mx.y-mn.y)*0.5
    body_hy=(bmx.y-bmn.y)*0.5
    hy=max(source_hy*0.88, body_hy*0.56)
    h=mx.z-mn.z
    rings=[
        (mx.z-h*0.018,cx,cy,hx*0.30,hy*0.42,0.00),
        (mx.z-h*0.070,cx,cy,hx*0.60,hy*0.78,0.18),
        (mx.z-h*0.135,cx,cy,hx*0.92,hy*0.98,0.38),
        (mx.z-h*0.245,cx,cy,hx*0.94,hy*1.03,0.65),
        (mx.z-h*0.375,cx,cy,hx*0.91,hy*1.04,0.95),
        (mx.z-h*0.515,cx,cy,hx*0.86,hy*1.00,1.25),
        (mx.z-h*0.645,cx,cy,hx*0.79,hy*0.94,1.60),
        (mx.z-h*0.735,cx,cy,hx*0.75,hy*0.90,1.95),
        (mx.z-h*0.825,cx,cy,hx*0.76,hy*0.91,2.25),
        (mx.z-h*0.910,cx,cy,hx*0.82,hy*0.95,2.55),
        (mn.z+h*0.010,cx,cy,hx*0.86,hy*0.97,2.90),
    ]
    tunic=_styled_tube("AF_Tunic_Complete",rings,36,fold_strength=0.038,hem_wobble=-h*0.018)
    tunic.data.materials.append(_material("AF_Worn_Linen_Tunic",(0.300,0.270,0.215),0.94))
    tunic["aetherfall_subpart"]="complete_tunic"
    for src in sources:
        src.hide_viewport=True
        src.hide_render=True
        src["aetherfall_replaced_source"]=True
    return [(tunic,"Tunic","complete_tunic",body)]

def _build_primary_cloth(body, rig, part_objects):
    """Replace the source's incomplete torso/trouser panels with full garments.

    The original Tripo clothing pieces are useful as fit references and weight
    donors, but their open backs/sides make them unsuitable as final geometry.
    """
    created = []

    tunic_sources = [
        o for o in part_objects.get("Tunic", [])
        if "tunic_upper" in str(o.get("aetherfall_source_name", "")).lower()
        or "tunic_lower" in str(o.get("aetherfall_source_name", "")).lower()
    ]
    if tunic_sources:
        mn, mx = _combined_bounds(tunic_sources)
        bmn, bmx = world_bounds(body)
        cx = (mn.x + mx.x) * 0.5
        # The Tripo front panels are intentionally biased toward the chest and
        # stop short of the back. Center the continuity garment on the BODY,
        # then keep it slightly inside the source panels so their folds remain
        # the visible outer layer.
        cy = (bmn.y + bmx.y) * 0.5
        hx = (mx.x - mn.x) * 0.5
        body_hy = (bmx.y - bmn.y) * 0.5
        depth = max(body_hy + 0.012, (mx.y - mn.y) * 0.44)
        h = mx.z - mn.z
        rings = [
            (mx.z - h*0.020, cx, cy, hx*0.28, depth*0.46, 0.00), # neck opening
            (mx.z - h*0.075, cx, cy, hx*0.62, depth*0.83, 0.18), # shoulder slope
            (mx.z - h*0.145, cx, cy, hx*0.86, depth*1.02, 0.36), # shoulder seam
            (mx.z - h*0.275, cx, cy, hx*0.81, depth*1.04, 0.70), # chest
            (mx.z - h*0.430, cx, cy, hx*0.76, depth*1.00, 1.02), # ribs
            (mx.z - h*0.585, cx, cy, hx*0.69, depth*0.94, 1.40), # waist
            (mx.z - h*0.720, cx, cy, hx*0.64, depth*0.91, 1.82), # belt gather
            (mx.z - h*0.795, cx, cy, hx*0.65, depth*0.90, 2.05), # under belt
            (mx.z - h*0.900, cx, cy, hx*0.70, depth*0.92, 2.42), # flare
            (mn.z + h*0.012, cx, cy, hx*0.74, depth*0.93, 2.82), # hem
        ]
        tunic = _styled_tube("AF_Tunic_FullUnderlay", rings, 32, fold_strength=0.026, hem_wobble=-h*0.014)
        tunic.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.190, 0.162, 0.124), 0.94))
        tunic["aetherfall_subpart"] = "full_tunic_underlay"
        created.append((tunic, "Tunic", "full_tunic_underlay", body))
        for src in tunic_sources:
            src["aetherfall_outer_detail"] = True

    trouser_sources = [
        o for o in part_objects.get("Trousers", [])
        if "trousers" in str(o.get("aetherfall_source_name", "")).lower()
    ]
    if trouser_sources:
        tmn, tmx = _combined_bounds(trouser_sources)
        tcx = (tmn.x + tmx.x) * 0.5
        tcy = (tmn.y + tmx.y) * 0.5
        thx = (tmx.x - tmn.x) * 0.5
        thy = (tmx.y - tmn.y) * 0.5
        th = tmx.z - tmn.z
        pelvis_rings = [
            (tmx.z + th*0.010, tcx, tcy, thx*0.76, thy*1.02, 0.2),
            (tmx.z - th*0.13,  tcx, tcy, thx*0.73, thy*0.98, 0.8),
            (tmx.z - th*0.22,  tcx, tcy, thx*0.69, thy*0.94, 1.2),
        ]
        pelvis = _styled_tube("AF_Trousers_PelvisUnderlay", pelvis_rings, 28, fold_strength=0.012)
        pelvis.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.095, 0.060, 0.038), 0.96))
        pelvis["aetherfall_subpart"] = "trouser_pelvis"
        created.append((pelvis, "Trousers", "trouser_pelvis", body))

        for src in trouser_sources:
            mn, mx = world_bounds(src)
            cx = (mn.x + mx.x) * 0.5
            cy = (mn.y + mx.y) * 0.5
            hx = (mx.x - mn.x) * 0.5
            hy = (mx.y - mn.y) * 0.5
            h = mx.z - mn.z
            side_phase = 0.45 if cx >= tcx else 1.25
            # Full leg sits just behind the original front/detail panel. Keep
            # enough rear depth to cover the body while preserving the fitted,
            # narrower peasant silhouette from the approved v46 checkpoint.
            rings = [
                (mx.z - h*0.01, cx, cy, hx*0.86, hy*1.00, side_phase),
                (mx.z - h*0.15, cx, cy, hx*0.91, hy*1.04, side_phase+0.45),
                (mx.z - h*0.34, cx, cy, hx*0.95, hy*1.06, side_phase+0.95),
                (mx.z - h*0.50, cx, cy, hx*1.00, hy*1.08, side_phase+1.50), # knee bunch
                (mx.z - h*0.61, cx, cy, hx*0.94, hy*1.03, side_phase+1.95),
                (mx.z - h*0.73, cx, cy, hx*0.86, hy*0.98, side_phase+2.35),
                (mx.z - h*0.85, cx, cy, hx*0.76, hy*0.93, side_phase+2.75),
                (mn.z + h*0.01, cx, cy, hx*0.67, hy*0.88, side_phase+3.05),
            ]
            leg = _styled_tube(
                "AF_Trouser_FullUnderlay_%s" % ("L" if cx >= tcx else "R"),
                rings, 22, fold_strength=0.022, hem_wobble=h*0.004
            )
            leg.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.086, 0.052, 0.032), 0.97))
            leg["aetherfall_subpart"] = "full_trouser_underlay"
            created.append((leg, "Trousers", "full_trouser_underlay", src))
            src["aetherfall_outer_detail"] = True

    return created


def _continuity_pieces(body, rig, part_objects):
    """Add authored cloth underlays only where the source garment is physically open.

    These are deliberately shaped from garment bounds, not copied/extruded from
    the body, so they solve the source model's open side/waist/crotch gaps
    without returning to the rejected painted-on shell approach.
    """
    created = []

    tunics = part_objects.get("Tunic", [])
    if tunics:
        mn, mx = _combined_bounds(tunics)
        cx = (mn.x + mx.x) * 0.5
        cy = (mn.y + mx.y) * 0.5
        hx = (mx.x - mn.x) * 0.5
        hy = (mx.y - mn.y) * 0.5
        h = mx.z - mn.z
        rings = [
            (mx.z - h * 0.015, cx, cy, hx * 0.40, hy * 0.34),  # neck opening
            (mx.z - h * 0.14,  cx, cy, hx * 0.73, hy * 0.64),  # shoulder/chest
            (mx.z - h * 0.43,  cx, cy, hx * 0.71, hy * 0.62),  # chest
            (mx.z - h * 0.70,  cx, cy, hx * 0.66, hy * 0.58),  # waist
            (mn.z + h * 0.02,  cx, cy, hx * 0.73, hy * 0.62),  # loose hem
        ]
        under = _elliptic_tube("AF_Tunic_ContinuityUnderlay", rings, 28)
        under.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.205, 0.175, 0.135), 0.93))
        under["aetherfall_subpart"] = "continuity_underlay"
        created.append((under, "Tunic", "continuity_underlay"))

        # The imported source tunic has a deliberately unusable open back.
        # Build one lightweight authored back panel with a shallow neckline,
        # shoulder width, waist suppression and lower-hem flare.
        back_y = cy + hy * 0.96
        rows = [
            (mx.z - h * 0.035, cx, cy + hy * 0.84, hx * 0.78, h * 0.050),
            (mx.z - h * 0.17,  cx, back_y,          hx * 0.84, 0.0),
            (mx.z - h * 0.45,  cx, back_y,          hx * 0.76, 0.0),
            (mx.z - h * 0.70,  cx, cy + hy * 0.91, hx * 0.68, 0.0),
            (mn.z + h * 0.02,  cx, cy + hy * 0.87, hx * 0.79, 0.0),
        ]
        back = _back_panel("AF_Tunic_BackPanel", rows, 7)
        back.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.205, 0.175, 0.135), 0.93))
        back["aetherfall_subpart"] = "back_panel"
        created.append((back, "Tunic", "back_panel"))

    trousers = part_objects.get("Trousers", [])
    if trousers:
        mn, mx = _combined_bounds(trousers)
        cx = (mn.x + mx.x) * 0.5
        cy = (mn.y + mx.y) * 0.5
        hx = (mx.x - mn.x) * 0.5
        hy = (mx.y - mn.y) * 0.5
        # An inset pelvis/crotch cloth bridge, almost entirely hidden by the
        # outer trouser legs and tunic but visible where the source had a hole.
        top = mx.z + 0.004
        bottom = mx.z - max(0.075, (mx.z - mn.z) * 0.28)
        rings = [
            (top, cx, cy, hx * 0.76, hy * 0.68),
            (bottom, cx, cy, hx * 0.62, hy * 0.58),
        ]
        bridge = _elliptic_tube("AF_Trouser_PelvisUnderlay", rings, 24)
        bridge.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.095, 0.060, 0.038), 0.96))
        bridge["aetherfall_subpart"] = "pelvis_underlay"
        created.append((bridge, "Trousers", "pelvis_underlay"))

        # Each source trouser leg is also incomplete at the rear. A smaller
        # full tube underneath preserves the authored outer folds while
        # guaranteeing cloth coverage through knee/ankle poses.
        for leg_index, leg in enumerate(trousers, start=1):
            lmn, lmx = world_bounds(leg)
            lcx = (lmn.x + lmx.x) * 0.5
            lcy = (lmn.y + lmx.y) * 0.5
            lhx = (lmx.x - lmn.x) * 0.5
            lhy = (lmx.y - lmn.y) * 0.5
            lh = lmx.z - lmn.z
            leg_rings = [
                (lmx.z - lh * 0.02, lcx, lcy, lhx * 0.76, lhy * 0.66),
                (lmn.z + lh * 0.48, lcx, lcy, lhx * 0.74, lhy * 0.64),
                (lmn.z + lh * 0.02, lcx, lcy, lhx * 0.62, lhy * 0.56),
            ]
            leg_under = _elliptic_tube("AF_Trouser_LegUnderlay_%d" % leg_index, leg_rings, 20)
            leg_under.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.095, 0.060, 0.038), 0.96))
            leg_under["aetherfall_subpart"] = "leg_underlay"
            created.append((leg_under, "Trousers", "leg_underlay"))

    # Add two thin irregular-looking wrap bands per boot shaft. They give the
    # otherwise simple mobile boot silhouette a layered peasant construction.
    boots = part_objects.get("Boots", [])
    shafts = [o for o in boots if "bootshaft" in str(o.get("aetherfall_source_name", "")).lower()]
    for shaft in shafts:
        mn, mx = world_bounds(shaft)
        cx = (mn.x + mx.x) * 0.5
        cy = (mn.y + mx.y) * 0.5
        rx = (mx.x - mn.x) * 0.52
        ry = (mx.y - mn.y) * 0.52
        h = mx.z - mn.z
        for band_index, frac in enumerate((0.34, 0.68), start=1):
            zc = mn.z + h * frac
            thick = max(0.007, h * 0.065)
            rings = [
                (zc - thick * 0.5, cx, cy, rx * 1.04, ry * 1.04),
                (zc + thick * 0.5, cx, cy, rx * 1.06, ry * 1.06),
            ]
            band = _elliptic_tube("AF_Boot_Wrap_%s_%d" % ("L" if cx >= 0 else "R", band_index), rings, 18)
            band.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.048, 0.023, 0.012), 0.84))
            band["aetherfall_subpart"] = "boot_wrap"
            band["aetherfall_rigid_bone"] = "mixamorig:LeftLeg" if cx >= 0 else "mixamorig:RightLeg"
            created.append((band, "Boots", "boot_wrap"))

        # Fill the source shaft's open rear with a smaller rigid leather tube.
        shaft_rings = [
            (mx.z - h * 0.02, cx, cy, rx * 0.79, ry * 0.74),
            (mn.z + h * 0.02, cx, cy, rx * 0.72, ry * 0.70),
        ]
        shaft_under = _elliptic_tube("AF_Boot_ShaftUnderlay_%s" % ("L" if cx >= 0 else "R"), shaft_rings, 18)
        shaft_under.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.055, 0.028, 0.014), 0.82))
        shaft_under["aetherfall_subpart"] = "boot_shaft_underlay"
        shaft_under["aetherfall_rigid_bone"] = "mixamorig:LeftLeg" if cx >= 0 else "mixamorig:RightLeg"
        created.append((shaft_under, "Boots", "boot_shaft_underlay"))

    feet = [o for o in boots if "bootfoot" in str(o.get("aetherfall_source_name", "")).lower()]
    for foot in feet:
        mn, mx = world_bounds(foot)
        center = (mn + mx) * 0.5
        sx = max(0.01, (mx.x - mn.x) * 0.38)
        sy = max(0.01, (mx.y - mn.y) * 0.40)
        sz = max(0.01, (mx.z - mn.z) * 0.34)
        fill = _ellipsoid("AF_Boot_FootUnderlay_%s" % ("L" if center.x >= 0 else "R"), center, (sx, sy, sz), 18, 8)
        fill.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.055, 0.028, 0.014), 0.82))
        fill["aetherfall_subpart"] = "boot_foot_underlay"
        fill["aetherfall_rigid_bone"] = "mixamorig:LeftFoot" if center.x >= 0 else "mixamorig:RightFoot"
        created.append((fill, "Boots", "boot_foot_underlay"))

    return created





def _boundary_edges(obj):
    counts = {}
    for poly in obj.data.polygons:
        vs = list(poly.vertices)
        for i in range(len(vs)):
            a, b = vs[i], vs[(i+1) % len(vs)]
            key = (min(a,b), max(a,b))
            counts[key] = counts.get(key, 0) + 1
    return [edge for edge, count in counts.items() if count == 1]

def _build_side_seam_strip(source, body_center_y, back_offset, name, part):
    mn, mx = world_bounds(source)
    center_x = (mn.x + mx.x) * 0.5
    half_x = max(1e-6, (mx.x - mn.x) * 0.5)
    height = max(1e-6, mx.z - mn.z)
    verts, faces = [], []
    for a_idx, b_idx in _boundary_edges(source):
        pa = source.matrix_world @ source.data.vertices[a_idx].co
        pb = source.matrix_world @ source.data.vertices[b_idx].co
        mid = (pa + pb) * 0.5
        zt = (mid.z - mn.z) / height
        xt = abs(mid.x - center_x) / half_x
        # Side seams only: reject hem/neck openings and central cutouts.
        if xt < 0.60 or zt < 0.06 or zt > 0.96:
            continue
        qa = pa.copy(); qb = pb.copy()
        qa.y = 2.0 * body_center_y - pa.y
        qb.y = 2.0 * body_center_y - pb.y
        if qa.y > body_center_y: qa.y += back_offset
        if qb.y > body_center_y: qb.y += back_offset
        base = len(verts)
        verts.extend([tuple(pa), tuple(pb), tuple(qb), tuple(qa)])
        faces.append((base, base+1, base+2, base+3))
    if not faces:
        return None
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if part == "Tunic":
        obj.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.205,0.175,0.135), 0.93))
    elif part == "Trousers":
        obj.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.095,0.060,0.038), 0.96))
    else:
        obj.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.055,0.028,0.014), 0.82))
    obj["aetherfall_subpart"] = "side_seam_bridge"
    return obj

def _mirror_back_copy(source, body_center_y, back_offset, label):
    dup = source.copy()
    dup.data = source.data.copy()
    bpy.context.collection.objects.link(dup)
    dup.name = source.name + "_" + label
    inv = dup.matrix_world.inverted()
    for v in dup.data.vertices:
        p = dup.matrix_world @ v.co
        p.y = 2.0 * body_center_y - p.y
        if p.y > body_center_y:
            p.y += back_offset
        v.co = inv @ p
    try:
        dup.data.flip_normals()
    except Exception:
        pass
    dup.data.update()
    for poly in dup.data.polygons:
        poly.use_smooth = True
    return dup

def _build_mirrored_back_panels(body, part_objects):
    """Complete the source outfit by reflecting its authored front/detail panels.

    This preserves the source folds and exact skin weights instead of replacing
    them with smooth body shells. The mirrored pieces overlap at the side seams
    and sit a few millimeters farther behind the body to avoid z-fighting.
    """
    bmn, bmx = world_bounds(body)
    body_cy = (bmn.y + bmx.y) * 0.5
    created = []

    for src in part_objects.get("Tunic", []):
        source_name = str(src.get("aetherfall_source_name", "")).lower()
        if "tunic_upper" not in source_name and "tunic_lower" not in source_name:
            continue
        back = _mirror_back_copy(src, body_cy, 0.0065, "Back")
        back["aetherfall_subpart"] = "mirrored_tunic_back"
        back["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
        created.append((back, "Tunic", "mirrored_tunic_back"))
        seam = _build_side_seam_strip(src, body_cy, 0.0065, src.name + "_SideSeam", "Tunic")
        if seam is not None:
            seam["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
            created.append((seam, "Tunic", "side_seam_bridge"))

    for src in part_objects.get("Trousers", []):
        source_name = str(src.get("aetherfall_source_name", "")).lower()
        if "trousers" not in source_name:
            continue
        back = _mirror_back_copy(src, body_cy, 0.0045, "Back")
        back["aetherfall_subpart"] = "mirrored_trouser_back"
        back["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
        created.append((back, "Trousers", "mirrored_trouser_back"))
        seam = _build_side_seam_strip(src, body_cy, 0.0045, src.name + "_SideSeam", "Trousers")
        if seam is not None:
            seam["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
            created.append((seam, "Trousers", "side_seam_bridge"))

    for src in part_objects.get("Boots", []):
        source_name = str(src.get("aetherfall_source_name", "")).lower()
        if "bootshaft" in source_name:
            back = _mirror_back_copy(src, body_cy, 0.0025, "Back")
            back["aetherfall_subpart"] = "mirrored_bootshaft_back"
            back["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
            created.append((back, "Boots", "mirrored_bootshaft_back"))
            seam = _build_side_seam_strip(src, body_cy, 0.0025, src.name + "_SideSeam", "Boots")
            if seam is not None:
                seam["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
                created.append((seam, "Boots", "side_seam_bridge"))
        elif "bootfoot" in source_name:
            heel = _mirror_back_copy(src, body_cy, 0.0020, "Heel")
            heel["aetherfall_subpart"] = "mirrored_bootfoot_heel"
            heel["aetherfall_mirror_source"] = str(src.get("aetherfall_source_name", src.name))
            created.append((heel, "Boots", "mirrored_bootfoot_heel"))

    return created


def _back_half_tube(name, rings, segments=18):
    verts, faces = [], []
    for z, cx, cy, rx, ry in rings:
        for i in range(segments + 1):
            a = math.pi * i / segments
            verts.append((cx + math.cos(a) * rx, cy + math.sin(a) * ry, z))
    stride = segments + 1
    for r in range(len(rings)-1):
        for i in range(segments):
            a = r*stride + i
            b = a + 1
            c2 = (r+1)*stride + i + 1
            d = (r+1)*stride + i
            faces.append((a, d, c2, b))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = True
    return obj

def _build_gap_fillers(body, part_objects):
    created = []
    tunics = part_objects.get("Tunic", [])
    uppers = [o for o in tunics if "tunic_upper" in str(o.get("aetherfall_source_name","")).lower()]
    lowers = [o for o in tunics if "tunic_lower" in str(o.get("aetherfall_source_name","")).lower()]
    if uppers and lowers:
        umn, umx = _combined_bounds(uppers)
        lmn, lmx = _combined_bounds(lowers)
        bmn, bmx = world_bounds(body)
        cx = (bmn.x + bmx.x) * 0.5
        cy = (bmn.y + bmx.y) * 0.5
        bhx = (bmx.x - bmn.x) * 0.5
        bhy = (bmx.y - bmn.y) * 0.5

        zc = (umn.z + lmx.z) * 0.5
        half_h = max(0.020, abs(umn.z - lmx.z) * 0.62)
        waist = _elliptic_tube("AF_Tunic_WaistBridge", [
            (zc-half_h, cx, cy, bhx*0.54, bhy*0.91),
            (zc+half_h, cx, cy, bhx*0.56, bhy*0.93),
        ], 24)
        waist.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.190,0.162,0.124), 0.94))
        waist["aetherfall_subpart"] = "waist_bridge"
        created.append((waist, "Tunic", "waist_bridge", body))

        uh = umx.z - umn.z
        back_y = bmx.y + 0.005
        rows = [
            (umx.z - uh*0.055, cx, back_y, bhx*0.30, uh*0.018),
            (umx.z - uh*0.135, cx, back_y+0.002, bhx*0.62, 0.0),
            (umx.z - uh*0.235, cx, back_y+0.003, bhx*0.72, 0.0),
            (umx.z - uh*0.330, cx, back_y+0.002, bhx*0.64, 0.0),
        ]
        rear = _back_panel("AF_Tunic_BackYoke", rows, 11)
        rear.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.190,0.162,0.124), 0.94))
        rear["aetherfall_subpart"] = "back_yoke"
        created.append((rear, "Tunic", "back_yoke", body))
    return created

def evaluated_world_bounds(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    eo = obj.evaluated_get(deps)
    mesh = eo.to_mesh()
    try:
        pts = [eo.matrix_world @ v.co for v in mesh.vertices]
        if not pts:
            return world_bounds(obj)
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return mn, mx
    finally:
        eo.to_mesh_clear()


def _build_rear_coverage_patches(body, part_objects):
    """Small rear-only cloth patches for source meshes that are open at the back."""
    created = []
    bmn, bmx = world_bounds(body)
    cx = (bmn.x + bmx.x) * 0.5
    back_y = bmx.y + 0.004
    body_hx = (bmx.x - bmn.x) * 0.5

    uppers = [o for o in part_objects.get("Tunic", [])
              if "tunic_upper" in str(o.get("aetherfall_source_name","")).lower()]
    if uppers:
        umn, umx = _combined_bounds(uppers)
        h = umx.z - umn.z
        rows = [
            (umx.z - h*0.075, cx, back_y, body_hx*0.66, h*0.010),
            (umx.z - h*0.20,  cx, back_y+0.002, body_hx*0.78, 0.0),
            (umx.z - h*0.42,  cx, back_y+0.001, body_hx*0.72, 0.0),
            (umn.z + h*0.22,  cx, back_y, body_hx*0.58, 0.0),
        ]
        patch = _back_panel("AF_Tunic_ShoulderBackPatch", rows, 9)
        patch.data.materials.append(_material("AF_Worn_Linen_Tunic", (0.188,0.160,0.122), 0.94))
        patch["aetherfall_subpart"] = "shoulder_back_patch"
        created.append((patch, "Tunic", "shoulder_back_patch", body))

    for src in part_objects.get("Trousers", []):
        source_name = str(src.get("aetherfall_source_name","")).lower()
        if "trousers" not in source_name:
            continue
        mn, mx = world_bounds(src)
        h = mx.z - mn.z
        cx_leg = (mn.x + mx.x) * 0.5
        cy_leg = (mn.y + mx.y) * 0.5
        hx = (mx.x - mn.x) * 0.5
        hy = (mx.y - mn.y) * 0.5
        rear = _back_half_tube("AF_Trouser_LowerRearFill", [
            (mn.z + h*0.56, cx_leg, cy_leg, hx*0.88, hy*1.02),
            (mn.z + h*0.36, cx_leg, cy_leg, hx*0.84, hy*1.03),
            (mn.z + h*0.18, cx_leg, cy_leg, hx*0.78, hy*1.02),
            (mn.z + h*0.04, cx_leg, cy_leg, hx*0.68, hy*1.00),
        ], 14)
        rear.data.materials.append(_material("AF_Patched_Wool_Trousers", (0.086,0.052,0.032), 0.97))
        rear["aetherfall_subpart"] = "lower_rear_fill"
        created.append((rear, "Trousers", "lower_rear_fill", src))

    return created


def _side_panel(name, x, y_front, y_back, z_top, z_bottom, rows=5, cols=5):
    verts, faces = [], []
    for r in range(rows):
        tz = r / max(1, rows-1)
        z = z_top + (z_bottom-z_top)*tz
        # Slight inward taper toward waist/hem.
        xoff = 0.004 * math.sin(math.pi * tz)
        for col in range(cols):
            ty = col / max(1, cols-1)
            y = y_front + (y_back-y_front)*ty
            verts.append((x + xoff*(1 if x >= 0 else -1), y, z))
    for r in range(rows-1):
        for col in range(cols-1):
            a = r*cols+col
            b = a+1
            c2 = (r+1)*cols+col+1
            d = (r+1)*cols+col
            faces.append((a,d,c2,b))
    mesh=bpy.data.meshes.new(name+"_Mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth=True
    return obj

def _build_gussets(body, part_objects):
    """Traditional-style side/rear gussets close large panel openings cleanly."""
    created=[]
    bmn,bmx=world_bounds(body)

    tunics=part_objects.get("Tunic",[])
    if tunics:
        mn,mx=_combined_bounds(tunics)
        height=mx.z-mn.z
        y_front=min(mn.y, bmn.y)-0.004
        y_back=max(2.0*((bmn.y+bmx.y)*0.5)-mn.y, bmx.y)+0.006
        z_top=mx.z-height*0.30
        z_bottom=mn.z+height*0.06
        for side, x in (("L", mx.x+0.004), ("R", mn.x-0.004)):
            panel=_side_panel("AF_Tunic_SideGusset_"+side,x,y_front,y_back,z_top,z_bottom,6,6)
            panel.data.materials.append(_material("AF_Worn_Linen_Tunic",(0.188,0.160,0.122),0.94))
            panel["aetherfall_subpart"]="side_gusset"
            created.append((panel,"Tunic","side_gusset",body))

    for src in part_objects.get("Trousers",[]):
        source_name=str(src.get("aetherfall_source_name","")).lower()
        if "trousers" not in source_name:
            continue
        mn,mx=world_bounds(src)
        h=mx.z-mn.z
        cx=(mn.x+mx.x)*0.5
        back_y=max(mx.y, bmx.y*0.55)+0.004
        rows=[
            (mn.z+h*0.58,cx,back_y,(mx.x-mn.x)*0.34,0.0),
            (mn.z+h*0.38,cx,back_y+0.002,(mx.x-mn.x)*0.33,0.0),
            (mn.z+h*0.18,cx,back_y+0.001,(mx.x-mn.x)*0.30,0.0),
            (mn.z+h*0.05,cx,back_y,(mx.x-mn.x)*0.26,0.0),
        ]
        patch=_back_panel("AF_Trouser_RearGusset",rows,7)
        patch.data.materials.append(_material("AF_Patched_Wool_Trousers",(0.090,0.055,0.034),0.97))
        patch["aetherfall_subpart"]="rear_leg_gusset"
        created.append((patch,"Trousers","rear_leg_gusset",src))
    return created

def _build_boot_layers(body, rig, part_objects):
    created = []
    boots = part_objects.get("Boots", [])
    shafts = [o for o in boots if "bootshaft" in str(o.get("aetherfall_source_name", "")).lower()]
    for shaft in shafts:
        mn, mx = world_bounds(shaft)
        cx = (mn.x + mx.x) * 0.5
        cy = (mn.y + mx.y) * 0.5
        rx = (mx.x - mn.x) * 0.50
        ry = (mx.y - mn.y) * 0.50
        h = mx.z - mn.z
        side = "L" if cx >= 0 else "R"
        bone = "mixamorig:LeftLeg" if cx >= 0 else "mixamorig:RightLeg"
        # Closed shaft underlay prevents calf/heel holes while the original
        # source leather remains visible as the outer sculpt.
        shaft_rings = [
            (mx.z - h*0.04, cx, cy, rx*0.80, ry*0.76),
            (mn.z + h*0.05, cx, cy, rx*0.72, ry*0.69),
        ]
        under = _elliptic_tube("AF_Boot_ShaftFill_" + side, shaft_rings, 20)
        under.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.050,0.024,0.012), 0.84))
        under["aetherfall_subpart"] = "boot_shaft_fill"
        under["aetherfall_rigid_bone"] = bone
        created.append((under, "Boots", "boot_shaft_fill"))
        for idx, frac in enumerate((0.28, 0.56, 0.80), start=1):
            zc = mn.z + h*frac
            thick = max(0.006, h*0.055)
            band = _elliptic_tube("AF_Boot_Wrap_%s_%d" % (side, idx), [
                (zc-thick*0.5, cx, cy, rx*0.99, ry*0.98),
                (zc+thick*0.5, cx, cy, rx*1.04, ry*1.02),
            ], 18)
            band.data.materials.append(_material("AF_Boot_Wrap_Leather", (0.037,0.017,0.009), 0.87))
            band["aetherfall_subpart"] = "boot_wrap"
            band["aetherfall_rigid_bone"] = bone
            created.append((band, "Boots", "boot_wrap"))

    feet = [o for o in boots if "bootfoot" in str(o.get("aetherfall_source_name", "")).lower()]
    for foot in feet:
        mn, mx = world_bounds(foot)
        center = (mn + mx) * 0.5
        side = "L" if center.x >= 0 else "R"
        bone = "mixamorig:LeftFoot" if center.x >= 0 else "mixamorig:RightFoot"
        # Slightly inset rounded leather fill closes exposed toes/heels.
        fill = _ellipsoid(
            "AF_Boot_FootFill_" + side,
            center + Vector((0.0, (mn.y-mx.y)*0.015, 0.0)),
            (
                max(0.012, (mx.x-mn.x)*0.34),
                max(0.018, (mx.y-mn.y)*0.39),
                max(0.012, (mx.z-mn.z)*0.31),
            ),
            18, 8
        )
        fill.data.materials.append(_material("AF_Scuffed_Leather_Boots", (0.050,0.024,0.012), 0.84))
        fill["aetherfall_subpart"] = "boot_foot_fill"
        fill["aetherfall_rigid_bone"] = bone
        created.append((fill, "Boots", "boot_foot_fill"))
    return created


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

def setup_render(body, garments, rig, out_dir):
    scene = bpy.context.scene
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.020, 0.026, 0.038)
    scene.view_settings.exposure = -0.65
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass

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

    # Deformation stress checkpoints: use the imported actions directly so
    # shoulder, hip, knee and ankle failures are visible before Godot import.
    previous_action = rig.animation_data.action if rig.animation_data else None
    previous_frame = scene.frame_current
    stress_views = {
        "walk_front": ("walk", views["front"]),
        "walk_34": ("walk", views["front34"]),
        "run_front": ("run", views["front"]),
        "run_34": ("run", views["front34"]),
    }
    actions = list(bpy.data.actions)
    for filename, (needle, pos) in stress_views.items():
        action = next((a for a in actions if needle in a.name.lower()), None)
        if action is None:
            continue
        rig.animation_data_create()
        rig.animation_data.action = action
        start, end = action.frame_range
        frame = int(round(start + (end-start) * (0.44 if needle == "walk" else 0.38)))
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        pmn, pmx = evaluated_world_bounds(body)
        pose_target = (pmn + pmx) * 0.5
        pose_height = max(0.1, pmx.z - pmn.z)
        pose_dist = pose_height * 2.15
        if filename.endswith("_34"):
            cam.location = Vector((pose_target.x + pose_dist * 0.52, pose_target.y - pose_dist * 0.86, pose_target.z + pose_height * 0.02))
        else:
            cam.location = Vector((pose_target.x, pose_target.y - pose_dist, pose_target.z + pose_height * 0.02))
        look_at(cam, pose_target)
        scene.render.filepath = str(out_dir / (filename + ".png"))
        bpy.ops.render.render(write_still=True)
    if rig.animation_data:
        rig.animation_data.action = previous_action
    scene.frame_set(previous_frame)

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
    part_objects = {"Tunic": [], "Trousers": [], "Boots": [], "Belt": []}
    for garment in garment_candidates:
        original_name = garment.name
        part = classify_part(garment, body)
        garment["aetherfall_source_name"] = original_name
        _reshape_authored_garment(garment, original_name)
        _apply_garment_material(garment, original_name, part)
        before = matching_weight_ratio(garment, rig)
        if before < 0.98:
            transfer_weights(body, garment, rig)
        clean_weights(garment)
        ensure_armature(garment, rig)
        counters[part] += 1
        tag_garment(garment, part, counters[part])
        garment["aetherfall_source_name"] = original_name
        part_objects[part].append(garment)
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

    continuity_count = 0
    for extra, part, subpart, weight_source in _build_clean_tunic(body, part_objects):
        transfer_weights(weight_source, extra, rig)
        clean_weights(extra)
        ensure_armature(extra, rig)
        counters[part] += 1
        tag_garment(extra, part, counters[part])
        extra["aetherfall_subpart"] = subpart
        ratio = matching_weight_ratio(extra, rig)
        garment_candidates.append(extra)
        continuity_count += 1
        report_items.append({
            "name": extra.name,
            "source_name": "Aetherfall complete authored tunic",
            "part": part,
            "vertices": len(extra.data.vertices),
            "weight_ratio_before": 0.0,
            "weight_ratio_after": ratio,
            "subpart": subpart,
        })

    filler_count = 0
    rear_patch_count = 0
    gusset_count = 0
    boot_layer_count = 0

    # Keep metadata on the character as well for Godot import tooling.
    body["aetherfall_body_profile"] = "male_anime_v1"
    body["aetherfall_body_regions"] = "Head,Neck,Torso,Pelvis,UpperArm.L,UpperArm.R,Forearm.L,Forearm.R,Hand.L,Hand.R,Thigh.L,Thigh.R,Calf.L,Calf.R,Foot.L,Foot.R"
    body["aetherfall_skeleton_profile"] = "AF_65"

    setup_render(body, garment_candidates, rig, Path(a.render_dir).resolve())

    for obj in list(bpy.context.scene.objects):
        if bool(obj.get("aetherfall_replaced_source", False)):
            bpy.data.objects.remove(obj, do_unlink=True)

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
        "version": "v82",
        "input": str(Path(a.input).resolve()),
        "output": str(output),
        "armature_bones": len(rig.data.bones),
        "body": body.name,
        "authored_garment_objects": len(garment_candidates),
        "complete_tunic_pieces": continuity_count,
        "targeted_gap_fillers": filler_count,
        "rear_coverage_patches": rear_patch_count,
        "gusset_pieces": gusset_count,
        "boot_layer_pieces": boot_layer_count,
        "parts": counters,
        "garments": report_items,
        "uses_body_derived_shells": False,
        "mobile_influence_limit": 4,
        "metadata_in_gltf_extras": True,
    }
    report = Path(a.report).resolve()
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("AETHERFALL_MALE_PEASANT_V82_OK")
    print(json.dumps(data, indent=2))

if __name__ == "__main__":
    main()
