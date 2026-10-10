"""Headless Blender pipeline proof for Aetherfall's original rigged anime avatar.

Usage (from repo root):
  python3 tools/generate_avatar_v033.py
  blender -b -t 2 --python tools/blender_character_pipeline.py

This first pass intentionally preserves all existing meshes, skins, animations,
materials, and appearance mesh names. Future work can sculpt the character in
Blender instead of adding more procedural Godot shape code.
"""
import bpy
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

# Organize editable assets without altering bone hierarchy or deform weights.
for obj in meshes:
    if obj.name.startswith("Hair_"):
        obj.color = (0.42, 0.51, 0.87, 1.0)
    elif obj.name.startswith("Outfit_"):
        obj.color = (0.25, 0.55, 0.75, 1.0)

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
