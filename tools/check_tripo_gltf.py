#!/usr/bin/env python3
"""Validate a user-provided Tripo GLB before publishing an Android test APK.
Only stdlib, parses accessors safely and rejects hip-only/broken skinning.
"""
import json
import struct
import sys
from collections import defaultdict
from pathlib import Path

file = Path(sys.argv[1])
raw = file.read_bytes()
assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 4)[0] == 2, "Not a GLB2"
assert struct.unpack_from("<I", raw, 8)[0] == len(raw), "Invalid declared GLB length"
jlen, jtype = struct.unpack_from("<I4s", raw, 12)
assert jtype == b"JSON", "Missing JSON chunk"
j = json.loads(raw[20:20+jlen])
binstart = 20 + jlen
blen, btype = struct.unpack_from("<I4s", raw, binstart)
assert btype == b"BIN\x00", "No binary model payload"
data = memoryview(raw)[binstart+8:binstart+8+blen]
assert len(data) == blen
assert len(j.get("skins", [])) == 1, "Expected one Mixamo skinned character"
assert len(j.get("meshes", [])) >= 1
skin = j["skins"][0]
bones = [j["nodes"][n].get("name", "") for n in skin["joints"]]
assert len(bones) >= 55, "Skeleton joint count too low"
for name in ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot",
             "RightUpLeg", "RightLeg", "RightFoot",
             "LeftArm", "RightArm", "Head"]:
    assert any(b.endswith(name) for b in bones), "Missing essential joint: " + name
prim = j["meshes"][0]["primitives"][0]
attributes = prim["attributes"]
for attr in ["POSITION", "JOINTS_0", "WEIGHTS_0"]:
    assert attr in attributes, "Missing skinned vertex attribute " + attr
accessors = j["accessors"]
views = j["bufferViews"]
formats = {5120:("b",1),5121:("B",1),5122:("h",2),
           5123:("H",2),5125:("I",4),5126:("f",4)}
sizes = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4}

def accessor(index):
    acc = accessors[index]
    view = views[acc["bufferView"]]
    n = sizes[acc["type"]]
    fmt, bs = formats[acc["componentType"]]
    step = view.get("byteStride", n*bs)
    begin = view.get("byteOffset",0) + acc.get("byteOffset",0)
    assert begin+(acc["count"]-1)*step+n*bs <= len(data)
    fmt4 = "<" + fmt*n
    for i in range(acc["count"]):
        yield struct.unpack_from(fmt4, data, begin+i*step)

num_verts = accessors[attributes["POSITION"]]["count"]
assert num_verts >= 2000
w_idx = attributes["WEIGHTS_0"]
j_idx = attributes["JOINTS_0"]
weight_sum = defaultdict(float)
affected = defaultdict(int)
for joint_ids, weights in zip(accessor(j_idx), accessor(w_idx)):
    assert abs(sum(weights)-1.0) < 0.02, "Skin weights are not normalized"
    for joint, weight in zip(joint_ids, weights):
        if weight > 0.0001:
            assert joint < len(bones), "Invalid bone index"
            weight_sum[bones[joint]] += weight
            affected[bones[joint]] += 1
nontrivial = {k:v for k,v in weight_sum.items() if v >= 10}
assert len(nontrivial) >= 18, "Rig weights collapsed onto too few bones"
hip_total = sum(v for k,v in weight_sum.items() if k.endswith("Hips"))
assert hip_total/num_verts < 0.30, "Hip-only skinning detected"
for suffix in ("LeftUpLeg","RightUpLeg","LeftLeg","RightLeg","LeftArm","RightArm","Head"):
    assert any(k.endswith(suffix) and v > 80 for k,v in weight_sum.items()), "Unskinned region " + suffix
animations = j.get("animations", [])
for target in ("walk","run"):
    clips = [a for a in animations if a.get("name","").lower().endswith(target)]
    assert clips, "Missing animation: " + target
    clip = clips[0]
    assert len(clip.get("channels", [])) >= 20, target + " has too few channels"
    timeline = accessors[clip["samplers"][0]["input"]]
    assert timeline.get("max",[0])[0] >= 0.4, target + " is too short"
assert j.get("materials") and j.get("textures"), "Missing textured materials"
print("AETHERFALL_TRIPO_GLB_OK",
      json.dumps({"vertices":num_verts,"rig_joints":len(bones),
                  "skinned_joint_count":len(nontrivial),
                  "hip_weight_ratio":round(hip_total/num_verts,4),
                  "animations":[a.get("name") for a in animations]}))
