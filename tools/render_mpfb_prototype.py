"""Produce visual QA portraits from the actual MPFB/Rigify Blender model.

Run: blender -b builds/Aetherfall-MPFB-Rigify-Anime-Prototype.blend
             --python tools/render_mpfb_prototype.py
This is a raster preview only, not the character source used in Godot.
"""
import bpy
from pathlib import Path
from mathutils import Vector

OUT=Path("builds/character-preview")
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=10
scene.render.resolution_x=360
scene.render.resolution_y=600
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.film_transparent=False
scene.view_settings.view_transform="AgX"
world=bpy.data.worlds.new("Aetherfall Studio Backdrop")
scene.world=world
world.use_nodes=True
bg=world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value=(.06,.085,.15,1)
bg.inputs["Strength"].default_value=.7

def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()

camera=bpy.data.objects.new("Aetherfall_Review_Camera",bpy.data.cameras.new("Character Portrait Lens"))
bpy.context.collection.objects.link(camera)
camera.location=(1.2,-3.5,1.4)
aim(camera,(0,0,.99))
camera.data.type="ORTHO"
camera.data.ortho_scale=1.99
scene.camera=camera

for loc,energy,size in [((-2.0,-3.0,3.8),450,4.0),((2.5,1.4,3.4),650,3.0)]:
    data=bpy.data.lights.new("Studio Softbox","AREA")
    data.energy=energy;data.shape="DISK";data.size=size
    light=bpy.data.objects.new("Studio Softbox",data)
    bpy.context.collection.objects.link(light)
    light.location=loc
    aim(light,(0,0,1.0))

for obj in bpy.data.objects:
    if obj.type=="MESH":
        obj.hide_render=not (
            obj.name=="Aetherfall_Anime_Human" or
            obj.name.startswith("Hair_") or
            obj.name.startswith("Outfit_Adventurer_"))
for style in ("Windswept","Long","Short","Ponytail"):
    for obj in bpy.data.objects:
        if obj.type=="MESH" and obj.name.startswith("Hair_"):
            obj.hide_render=not obj.name.startswith("Hair_"+style+"_")
    scene.render.filepath=str(OUT/("Aetherfall-%s-Preview.png"%style))
    bpy.ops.render.render(write_still=True)
    path=Path(scene.render.filepath)
    assert path.is_file() and path.stat().st_size>9000
    print("AETHERFALL_STYLE_PREVIEW_OK",style,path.stat().st_size)
