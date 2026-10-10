#!/usr/bin/env python3
"""Aetherfall original anime-proportioned humanoid built using MPFB and Rigify.

This is a *new* experimental character, not a modification of the playable
v0.3.3 avatar. Do not replace the Godot prefab until bone retargeting, clothing
and animation tests pass. Outputs a Blender project and Godot-importable GLB.
Run using Blender 4.5+ with MPFB and Rigify enabled.
"""
import bpy
import addon_utils
import importlib
import json
from pathlib import Path

OUT=Path("builds")
OUT.mkdir(exist_ok=True)
BLEND=OUT/"Aetherfall-MPFB-Rigify-Anime-Prototype.blend"
GLB=OUT/"Aetherfall-MPFB-Rigify-Anime-Prototype.glb"
INFO=OUT/"Aetherfall-MPFB-Rigify-Anime-Prototype.json"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for name in ("bl_ext.blender_org.mpfb","rigify"):
    addon_utils.enable(name,default_set=True)
    assert name in bpy.context.preferences.addons, f"Required character creation add-on missing: {name}"

module="bl_ext.blender_org.mpfb.services."
HumanService=importlib.import_module(module+"humanservice").HumanService
RigService=importlib.import_module(module+"rigservice").RigService
SystemService=importlib.import_module(module+"systemservice").SystemService
assert SystemService.check_for_rigify(), "MPFB does not recognize active Rigify"

# MPFB provides its actual anatomical base (body, hands and face topology).
human=HumanService.create_human(mask_helpers=True,detailed_helpers=True,
    extra_vertex_groups=True,feet_on_ground=True,scale=0.1)
assert human is not None and human.type=="MESH","MPFB did not create a basemesh"
human.name="Aetherfall_Anime_Human"
assert len(human.data.vertices)>10000, "Character isn't a real MPFB base mesh"

# Anime proportions: preserve bilateral symmetry and a realistic jaw,
# shorten the lower face subtly, emphasize cranial volume, soften torso.
# This is vertex-level sculpting on MPFB topology *before* fitting the rig.
verts=human.data.vertices
zmin=min(v.co.z for v in verts)
zmax=max(v.co.z for v in verts)
height=zmax-zmin
assert height>.1, "Invalid MPFB body height"
for v in verts:
    p=v.co
    h=(p.z-zmin)/height
    if .83<h<=1:
        # Upper head and brow fuller; chin tapers slightly inward.
        amount=max(0.0,min(1.0,(h-.83)/.14))
        p.x *= (.925+.11*amount)
        # A subtle face depth adjustment: less protruding at brow.
        if p.y<0:
            p.y *= (.98+.02*amount)
    elif .49<h<.68:
        # Defined anime-adventurer waist instead of straight torso.
        strength=max(0.0,1-abs(h-.555)/.08)
        p.x*=1-.035*strength
human.data.update()

# Create a visible, neutral, non-transparent skin material for the model
# preview; hairstyles and fantasy costume will be authored next.
skin=bpy.data.materials.new("Aetherfall_Warm_Skin")
skin.diffuse_color=(.72,.49,.38,1)
skin.use_nodes=True
bsdf=skin.node_tree.nodes.get("Principled BSDF")
if bsdf is not None:
    bsdf.inputs["Base Color"].default_value=skin.diffuse_color
    bsdf.inputs["Roughness"].default_value=.83
human.data.materials.clear()
human.data.materials.append(skin)

# Fit MPFB's human metarig to the sculpted body, then let Rigify build IK/FK,
# deformation bones, and animation controls; leave the actual body weighted.
metarig=HumanService.add_builtin_rig(human,"rigify.human")
assert metarig is not None and metarig.type=="ARMATURE", "MPFB metarig fitting failed"
rig=RigService.generate_rigify_rig(metarig,meta_rig_action="delete")
assert rig is not None and rig.type=="ARMATURE", "Rigify generation failed"
rig.name="Aetherfall_Anime_Rigify"
assert len(rig.data.bones)>40, "Generated Rigify skeleton incomplete"

# The rig includes numerous non-deformation animation controls. Rigify bones
# are intentionally not mapped to Aetherfall's existing 17-bone game skeleton.
deform=[b.name for b in rig.data.bones if b.use_deform]
assert len(deform)>15, "Rigify has no usable deform skeleton"
assert any(m.type=="ARMATURE" for m in human.modifiers), "MPFB lost its armature modifier"

# Export only body and generated rig; hide Rigify widgets and rig internals.
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
human.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(filepath=str(GLB),export_format="GLB",
    use_selection=True,export_animations=True,export_skins=True,
    export_materials="EXPORT")
assert BLEND.is_file() and BLEND.stat().st_size>100000
assert GLB.is_file() and GLB.stat().st_size>100000
stats={"generator":"MPFB", "rigging":"Rigify", "blender":bpy.app.version_string,
    "vertices":len(human.data.vertices),"bones":len(rig.data.bones),
    "deform_bones":len(deform),"height_model_units":round(height,3),
    "export_glb_bytes":GLB.stat().st_size,
    "release_integration":False}
INFO.write_text(json.dumps(stats,indent=2))
print("AETHERFALL_MPFBRIGIFY_PROTOTYPE_OK "+json.dumps(stats))
