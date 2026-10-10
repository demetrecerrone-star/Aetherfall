#!/usr/bin/env python3
"""Aetherfall v0.3.3 proof of correct knee direction and original stylized meshes.

The test works on actual exported glTF animation quaternion tracks and skinned
vertex buffers. It is intentionally not a test of the sign alone.
"""
import base64
import json
import math
import struct
from pathlib import Path

scene=json.loads(Path("assets/characters/aetherfall_adventurer.gltf").read_text())
payload=base64.b64decode(scene["buffers"][0]["uri"].split(",",1)[1])
nodes={n["name"]:i for i,n in enumerate(scene["nodes"])}
meshes={m["name"]:m for m in scene["meshes"]}
component_fmt={5126:"f",5123:"H",5125:"I"}
component_size={5126:4,5123:2,5125:4}
type_count={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
def values(accessor_index):
    a=scene["accessors"][accessor_index]
    view=scene["bufferViews"][a["bufferView"]]
    fmt=component_fmt[a["componentType"]]
    n=type_count[a["type"]]
    size=n*component_size[a["componentType"]]
    at=view.get("byteOffset",0)+a.get("byteOffset",0)
    stride=view.get("byteStride",size)
    return [struct.unpack_from("<"+fmt*n,payload,at+i*stride) for i in range(a["count"])]

def track(state,bone,path="rotation"):
    anim=next(x for x in scene["animations"] if x["name"]==state)
    for channel in anim["channels"]:
        tgt=channel["target"]
        if tgt["node"]==nodes[bone] and tgt["path"]==path:
            sampler=anim["samplers"][channel["sampler"]]
            return values(sampler["output"])
    raise AssertionError("Missing animation track %s %s %s"%(state,bone,path))

# The face and eyes of this ORIGINAL model point toward NEGATIVE Z.
# Its ankle vector relative to knee is (0,-.34,-.08); forward knee flexion
# should send the ANKLE TOWARDS POSITIVE Z (behind the torso), not -Z.
def rotated_ankle_z(angle):
    y,z = -.34, -.08
    return y*math.sin(angle)+z*math.cos(angle)
for clip_name in ("Walk","Run","Jump"):
    for side in ("Left","Right"):
        quats=track(clip_name,side+"Shin")
        angles=[2*math.atan2(q[0],q[3]) for q in quats]
        assert len(angles)==33,("time sampling",clip_name)
        flex=min(angles)
        assert flex < (-.68 if clip_name=="Walk" else -.9 if clip_name=="Run" else -.40),(
            "knee flex insufficient",clip_name,side,flex)
        assert max(angles)<=.01,("backwards joint rotation",clip_name,side,max(angles))
        assert rotated_ankle_z(flex)>.06,("ankle is still in FRONT of the knee",clip_name,side)
        print("KNEE_DIRECTION_OK",clip_name,side,
              "angle %.1f deg"%math.degrees(flex),
              "ankle behind knee %.3f m"%rotated_ankle_z(flex))
for state in ("Walk","Run"):
    arms=track(state,"LeftUpperArm")
    assert max(abs(2*math.atan2(q[0],q[3])) for q in arms)<.36

for piece in (
    "Outfit_AdventurerFrontTailL","Outfit_AdventurerBackTailR",
    "Outfit_SpellweaverRobeL","Outfit_VanguardFauldR",
    "Outfit_AdventurerCrossStrap","Detail_CollarChevronL",
    "Hair_LongRearVolume00","Hair_WindsweptCrownLift00",
):
    assert piece in meshes,("Missing redesign mesh",piece)
assert len(meshes)>180,("Not enough new modeled geometry",len(meshes))
# Prove the boot profile is slimmer than the prior mannequin-like model.
boot_mesh=meshes["Body_LeftBoot"]
boot_pos=values(boot_mesh["primitives"][0]["attributes"]["POSITION"])
assert (max(p[0] for p in boot_pos)-min(p[0] for p in boot_pos))<.21
assert len(scene["skins"])==1 and len(scene["animations"])==5
print("ANIME_REDRAW_V033_OK: geometry, custom outfits, slender boots, forward-flexing knees")
