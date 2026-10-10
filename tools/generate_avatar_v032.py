#!/usr/bin/env python3
"""Aetherfall 0.3.2: anatomically timed locomotion and original anime styling.

Builds on the original v0.3.1 skinned glTF, preserving its skeleton, clothing,
saving system and customizable hairstyles. All mesh and animation data is
authored here, not borrowed from any game.
"""
import base64
import json
import math
import runpy
from pathlib import Path

old = runpy.run_path("tools/generate_avatar_v031.py")
base = old["src"]
gltf = old["gltf"]
loft = old["loft"]
ellipse = old["ellipse"]
eye_disc = old["eye_disc"]
B = old["bone"]
TAU = math.tau

# Make the knees read visually as joints, even in an extreme half-stride.
# Interpolating the weights between thigh and shin avoids a hard break across
# their two original lofts. The knee guards are fabric/leather, not large spheres.
for side in (-1, 1):
    suffix = "L" if side < 0 else "R"
    upper_name = "thigh_l" if side < 0 else "thigh_r"
    shin_name = "shin_l" if side < 0 else "shin_r"
    fore_name = "lower_l" if side < 0 else "lower_r"
    arm_name = "upper_l" if side < 0 else "upper_r"
    x = .153 * side
    loft("Detail_KneeWrap" + suffix, "ClothDark", [
        ellipse(.545, .125, .128, x), ellipse(.513, .138, .137, x),
        ellipse(.465, .142, .144, x), ellipse(.417, .133, .134, x),
        ellipse(.386, .118, .120, x)],
        lambda i,p: base["smooth_mix"](upper_name, shin_name, p[1], .54, .41), 24)
    loft("Detail_KneeRidge" + suffix, "ArmorBlue", [
        ellipse(.484, .141, .146, x, -.01),
        ellipse(.470, .146, .150, x, -.011),
        ellipse(.453, .141, .148, x, -.01)],
        lambda i,p: base["smooth_mix"](upper_name, shin_name, p[1], .51, .41), 24)
    # The elbow crease stays connected as the forearm bends.
    elbow_x = .380 * side
    loft("Detail_ElbowSeam" + suffix, "ClothDark", [
        ellipse(1.220, .109, .113, elbow_x),
        ellipse(1.187, .113, .116, elbow_x),
        ellipse(1.159, .115, .113, elbow_x),
        ellipse(1.125, .109, .107, elbow_x)],
        lambda i,p: base["smooth_mix"](arm_name, fore_name, p[1], 1.23, 1.12), 20)

# 3D tapering angular hair blades supplement the original rounded locks; their
# points are intentionally above the eyes to keep facial expressions readable.
def make_blade(name, center_x, crown_y, base_z, tip_x, tip_y, tip_z, width, mat):
    centers=[
        (center_x, crown_y, base_z, width),
        (center_x*.7+tip_x*.3, crown_y*.7+tip_y*.3, base_z*.72+tip_z*.28, width*.98),
        (center_x*.4+tip_x*.6, crown_y*.4+tip_y*.6, base_z*.39+tip_z*.61, width*.72),
        (tip_x,tip_y,tip_z,.001)]
    pos=[]; uv=[]; joints=[]; faces=[]
    for i,(x,y,z,w) in enumerate(centers):
        for dx in (-.5,.5):
            pos.append((x+w*dx,y,z));uv.append((dx+.5,i/3));joints.append(B["head"])
    for i in range(3):
        a=i*2;b=a+1;c=a+2;d=a+3
        faces.extend([(a,b,c),(b,d,c)])
    base["finalize_mesh"](name,mat,pos,uv,joints,faces)

for style in ("Windswept","Long","Short","Ponytail"):
    # Uneven asymmetric layered spikes give each haircut a recognizable anime outline.
    for i in range(7):
        x=-.19+i*(.38/6)
        bend=(.030 if style=="Windswept" else -.010) + (.013 if i%2 else -.008)
        tip_y=1.980-.008*(i%3)
        make_blade("Hair_%sFringeBlade%02d"%(style,i),x,2.092,-.117,
                   x+bend,tip_y,-.194,.057,"HairMain")
        if i%2==0:
            make_blade("Hair_%sShineBlade%02d"%(style,i),x+.014,2.079,-.130,
                       x+bend+.007,1.999-.005*(i%3),-.199,.014,"HairSheen")
    for side in (-1,1):
        # Distinct pointed face-framing locks, short enough not to obscure the eyes.
        x=.210*side
        if style in ("Long","Ponytail"):
            make_blade("Hair_%sTemple%d"%(style,side),x,2.050,-.055,
                       .225*side,1.77,-.122,.074,"HairMain")
        else:
            make_blade("Hair_%sTemple%d"%(style,side),x,2.068,-.054,
                       .235*side,1.87,-.096,.069,"HairMain")

# More legible eye outlines while avoiding over-large white/black circles.
for side in (-1,1):
    label="L" if side<0 else "R"
    x=.086*side
    eye_disc("Face_UpperEyelash"+label,"EyeLine",x,1.984,-.194,.056,.007)
    eye_disc("Face_InnerCatchlight"+label,"EyesWhite",x+.013,1.936,-.217,.006,.008)

# Motion convention: the child shin aims downward along local -Y, so +X
# flexes the knee FORWARD (-Z). The old v0.3.1 gait used negative shin X and
# placed the arms toward the back with an asymmetric negative offset.
# Timing here defines a two-phase stance and swing with 32 interpolated frames.
def ease(t):
    t=max(0.,min(1.,t))
    return t*t*(3.-2.*t)

