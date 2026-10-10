#!/usr/bin/env python3
"""Aetherfall v0.3.3: fix backwards knees; reshape the original anime avatar.

Keeps the customizable 17-joint skinned glTF character, animations, and outfit
options. Retails no borrowed meshes, characters, or textures. This is the
second ORIGINAL hand-authored modeling pass, not a third-party asset.
"""
import base64
import json
import math
import runpy
import struct
from pathlib import Path

previous = runpy.run_path("tools/generate_avatar_v032.py")
source = previous["base"]
gltf = previous["gltf"]
loft = previous["loft"]
ellipse = previous["ellipse"]
ribbon = source["ribbon"]
eye_disc = previous["eye_disc"]
B = previous["B"]
TAU = math.tau
buffer = source["buffer"]
meshes = gltf["meshes"]
views = gltf["bufferViews"]
accessors = gltf["accessors"]

def reshape_mesh(mesh_name, modify):
    """Make the formerly cylindrical limb surfaces into slimmer tailored forms.

    Geometry is edited in the original glTF POSITION buffer, preserving skin
    weights, material IDs and imported animation compatibility.
    """
    for mesh in meshes:
        if mesh["name"] != mesh_name:
            continue
        prim = mesh["primitives"][0]
        acc = accessors[prim["attributes"]["POSITION"]]
        view = views[acc["bufferView"]]
        offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        for i in range(acc["count"]):
            p = struct.unpack_from("<fff", buffer, offset + stride * i)
            struct.pack_into("<fff", buffer, offset + stride * i, *modify(p))
        return True
    raise AssertionError("Missing expected model section: " + mesh_name)

# Reduce the exaggerated square-shoulder and oversized-toy-boot silhouette.
reshape_mesh("Body_Torso", lambda p: (
    p[0] * (.895 if p[1] >= 1.28 else .96), p[1], p[2] * .96))
reshape_mesh("Body_HipCloth", lambda p: (p[0] * .965, p[1], p[2] * .96))
for side, label in ((-1, "Left"), (1, "Right")):
    arm_centre = .36 * side
    wrist_centre = .392 * side
    boot_centre = .153 * side
    for part, origin, width in (
        ("Sleeve", arm_centre, .82),
        ("Forearm", wrist_centre, .83),
        ("Hand", .405 * side, .91),
        ("Trouser", .159 * side, .91),
        ("Shin", boot_centre, .88),
        ("Boot", boot_centre, .81),
    ):
        name = ("Skin_" if part == "Hand" else "Body_") + label + part
        reshape_mesh(name, lambda p, orig=origin, f=width, typ=part: (
            orig + (p[0] - orig) * f, p[1],
            p[2] * (.84 if typ == "Boot" else .95)))
    for prefix, origin, width in (
        ("Detail_ShoulderGuard", .34 * side, .76),
        ("Detail_Shoulder", .34 * side, .79),
        ("Detail_BootTop", boot_centre, .83),
        ("Detail_BootCuff", boot_centre, .83),
        ("Detail_KneeWrap", boot_centre, .87),
        ("Detail_KneeRidge", boot_centre, .86),
    ):
        reshape_mesh(prefix + ("L" if side < 0 else "R"),
                     lambda p, orig=origin, f=width: (
                         orig + (p[0] - orig) * f, p[1], p[2] * .91))

# Emphasize cheek-to-chin taper, while preserving original anime eye positions.
reshape_mesh("Skin_Head", lambda p: (
    p[0] * (.87 if p[1] < 1.84 else (.96 if p[1] < 1.90 else 1.0)),
    p[1], p[2]))

