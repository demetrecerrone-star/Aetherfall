#!/usr/bin/env python3
"""Validate real joint-angle motion in Aetherfall's generated glTF 0.3.2."""
import base64
import json
import math
from pathlib import Path
import struct

path=Path("assets/characters/aetherfall_adventurer.gltf")
scene=json.loads(path.read_text(encoding="utf-8"))
buffer=base64.b64decode(scene["buffers"][0]["uri"].split(",",1)[1])
accessors=scene["accessors"]
views=scene["bufferViews"]
nodes=scene["nodes"]
by_name={n["name"]:i for i,n in enumerate(nodes)}

def read_acc(i):
    a=accessors[i];v=views[a["bufferView"]]
    fmt={5126:"f",5123:"H",5125:"I"}[a["componentType"]]
    count={"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]]
    size=struct.calcsize("<"+fmt*count)
    offset=v.get("byteOffset",0)+a.get("byteOffset",0)
    stride=v.get("byteStride",size)
    return [struct.unpack_from("<"+fmt*count,buffer,offset+j*stride)
            for j in range(a["count"])]

def quat_angles(state,name):
    clip=next(c for c in scene["animations"] if c["name"]==state)
    node=by_name[name]
    for channel in clip["channels"]:
        if channel["target"]["node"]==node and channel["target"]["path"]=="rotation":
            samples=read_acc(clip["samplers"][channel["sampler"]]["output"])
            return [2*math.atan2(q[0],q[3]) for q in samples]
    raise AssertionError("No rotation for %s in %s"%(name,state))

assert len(scene["skins"])==1
assert len(scene["animations"])>=5
for state in ("Walk","Run"):
    left_knee=quat_angles(state,"LeftShin")
    right_knee=quat_angles(state,"RightShin")
    left_arm=quat_angles(state,"LeftUpperArm")
    right_arm=quat_angles(state,"RightUpperArm")
    left_hip=quat_angles(state,"LeftThigh")
    assert len(left_knee)==33, "Interpolated gait samples missing"
    assert min(left_knee)>-.02, "Knee flexes backward instead of forward"
    assert max(left_knee)>.57 if state=="Walk" else max(left_knee)>.95, "Knee lift too small"
    assert max(left_knee)-min(left_knee)>.55
    assert abs(left_knee[0]-left_knee[-1])<.001
    assert max(abs(x) for x in left_arm)<(.23 if state=="Walk" else .34), "Arm swings too far behind torso"
    assert max(abs(x) for x in right_arm)<(.23 if state=="Walk" else .34)
    assert max(abs(a+b) for a,b in zip(left_hip,quat_angles(state,"RightThigh")))<.001
    # Right and left knee maximums must occur around half a stride apart.
    assert abs(left_knee.index(max(left_knee))-right_knee.index(max(right_knee)))>=12
    print("GAIT_OK %s: knee flex %.0f-%.0f degrees; arms within %.0f degrees"%(
        state,math.degrees(min(left_knee)),math.degrees(max(left_knee)),
        math.degrees(max(abs(x) for x in left_arm))))

meshes={m["name"]:m for m in scene["meshes"]}
assert all(any(k.startswith("Detail_KneeWrap") for k in meshes) for _ in (1,))
assert all(any(k.startswith("Hair_"+style+"FringeBlade") for k in meshes)
           for style in ("Windswept","Long","Short","Ponytail"))
assert all("Face_UpperEyelash"+side in meshes for side in ("L","R"))
assert len(meshes)>130
print("GATE_V032_OK: positive flexing knees, restrained mirrored arm swing, joint wraps, anime hair/face geometry")