def bend(angle):
    return (math.sin(angle/2),0.0,0.0,math.cos(angle/2))

def lean(angle):
    return (0.0,0.0,math.sin(angle/2),math.cos(angle/2))

def mult(a,b):
    x,y,z,w=a;u,v,t,s=b
    return (w*u+x*s+y*t-z*v,w*v-x*t+y*s+z*u,
            w*t+x*v-y*u+z*s,w*s-x*u-y*v-z*t)

def gait(state, key, p):
    if state in ("Walk","Run"):
        running=(state=="Run")
        # Left and right exactly half a stride out of phase.
        side_phase = p+(math.pi if key.endswith("_r") else 0.0)
        swing=math.sin(side_phase)
        forward_motion=math.cos(side_phase)
        # The foot is airborne during the forward-swing half only.
        lift=ease(max(0.0,forward_motion))
        stride=.33 if not running else .52
        if key.startswith("thigh_"):
            # Positive hip X is a forward leg swing in the original bind pose.
            return bend(stride*swing)
        if key.startswith("shin_"):
            # Positive knee flexion with a strong peak during forward recovery.
            return bend((.08 if not running else .16)+(.65 if not running else .99)*lift)
        if key.startswith("foot_"):
            # Toe clears the floor in recovery, then rolls onto the planted foot.
            return bend(-.18*lift+.14*max(0.0,-forward_motion))
        if key.startswith("upper_"):
            # Arm opposition: smaller motion than the thigh and nearly
            # symmetric around neutral, preventing excessive rearward swing.
            return bend(.02-(.19 if not running else .30)*swing)
        if key.startswith("lower_"):
            return bend((.18 if not running else .40)+.07*lift)
        if key=="spine":
            return mult(lean(.014*math.sin(p)),bend(-.025 if running else .005))
        if key=="chest":
            return lean(-.017*math.sin(p))
        if key=="head":
            return bend(-.018*math.sin(2*p))
    if state=="Idle":
        if key=="spine":return bend(.012*math.sin(p))
        if key=="chest":return lean(.008*math.sin(p))
        if key=="head":return bend(-.01*math.sin(p))
        if key.startswith("upper_"):return bend(.025)
        if key.startswith("lower_"):return bend(.12)
    if state=="Jump":
        pulse=math.sin(.5*p)
        if key.startswith("thigh_"):return bend(-.30*pulse)
        if key.startswith("shin_"):return bend(.52*pulse)
        if key.startswith("foot_"):return bend(-.10*pulse)
        if key.startswith("upper_"):return bend(-.33*pulse)
        if key.startswith("lower_"):return bend(.28*pulse)
        if key=="spine":return bend(-.05*pulse)
    if state=="Wave":
        if key=="upper_r":return lean(1.12*ease(p/.8))
        if key=="lower_r":return lean(.34+.21*math.sin(p*2))
        if key=="head":return lean(.050*math.sin(p))
    return (0.,0.,0.,1.)

TRACKS=("thigh_l","thigh_r","shin_l","shin_r","foot_l","foot_r",
        "upper_l","upper_r","lower_l","lower_r","spine","chest","head")
def hip_track(clip,times,phases,state):
    duration=times[-1]
    positions=[]
    for p in phases:
        if state in ("Walk","Run"):
            lift=.014 if state=="Walk" else .027
            # Restrained vertical motion; do not translate the player capsule.
            positions.append((.008*math.sin(p),.90+lift*abs(math.sin(p)),0.0))
        elif state=="Idle":
            positions.append((0,.90+.004*math.sin(p),0))
        else:
            positions.append((0,.90,0))
    ta=base["acc"](times,5126,"SCALAR",track_minmax=True)
    va=base["acc"](positions,5126,"VEC3")
    si=len(clip["samplers"])
    clip["samplers"].append({"input":ta,"output":va,"interpolation":"LINEAR"})
    clip["channels"].append({"sampler":si,"target":{
        "node":base["joint_nodes"][B["hips"]],"path":"translation"}})

gltf["animations"].clear()
for state,duration in (("Idle",2.4),("Walk",.90),("Run",.64),("Jump",.95),("Wave",2.0)):
    times=[duration*i/32 for i in range(33)]
    phases=[TAU*i/32 for i in range(33)]
    clip={"name":state,"samplers":[],"channels":[]}
    for key in TRACKS:
        rotations=[gait(state,key,p) for p in phases]
        base["track"](clip,base["joint_nodes"][B[key]],rotations,times)
    hip_track(clip,times,phases,state)
    gltf["animations"].append(clip)

gltf["buffers"][0]["byteLength"]=len(base["buffer"])
gltf["buffers"][0]["uri"]="data:application/octet-stream;base64,"+base64.b64encode(base["buffer"]).decode("ascii")
gltf["asset"]["generator"]="Aetherfall original v0.3.2 gait correction and anime silhouette"
out=Path("assets/characters/aetherfall_adventurer.gltf")
out.write_text(json.dumps(gltf,separators=(",",":")),encoding="utf-8")
print("AETHERFALL_V032: %d skinned meshes, 5 improved motion clips, %d bytes" %
      (len(gltf["meshes"]),len(base["buffer"])))
assert len(gltf["meshes"])>130