# Cloth strips are gracefully curved in 3D; they ride the hips, not the knees.
def draped_panel(name, mat, rows, width, bone_name="hips"):
    verts=[]; uv=[]; bones=[]; faces=[]
    for i,(cx,cy,cz,w,fold) in enumerate(rows):
        for k in range(5):
            t=k/4.0
            dx=(t-.5)*w
            # Central pleat near the body, softly rolled edges outside.
            dz=fold * (2*t-1)**2
            verts.append((cx+dx,cy,cz+dz))
            uv.append((t,i/max(1,len(rows)-1)))
            bones.append(B[bone_name])
    for i in range(len(rows)-1):
        for k in range(4):
            a=i*5+k; b=a+1; c=(i+1)*5+k; d=c+1
            faces.extend([(a,c,b),(b,c,d)])
    source["finalize_mesh"](name,mat,verts,uv,bones,faces)

# Tailored coat and chest detailing; each outfit variant is a different
# geometry selection, not just a paint-color swap.
for side in (-1,1):
    lab="L" if side < 0 else "R"
    draped_panel("Outfit_AdventurerFrontTail"+lab,"ClothDark",[
        (.135*side,.88,-.190,.174,.014),
        (.145*side,.81,-.192,.180,.018),
        (.15*side,.69,-.185,.182,.032),
        (.15*side,.595,-.180,.130,.045),
    ],.174)
    draped_panel("Outfit_AdventurerBackTail"+lab,"ClothMain",[
        (.132*side,.89,.190,.190,-.008),
        (.143*side,.78,.216,.190,-.02),
        (.153*side,.65,.239,.214,-.038),
        (.159*side,.58,.251,.165,-.048),
    ],.190)
    draped_panel("Outfit_SpellweaverRobe"+lab,"ClothDark",[
        (.17*side,1.04,-.190,.23,.01),
        (.17*side,.94,-.200,.24,.012),
        (.18*side,.75,-.225,.25,.032),
        (.18*side,.55,-.230,.19,.060),
    ],.240)
    draped_panel("Outfit_VanguardFauld"+lab,"Leather",[
        (.165*side,.91,.190,.186,.02),
        (.174*side,.84,.211,.196,.025),
        (.18*side,.72,.239,.181,.04),
    ],.192)

# Fine diagonal harness and lapels make the jacket read as a garment.
ribbon("Outfit_AdventurerCrossStrap","Leather",[
    (-.235,1.51,-.167),(-.176,1.44,-.201),
    (-.083,1.30,-.216),(.046,1.12,-.182),
    (.154,.98,-.176)],.043,lambda p: B["chest"] if p[1] > 1.18 else B["spine"])
ribbon("Outfit_AdventurerStrapHighlight","MetalGold",[
    (-.213,1.48,-.200),(-.15,1.40,-.213),
    (-.056,1.25,-.219),(.065,1.11,-.188)],.010,B["chest"])
for side in (-1,1):
    lab="L" if side<0 else "R"
    ribbon("Detail_CollarChevron"+lab,"TrimLight",[
        (.063*side,1.625,-.107),(.117*side,1.558,-.164),
        (.130*side,1.472,-.208),(.073*side,1.370,-.208)
    ],.018,B["chest"])
    ribbon("Detail_BootLeatherBinding"+lab,"Leather",[
        ((.153-.065)*side,.215,-.123),
        (.153*side,.205,-.132),
        ((.153+.065)*side,.217,-.123)
    ],.024,B["shin_l" if side<0 else "shin_r"])

# Sculpted multi-ring flyaway hair tufts, thicker than flat floating triangles.
def hair_tuft(name, points, size, main_material):
    sections=[]
    for i,p in enumerate(points):
        t=i/max(1,len(points)-1)
        w=size*max(.04,1.0-t**1.35)
        sections.append((p,w,w*.70))
    loft(name,main_material,sections,lambda i,p:B["head"],12)

