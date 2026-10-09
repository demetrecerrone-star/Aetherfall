#!/usr/bin/env python3
"""Aetherfall v0.3.1: author added garment geometry and smoother skeletal motion.

Runs the existing original glTF model generator in-memory and appends skinned
details and replacement animation curves to the same glTF asset. No third-party
models, dependencies or licensing ambiguity.
"""
import base64
import json
import math
import runpy
from pathlib import Path

src = runpy.run_path("tools/generate_avatar.py")
gltf = src["gltf"]
loft = src["loft"]
ellipse = src["ellipse"]
ribbon = src["ribbon"]
strand = src["strand"]
eye_disc = src["eye_disc"]
bone = src["BONE"]
TAU = math.tau

# The base model already has soft skin weights; add designed contours.
loft("Detail_StandCollar", "ClothDark", [
    ellipse(1.57, .145, .14), ellipse(1.63, .117, .116),
    ellipse(1.67, .102, .101)], lambda i,p: bone["neck"], 24)
loft("Detail_WaistBinding", "Leather", [
    ellipse(.86, .268, .203), ellipse(.905, .280, .209),
    ellipse(.927, .258, .193)], lambda i,p: bone["hips"], 24)
for side in (-1, 1):
    label = "L" if side < 0 else "R"
    arm = bone["upper_l" if side < 0 else "upper_r"]
    lower = bone["lower_l" if side < 0 else "lower_r"]
    shin = bone["shin_l" if side < 0 else "shin_r"]
    x = .34 * side
    loft("Detail_ShoulderGuard"+label, "ArmorBlue", [
        ellipse(1.50, .140, .140, x),
        ellipse(1.535, .155, .148, x),
        ellipse(1.564, .130, .131, x),
        ellipse(1.586, .048, .080, x)], lambda i,p: arm, 20)
    loft("Detail_Bracelet"+label, "Leather", [
        ellipse(.94, .089, .092, .40*side),
        ellipse(.97, .097, .099, .40*side)], lambda i,p: lower, 18)
    loft("Detail_BootTop"+label, "Leather", [
        ellipse(.191, .124, .131, .153*side),
        ellipse(.217, .128, .133, .153*side),
        ellipse(.244, .112, .118, .153*side)], lambda i,p: shin, 18)
    ribbon("Detail_JacketPiping"+label, "TrimLight", [
        (.125*side, 1.52, -.181), (.13*side, 1.43, -.207),
        (.105*side, 1.33, -.210), (.085*side, 1.20, -.191),
        (.09*side, 1.10, -.18)], .018, bone["chest"])
    bx=.087*side
    eye_disc("Face_Brow"+label, "Brow", bx, 2.014, -.159, .067, .009)
    eye_disc("Face_LowerLid"+label, "SkinShadow", bx, 1.910, -.187, .052, .005)
    eye_disc("Face_Catchlight"+label, "EyesWhite", bx-.011, 1.953, -.212, .010, .012)
ribbon("Detail_BeltBuckle", "MetalGold", [
    (-.044, .922, -.221), (.044, .922, -.221)], .047, bone["hips"])
ribbon("Detail_JacketCenter", "ClothDark", [
    (0, 1.55, -.178), (0, 1.43, -.211),
    (0, 1.30, -.211)], .045, bone["chest"])
for style in ("Windswept", "Long", "Short", "Ponytail"):
    count = 7 if style != "Short" else 5
    for index in range(count):
        x = -.176 + index * .352 / (count-1)
        skew = .053 if style == "Windswept" else .011
        strand("Hair_%sSweep%02d" % (style,index), "HairSheen", [
            (x, 2.119, -.048), (x+skew, 2.084, -.125),
            (x+skew+.012, 2.025, -.174),
            (x+skew+.015, 1.988-(index%3)*.009, -.175)], radius=.022)

# Replace sharp five-key mannequin gait with sampled easing and arm-leg opposition.
def mul(q, r):
    x,y,z,w=q
    a,b,c,d=r
    return (w*a+x*d+y*c-z*b, w*b-x*c+y*d+z*a,
            w*c+x*b-y*a+z*d, w*d-x*a-y*b-z*c)

def qx(a):
    return (math.sin(a/2), 0., 0., math.cos(a/2))

def qz(a):
    return (0., 0., math.sin(a/2), math.cos(a/2))

