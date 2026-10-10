"""Headless Blender pipeline proof for Aetherfall's original rigged anime avatar.

Usage (from repo root):
  python3 tools/generate_avatar_v033.py
  blender -b -t 2 --python tools/blender_character_pipeline.py

This first pass intentionally preserves all existing meshes, skins, animations,
materials, and appearance mesh names. Future work can sculpt the character in
Blender instead of adding more procedural Godot shape code.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path.cwd()
SOURCE = ROOT / "assets/characters/aetherfall_adventurer.gltf"
BLEND = ROOT / "builds/Aetherfall-Anime-Character-Editable.blend"
GLB = ROOT / "builds/Aetherfall-Anime-Character-Blender.glb"
assert SOURCE.is_file(), f"Generate the avatar first: {SOURCE}"
BLEND.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
assert len(meshes) > 100, f"Unexpected missing avatar geometry: {len(meshes)} meshes"
assert armatures, "No armature imported"
skeleton = max(armatures, key=lambda obj: len(obj.data.bones))
assert len(skeleton.data.bones) >= 17, "Blender rig import failed"
for name in ("Head", "LeftShin", "RightShin", "LeftFoot", "RightFoot"):
    assert name in skeleton.data.bones, f"Missing rig joint: {name}"

# Anime sculpt pass 01. These are actual editable mesh vertex changes within
# Blender, not an engine-only tint or a static concept-image mockup.
#
# Blender uses Z-up; glTF's original character uses Y-up, so edit in the
# object's world space (converted by the imported glTF root transform).
# Import maintains armature weights. Never transform armature or bind matrices.
def sculpt_world(obj, fn):
    inv = obj.matrix_world.inverted_safe()
    mat = obj.matrix_world
    for vertex in obj.data.vertices:
        pt = mat @ vertex.co
        vertex.co = inv @ fn(pt)
    obj.data.update()

def change_world(obj, xscale=1.0, zscale=1.0, shiftx=0.0, shifty=0.0):
    origin = obj.matrix_world.translation.copy()
    def transform(p):
        q=p.copy()
        q.x=origin.x+(q.x-origin.x)*xscale+shiftx
        q.y=origin.y+(q.y-origin.y)*zscale+shifty
        return q
    sculpt_world(obj,transform)

haircounts={"Windswept":0,"Long":0,"Short":0,"Ponytail":0}
for obj in meshes:
    name=obj.name
    if name.startswith("Hair_"):
        obj.color = (0.30, 0.37, 0.57, 1.0)
        for style in haircounts:
            if name.startswith("Hair_"+style):
                haircounts[style]+=1
        # Long and ponytail rear pieces gain real projected silhouette.
        if name.startswith("Hair_Long") and (
            "RearVolume" in name or "Rear" in name or "SideLayer" in name):
            change_world(obj,xscale=1.14,zscale=1.14)
        elif name.startswith("Hair_Ponytail") and (
            "Cascade" in name or "Rear" in name):
            change_world(obj,xscale=1.13,zscale=1.10)
        elif name.startswith("Hair_Windswept") and (
            "CrownLift" in name or "Fringe" in name):
            change_world(obj,xscale=1.17,shiftx=.017)
        elif name.startswith("Hair_Short") and (
            "CrownLift" in name or "Fringe" in name):
            change_world(obj,xscale=.94)
    elif name.startswith("Outfit_"):
        obj.color = (0.23, 0.49, 0.72, 1.0)

# Reduce head shape's uniform roundness: sculpt cheeks in toward the jaw,
# widen the brow subtly, and keep the chin pointed. The same shape is used
# for every user-customized skin tone and hairstyle.
for obj in meshes:
    if obj.name.startswith("Skin_Head"):
        def sculpt_head(pt):
            q=pt.copy()
            # Head bottom is around 1.72m in model-space Y => Blender Z.
            t=max(0.0,min(1.0,(q.z-1.74)/.28))
            xfactor=.86+.14*t
            q.x *= xfactor
            # Slightly flatten the center face's depth for stylized anime eyes.
            if q.y>0:
                q.y *= (.96+.04*t)
            return q
        # Blender importer may place asset along Z due to glTF unit conversion.
        sculpt_world(obj,sculpt_head)
    # Keep feet slimmer but let the toes read as actual footwear.
    if obj.name in ("Body_LeftBoot","Body_RightBoot"):
        def sculpt_boot(pt):
            q=pt.copy()
            q.x *= .95
            return q
        sculpt_world(obj,sculpt_boot)

# Shade smooth on curved skinned surfaces only. Preserve deliberately flat
# anime eye/iris highlights and graphic clothing seams.
for obj in meshes:
    if obj.type!="MESH":
        continue
    if obj.name.startswith(("Skin_","Body_","Hair_")):
        for polygon in obj.data.polygons:
            polygon.use_smooth=True

# Face expression geometry, cloth meshes and 4 hairstyle families survive
# exactly as named, allowing Godot's existing customization script to work.
assert all(count>=8 for count in haircounts.values()),haircounts
print("BLENDER_SCULPT_PASS_01: actual mesh vertex editing complete, "
      "hair mesh families",haircounts)

if bpy.context.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(GLB),
    export_format="GLB",
    export_apply=False,
    export_animations=True,
    export_skins=True,
    export_materials="EXPORT",
)
assert BLEND.stat().st_size > 100_000
assert GLB.stat().st_size > 100_000
print(f"BLENDER_PIPELINE_OK: {len(meshes)} editable meshes, "
      f"{len(skeleton.data.bones)} bones, "
      f"{len(bpy.data.actions)} actions, "
      f"editable={BLEND.stat().st_size}, glb={GLB.stat().st_size}")