for style in ("Windswept","Long","Short","Ponytail"):
    # The crown and temple silhouette no longer resembles a clipped helmet.
    for i in range(7):
        t=(i-3)/3.0
        x=t*.174
        y=2.085+.020*(1-abs(t))
        z=.102+(1-abs(t))*.055
        spread = (.086 if style=="Windswept" else .046) * (1 if i%2 else -1)
        hair_tuft("Hair_%sCrownLift%02d"%(style,i),[
            (x,2.085,z),(x+spread*.25,2.122,z+.022),
            (x+spread*.85,2.145,z+.046),
            (x+spread*1.75,2.124,z+.057)
        ],.065 if style=="Windswept" else .046,
            "HairMain")
    for side in (-1,1):
        side_long = style in ("Long","Ponytail")
        hair_tuft("Hair_%sSideLayer%s"%(style,"L" if side<0 else "R"),[
            (.193*side,2.05,.03),
            (.240*side,1.994,-.018),
            (.266*side,1.917,-.051),
            (.251*side,1.78 if side_long else 1.86,-.071),
        ],.073 if side_long else .058,"HairMain")
    if style=="Long":
        # Long hairstyle remains genuinely long and follows the neck/back.
        for i in range(4):
            x=(i-1.5)*.092
            hair_tuft("Hair_LongRearVolume%02d"%i,[
                (x,2.08,.146),(x,1.93,.227),
                (x*1.12,1.70,.251),
                (x*1.20,1.43,.217)],.084,"HairMain")
    if style=="Ponytail":
        hair_tuft("Hair_PonytailBackVolume","HairMain" if False else [
            (0,2.09,.17)],.04,"HairMain") if False else None
        for i in range(5):
            x=(i-2)*.032
            hair_tuft("Hair_PonytailCascade%02d"%i,[
                (x,2.09,.159),
                (x,2.025,.265),
                (x+(i-2)*.018,1.805,.30),
                (x+(i-2)*.023,1.48,.225),
            ],.055,"HairMain")

# Leg local -Y segment. X POSITIVE knee rotation swings the ankle toward -Z
# (in front of the character's eyes). That's precisely the visually BACKWARDS
# knee the player reported. Correct human knee bend sends the ankle behind the
# front-facing (-Z) torso: knee local X must be NEGATIVE.
gltf["animations"].clear()
prev_gait = previous["gait"]
easing = previous["ease"]
qx = previous["bend"]
track_names = previous["TRACKS"]
def correct_gait(state, key, p):
    if key.startswith("shin_") and state in ("Walk","Run"):
        phase=p+(math.pi if key.endswith("_r") else 0)
        recovery=easing(max(0,math.cos(phase)))
        return qx(-(.08 if state=="Walk" else .13) -
                  (.76 if state=="Walk" else .99)*recovery)
    if key.startswith("foot_") and state in ("Walk","Run"):
        phase=p+(math.pi if key.endswith("_r") else 0)
        recovery=easing(max(0,math.cos(phase)))
        return qx(.21*recovery-.08*max(0.,-math.cos(phase)))
    if key.startswith("shin_") and state=="Jump":
        return qx(-.48*math.sin(.5*p))
    return prev_gait(state,key,p)

for state,duration in (("Idle",2.4),("Walk",.90),("Run",.64),("Jump",.95),("Wave",2.0)):
    times=[duration*i/32 for i in range(33)]
    phases=[TAU*i/32 for i in range(33)]
    clip={"name":state,"samplers":[],"channels":[]}
    for key in track_names:
        angles=[correct_gait(state,key,p) for p in phases]
        source["track"](clip,source["joint_nodes"][B[key]],angles,times)
    previous["hip_track"](clip,times,phases,state)
    gltf["animations"].append(clip)

gltf["buffers"][0]["byteLength"]=len(buffer)
gltf["buffers"][0]["uri"]="data:application/octet-stream;base64,"+base64.b64encode(buffer).decode("ascii")
gltf["asset"]["generator"]="Aetherfall original v0.3.3 anime silhouette and backwards-knee fix"
out=Path("assets/characters/aetherfall_adventurer.gltf")
out.write_text(json.dumps(gltf,separators=(",",":")),encoding="utf-8")
print("AETHERFALL_V033: %d original skinned meshes, %d gait clips, %d packed bytes"%(
    len(gltf["meshes"]),len(gltf["animations"]),len(buffer)))
assert len(gltf["meshes"]) > 175