def animated_rotation(key, state, phase, amount):
    wave = math.sin(phase)
    opposite = math.sin(phase+math.pi)
    if state in ("Walk", "Run"):
        scale = .74 if state == "Walk" else 1.
        if key == "thigh_l": return qx(amount*wave)
        if key == "thigh_r": return qx(amount*opposite)
        if key == "shin_l": return qx(-.10-max(0.,-wave)*(.50*scale))
        if key == "shin_r": return qx(-.10-max(0.,-opposite)*(.50*scale))
        if key == "foot_l": return qx(.08+.12*wave)
        if key == "foot_r": return qx(.08+.12*opposite)
        if key == "upper_l": return qx(-.12-.66*amount*wave)
        if key == "upper_r": return qx(-.12-.66*amount*opposite)
        if key in ("lower_l", "lower_r"): return qx(-.22-.05*abs(wave))
        if key == "spine": return mul(qz(.025*wave),qx(-.065 if state=="Run" else -.012))
        if key == "chest": return qz(-.026*wave)
        if key == "head": return qx(.025*math.cos(phase))
    elif state == "Idle":
        if key == "spine": return qx(.018*math.sin(phase))
        if key == "chest": return qz(.009*math.sin(phase))
        if key == "head": return qx(-.012*math.sin(phase))
        if key in ("upper_l","upper_r"): return qx(-.07+.01*math.sin(phase))
        if key in ("lower_l","lower_r"): return qx(-.06)
    elif state == "Jump":
        pulse=math.sin(min(1.,phase/TAU)*math.pi)
        if key in ("thigh_l","thigh_r"): return qx(-.32*pulse)
        if key in ("shin_l","shin_r"): return qx(-.43*pulse)
        if key in ("upper_l","upper_r"): return qx(-.47*pulse)
        if key in ("lower_l","lower_r"): return qx(-.26*pulse)
        if key == "spine": return qx(.08*pulse)
    else:
        if key == "upper_r":
            return qz(1.32*min(1.,phase/.80))
        if key == "lower_r":
            return qz(.34+.24*math.sin(phase*2.0))
        if key == "head":
            return qz(.075*math.sin(phase))
    return (0.,0.,0.,1.)

def add_hip_translation(clip, times, phase_list, state):
    track_times = src["acc"](times,5126,"SCALAR",track_minmax=True)
    values=[]
    for phase in phase_list:
        if state in ("Walk","Run"):
            bob=(.016 if state=="Walk" else .031)*abs(math.sin(phase))
            sway=.014*math.cos(phase)
            values.append((sway,.90+bob,0.))
        elif state=="Idle":
            values.append((0.,.90+.006*math.sin(phase),0.))
        elif state=="Jump":
            values.append((0.,.90+.040*math.sin(phase/2),0.))
        else:
            values.append((0.,.90,0.))
    track_values=src["acc"](values,5126,"VEC3")
    index=len(clip["samplers"])
    clip["samplers"].append({"input":track_times,"output":track_values,"interpolation":"LINEAR"})
    clip["channels"].append({"sampler":index,"target":{
        "node":src["joint_nodes"][bone["hips"]],"path":"translation"}})

gltf["animations"].clear()
keys=("thigh_l","thigh_r","shin_l","shin_r","foot_l","foot_r",
      "upper_l","upper_r","lower_l","lower_r","spine","chest","head")
for state,duration,amount in (
    ("Idle",2.4,.012),("Walk",.90,.39),("Run",.64,.62),
    ("Jump",.95,.32),("Wave",2.0,.24)):
    times=[duration*i/12 for i in range(13)]
    phases=[TAU*i/12 for i in range(13)]
    clip={"name":state,"samplers":[],"channels":[]}
    for key in keys:
        rotations=[animated_rotation(key,state,p,amount) for p in phases]
        src["track"](clip,src["joint_nodes"][bone[key]],rotations,times)
    add_hip_translation(clip,times,phases,state)
    gltf["animations"].append(clip)

gltf["buffers"][0]["byteLength"]=len(src["buffer"])
gltf["buffers"][0]["uri"]="data:application/octet-stream;base64,"+base64.b64encode(src["buffer"]).decode("ascii")
gltf["asset"]["generator"]="Aetherfall original v0.3.1 sculpted lofts / authored motion"
out=Path("assets/characters/aetherfall_adventurer.gltf")
out.write_text(json.dumps(gltf,separators=(",",":")),encoding="utf-8")
print("AETHERFALL_V031: %d skinned meshes, %d refined animations, %d vertex bytes" % (
    len(gltf["meshes"]),len(gltf["animations"]),len(src["buffer"])))
assert len(gltf["meshes"])>=105
