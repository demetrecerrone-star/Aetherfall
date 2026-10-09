#!/usr/bin/env python3
"""Aetherfall original v0.3 full-mesh anime adventurer source generator.

Uses only Python's standard library. Produces a real, skinned glTF 2.0 scene
with original smooth, hand-designed ring loft geometry, skeleton, materials,
four alternate hairstyles, three outfit layers and five authored animations.
Unlike v0.2 this character is not made of independent Godot primitive meshes.
The resulting glTF is generated during Android CI before Godot asset import.
"""
import base64
import json
import math
import os
import struct
from pathlib import Path

TAU = math.tau
OUT = Path("assets/characters/aetherfall_adventurer.gltf")
C = {"hips": (0,.90,0), "spine": (0,1.16,0), "chest": (0,1.43,0),
     "neck": (0,1.64,0), "head": (0,1.84,0),
     "upper_l": (-.325,1.51,0), "lower_l": (-.38,1.16,0),
     "hand_l": (-.405,.86,0), "upper_r": (.325,1.51,0),
     "lower_r": (.38,1.16,0), "hand_r": (.405,.86,0),
     "thigh_l": (-.153,.83,0), "shin_l": (-.153,.44,0),
     "foot_l": (-.153,.10,-.08), "thigh_r": (.153,.83,0),
     "shin_r": (.153,.44,0), "foot_r": (.153,.10,-.08)}

J_NAMES = ["Hips","Spine","Chest","Neck","Head","LeftUpperArm","LeftForearm",
           "LeftHand","RightUpperArm","RightForearm","RightHand",
           "LeftThigh","LeftShin","LeftFoot","RightThigh","RightShin","RightFoot"]
KEYS = list(C.keys())
PARENTS = [-1,0,1,2,3,2,5,6,2,8,9,0,11,12,0,14,15]
BONE = {name:i for i,name in enumerate(KEYS)}
MAT = {}
mesh_defs = []
buffer = bytearray()
views = []
accessors = []
gltf = {"asset":{"version":"2.0","generator":"Aetherfall Original Character Generator v0.3"},
        "extensionsUsed": [], "scene":0, "scenes":[{"nodes":[]}],
        "nodes":[],"meshes":[],"skins":[],"animations":[],"materials":[],
        "bufferViews":views,"accessors":accessors,"buffers":[]}

def vadd(a,b): return tuple(a[i]+b[i] for i in range(3))
def vsub(a,b): return tuple(a[i]-b[i] for i in range(3))
def vmul(a,k): return tuple(x*k for x in a)
def dot(a,b): return sum(a[i]*b[i] for i in range(3))
def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def length(a): return math.sqrt(dot(a,a))
def norm(a):
    l=length(a)
    return vmul(a,1/l) if l>1e-8 else (0,1,0)
def mix(a,b,t): return tuple(a[i]*(1-t)+b[i]*t for i in range(3))
def color(hexcode): return [int(hexcode[i:i+2],16)/255 for i in (0,2,4)]+[1.]

def material(name, col, metallic=0.0, rough=0.83):
    n=len(gltf["materials"])
    MAT[name]=n
    gltf["materials"].append({"name":name,"doubleSided":True,
        "pbrMetallicRoughness":{"baseColorFactor":color(col),"metallicFactor":metallic,
        "roughnessFactor":rough}})
    return n

for args in [
 ("SkinMain","e2b59c",0,.8), ("SkinShadow","ae7467",0,.8),
 ("HairMain","24283e",0,.65), ("EyesWhite","fff7e6",0,.7),
 ("EyeIris","4b9bab",0,.42), ("EyeLine","202436",0,.55),
 ("ClothMain","3d5874",0,.9), ("ClothDark","253149",0,.9),
 ("Leather","655143",0,.85), ("MetalGold","bba26e",.52,.47),
 ("MetalSilver","9ca8b7",.55,.4), ("TrimLight","becbd1",0,.76),
 ("Trouser","2b3147",0,.9), ("Boot","2d2a36",0,.8),
 ("Cheek","d18b7f",0,.91), ("Blush","c98786",0,.9),
]: material(*args)

def align(b, n=4):
    while len(b)%n: b.append(0)

def acc(values, component, kind, target=None, track_minmax=False):
    """Add glTF binary buffer view/accessor. Flatten values with type-safe packing."""
    flat=[v for row in values for v in (row if isinstance(row,(list,tuple)) else [row])]
    fmt={5126:'f',5123:'H',5125:'I'}[component]
    align(buffer)
    start=len(buffer)
    buffer.extend(struct.pack('<'+fmt*len(flat),*flat))
    view={"buffer":0,"byteOffset":start,"byteLength":len(buffer)-start}
    if target is not None: view["target"]=target
    view_idx=len(views); views.append(view)
    item={"bufferView":view_idx,"componentType":component,"count":len(values),"type":kind}
    if track_minmax and values:
        dim = len(values[0]) if isinstance(values[0],(tuple,list)) else 1
        item["min"]=[min((r[k] if dim>1 else r) for r in values) for k in range(dim)]
        item["max"]=[max((r[k] if dim>1 else r) for r in values) for k in range(dim)]
    idx=len(accessors); accessors.append(item)
    return idx

def weights(spec):
    if isinstance(spec,int): return ((spec,0,0,0),(1.,0.,0.,0.))
    a,b,t=spec
    return ((a,b,0,0),(1.-t,t,0.,0.))

def skin_spec(*args): return tuple(args)

def finalize_mesh(name, matname, positions, uv, bones, tris, extras=None):
    if not positions:return
    normals=[[0.,0.,0.] for _ in positions]
    for a,b,c in tris:
        e1=vsub(positions[b],positions[a]);e2=vsub(positions[c],positions[a])
        n=cross(e1,e2)
        for i in (a,b,c):
            for j in range(3): normals[i][j]+=n[j]
    normals=[norm(n) for n in normals]
    joint_data=[]; weight_data=[]
    for b in bones:
        j,w=weights(b)
        joint_data.append(j);weight_data.append(w)
    pacc=acc(positions,5126,"VEC3",34962,True)
    nacc=acc(normals,5126,"VEC3",34962)
    tacc=acc(uv,5126,"VEC2",34962)
    jacc=acc(joint_data,5123,"VEC4",34962)
    wacc=acc(weight_data,5126,"VEC4",34962)
    ia=acc([i for face in tris for i in face],5125,"SCALAR",34963)
    mesh_index=len(gltf["meshes"])
    gltf["meshes"].append({"name":name,"primitives":[{"attributes":{"POSITION":pacc,
         "NORMAL":nacc,"TEXCOORD_0":tacc,"JOINTS_0":jacc,"WEIGHTS_0":wacc},
         "indices":ia,"material":MAT[matname]}]})
    node_idx=len(gltf["nodes"])
    node={"name":name,"mesh":mesh_index,"skin":0}
    if extras:node["extras"]=extras
    gltf["nodes"].append(node)
    gltf["scenes"][0]["nodes"].append(node_idx)
    mesh_defs.append(name)

def loft(name, matname, rings, bone_fn, segments=16, ellipse_axis=None):
    """Shape is a connected surface of cross-section rings, not a primitive."""
    pos=[]; uv=[]; bns=[]; tris=[]
    for idx,(center,rx,rz) in enumerate(rings):
        if ellipse_axis is None:
            u=(1.,0.,0.);v=(0.,0.,1.)
        else: u,v=ellipse_axis
        for k in range(segments):
            th=TAU*k/segments
            p=vadd(center,vadd(vmul(u,math.cos(th)*max(rx,.00001)),
                                 vmul(v,math.sin(th)*max(rz,.00001))))
            pos.append(p);uv.append((k/segments,idx/max(1,len(rings)-1)))
            bns.append(bone_fn(idx,p))
    for ring_index in range(len(rings)-1):
        for k in range(segments):
            a=ring_index*segments+k
            b=ring_index*segments+(k+1)%segments
            c=(ring_index+1)*segments+k
            d=(ring_index+1)*segments+(k+1)%segments
            tris.extend([(a,c,b),(b,c,d)])
    # Ensure outward winding for both ascending and descending loft sections.
    a,b,c=tris[0]
    actual=cross(vsub(pos[b],pos[a]),vsub(pos[c],pos[a]))
    center=rings[0][0]
    radial=vsub(pos[a],center)
    if dot(actual,radial)<0:
        tris=[(a,c,b) for a,b,c in tris]
    # close both tapered ends to avoid an open mannequin appearance
    center_bottom=rings[0][0];center_top=rings[-1][0]
    bottom_i=len(pos);pos.append(center_bottom);uv.append((.5,.5));bns.append(bone_fn(0,center_bottom))
    top_i=len(pos);pos.append(center_top);uv.append((.5,.5));bns.append(bone_fn(len(rings)-1,center_top))
    first=tris[0];flip=dot(cross(vsub(pos[first[1]],pos[first[0]]),vsub(pos[first[2]],pos[first[0]])),vsub(pos[first[0]],center))<0
    for k in range(segments):
        a=k;b=(k+1)%segments
        c=(len(rings)-1)*segments+k;d=(len(rings)-1)*segments+(k+1)%segments
        tris.extend([(bottom_i,b,a),(top_i,c,d)])
    finalize_mesh(name,matname,pos,uv,bns,tris)

def ellipse(y,rx,rz,x=0,z=0):
    return ((x,y,z),rx,rz)

def by_y(y):
    if y<.99:return BONE["hips"]
    if y<1.30:return BONE["spine"]
    return BONE["chest"]

# Separate skin and garment pieces are coherent smoothly lofted surfaces.
loft("Body_Torso","ClothMain",[
 ellipse(.84,.238,.168),ellipse(.91,.265,.18),ellipse(1.01,.229,.16),
 ellipse(1.11,.218,.155),ellipse(1.23,.256,.19),
 ellipse(1.35,.33,.196),ellipse(1.45,.335,.202),
 ellipse(1.55,.283,.172),ellipse(1.59,.13,.13)
],lambda i,p:by_y(p[1]),24)
loft("Body_HipCloth","ClothMain",[
 ellipse(.72,.258,.195),ellipse(.79,.266,.20),ellipse(.89,.265,.196),
 ellipse(.96,.241,.177)
],lambda i,p:BONE["hips"],20)
loft("Skin_Neck","SkinMain",[
 ellipse(1.55,.092,.091),ellipse(1.66,.081,.083),ellipse(1.76,.095,.10)
],lambda i,p:BONE["neck"],16)
# Head with tapered jawline, contoured cheekbones and gently angled cranium.
loft("Skin_Head","SkinMain",[
 ellipse(1.73,.075,.074),ellipse(1.765,.126,.111),
 ellipse(1.80,.167,.158),ellipse(1.86,.208,.17),
 ellipse(1.91,.222,.184),ellipse(1.98,.221,.187),
 ellipse(2.045,.183,.153),ellipse(2.085,.121,.118),
 ellipse(2.11,.045,.052)
],lambda i,p:BONE["head"],28)
# Forearms and fingers are now continuous section meshes (no toy balls).
for side in (-1,1):
    label="Left" if side<0 else "Right"
    upper=BONE["upper_l" if side<0 else "upper_r"]
    fore=BONE["lower_l" if side<0 else "lower_r"]
    hand=BONE["hand_l" if side<0 else "hand_r"]
    thigh=BONE["thigh_l" if side<0 else "thigh_r"]
    shin=BONE["shin_l" if side<0 else "shin_r"]
    foot=BONE["foot_l" if side<0 else "foot_r"]
    x=side
    loft("Body_%sSleeve"%label,"ClothMain",[
       ellipse(1.535,.130,.134,.32*x),ellipse(1.49,.142,.125,.342*x),
       ellipse(1.37,.114,.111,.36*x),ellipse(1.25,.101,.104,.367*x),
       ellipse(1.165,.111,.105,.38*x)
    ],lambda i,p:upper,16)
    loft("Body_%sForearm"%label,"ClothMain",[
       ellipse(1.19,.106,.106,.38*x),ellipse(1.13,.108,.105,.384*x),
       ellipse(1.03,.091,.091,.39*x),ellipse(.93,.077,.079,.40*x),
       ellipse(.88,.077,.08,.405*x)
    ],lambda i,p:fore,16)
    loft("Skin_%sHand"%label,"SkinMain",[
       ellipse(.887,.083,.082,.405*x),ellipse(.85,.081,.078,.405*x),
       ellipse(.79,.071,.073,.405*x),ellipse(.765,.026,.037,.41*x)
    ],lambda i,p:hand,16)
    loft("Body_%sTrouser"%label,"Trouser",[
       ellipse(.87,.16,.167,.16*x),ellipse(.78,.16,.165,.164*x),
       ellipse(.67,.137,.139,.165*x),ellipse(.56,.124,.126,.162*x),
       ellipse(.46,.124,.120,.155*x)
    ],lambda i,p:thigh,18)
    loft("Body_%sShin"%label,"Trouser",[
       ellipse(.49,.126,.12,.155*x),ellipse(.43,.126,.122,.155*x),
       ellipse(.33,.100,.111,.153*x),ellipse(.21,.084,.087,.153*x),
       ellipse(.16,.083,.09,.153*x)
    ],lambda i,p:shin,18)
    # Side-facing boot instep custom profile, slopes forward (-Z).
    loft("Body_%sBoot"%label,"Boot",[
       ellipse(.185,.116,.124,.153*x,-.011),
       ellipse(.14,.118,.132,.153*x,-.017),
       ellipse(.098,.119,.160,.153*x,-.057),
       ellipse(.068,.120,.178,.153*x,-.082),
       ellipse(.054,.111,.143,.153*x,-.087)
    ],lambda i,p:foot,20)

# Slim torso overlayer accessories: role-specific visibility at runtime.
loft("Outfit_Adventurer","Leather",[
 ellipse(.83,.258,.197,z=.0),ellipse(.86,.269,.20,z=.0),
 ellipse(.89,.271,.201,z=.0)
],lambda i,p:BONE["hips"],20)
loft("Outfit_Spellweaver","ClothDark",[
 ellipse(1.49,.344,.204),ellipse(1.52,.365,.209),
 ellipse(1.565,.348,.214),ellipse(1.63,.115,.105)
],lambda i,p:BONE["chest"],20)
loft("Outfit_Vanguard","MetalSilver",[
 ellipse(1.22,.28,.206),ellipse(1.30,.345,.207),
 ellipse(1.42,.354,.211),ellipse(1.54,.295,.18)
],lambda i,p:BONE["chest"],20)

# Hand-crafted flattened eye shapes on curved front of face; pupils/irises stay slim.
def eye_disc(name,mat,cx,cy,cz,rx,ry):
    ps=[(cx,cy,cz-.006)];uv=[(.5,.5)];bns=[BONE["head"]]
    tris=[]
    for k in range(16):
        th=TAU*k/16
        ps.append((cx+rx*math.cos(th),cy+ry*math.sin(th),cz))
        uv.append((.5+.5*math.cos(th),.5+.5*math.sin(th)));bns.append(BONE["head"])
    for k in range(16):tris.append((0,1+k,1+(k+1)%16))
    finalize_mesh(name,mat,ps,uv,bns,tris)
for side in (-1,1):
    lbl="Left" if side<0 else "Right"
    x=.087*side
    eye_disc("Eyes_%sWhite"%lbl,"EyesWhite",x,1.946,-.186,.063,.038)
    eye_disc("Eyes_%sIris"%lbl,"EyeIris",x,1.943,-.196,.027,.034)
    eye_disc("Eyes_%sPupil"%lbl,"EyeLine",x,1.939,-.2,.012,.021)
    eye_disc("Eyes_%sUpperLine"%lbl,"EyeLine",x,1.983,-.186,.063,.010)
eye_disc("Face_Nose","SkinShadow",0,1.858,-.188,.019,.024)
eye_disc("Face_Mouth","SkinShadow",0,1.804,-.172,.043,.006)
for side in (-1,1):
    eye_disc("Face_%sBlush"%("L" if side<0 else "R"),"Blush",.139*side,1.847,-.145,.046,.013)

def strand(name,mat,coords,bone=BONE["head"],radius=.045):
    rings=[]
    for i,p in enumerate(coords):
        t=i/max(len(coords)-1,1)
        r=radius*max(.09,(1-t*.87))
        rings.append((p,r,r*.70))
    loft(name,mat,rings,lambda i,p:bone,12)

# Every style is independent, named and skin-animated with the same head bone.
for style in ("Windswept","Long","Short","Ponytail"):
    loft("Hair_%sCap"%style,"HairMain",[
      ellipse(1.95,.218,.183,z=.023),ellipse(2.02,.220,.190,z=.025),
      ellipse(2.082,.19,.155,z=.020),ellipse(2.13,.085,.081,z=.018)
    ],lambda i,p:BONE["head"],24)
    bangs={"Windswept":8,"Long":8,"Short":5,"Ponytail":7}[style]
    for i in range(bangs):
        t=(i+.5)/bangs
        x=-.20+t*.4
        sweep=.032 if style=="Windswept" else -.012
        strand("Hair_%sFront%02d"%(style,i),"HairMain",[
            (x,2.07,-.103),(x+sweep,2.04,-.157),
            (x+sweep+.014,1.992-(i%3)*.018,-.191),
            (x+sweep+.01,1.96-(i%2)*.03,-.178)],radius=.050)
    if style in ("Long","Ponytail"):
        for i in range(7):
            x=-.17+i*.057
            length_to=1.42+abs(x)*.3 if style=="Long" else 1.58
            strand("Hair_%sBack%02d"%(style,i),"HairMain",[
              (x,2.05,.138),(x,1.94,.186),(x*1.14,1.76,.204),
              (x*1.13,length_to,.17)],radius=.08 if style=="Long" else .055)
        for side in (-1,1):
            strand("Hair_%sSide%d"%(style,side),"HairMain",[
              (.211*side,2.02,-.003),(.23*side,1.90,-.05),
              (.229*side,1.73,-.06),(.218*side,1.53 if style=="Long" else 1.75,-.01)
            ],radius=.065)
    elif style=="Windswept":
        for i in range(5):
            x=-.18+i*.09
            strand("Hair_WindsweptBack%02d"%i,"HairMain",[
                (x,2.11,.058),(x+.03,2.04,.20),
                (x+.055,1.92,.165)],radius=.077)
    if style=="Ponytail":
        for i in range(6):
            x=-.07+i*.028
            strand("Hair_PonytailTie%02d"%i,"HairMain",[
                (x,2.07,.160),(x,1.98,.25),
                (x+(i-2)*.024,1.74,.24),
                (x+(i-2)*.034,1.54,.18)],radius=.055)

# Worn equipment anchor: socket nodes parented to hand joints below.
joint_nodes=[]
for i,(name,key) in enumerate(zip(J_NAMES,KEYS)):
    parent=PARENTS[i]
    rest=C[key]; offset=rest if parent==-1 else vsub(rest,C[KEYS[parent]])
    node={"name":name,"translation":list(offset),"children":[]}
    idx=len(gltf["nodes"]);gltf["nodes"].append(node);joint_nodes.append(idx)
for i,p in enumerate(PARENTS):
    if p>=0:gltf["nodes"][joint_nodes[p]]["children"].append(joint_nodes[i])
gltf["scenes"][0]["nodes"].append(joint_nodes[0])
for joint_id,hand in ((7,"Right"),(10,"Left")):
    sock_id=len(gltf["nodes"])
    gltf["nodes"].append({"name":"EquipmentSocket_%sHand"%hand,
                          "translation":[0,-.07,-.10]})
    gltf["nodes"][joint_nodes[joint_id]]["children"].append(sock_id)
ibms=[]
for k in KEYS:
    x,y,z=C[k]
    ibms.append((1.,0.,0.,0., 0.,1.,0.,0., 0.,0.,1.,0., -x,-y,-z,1.))
ibm_accessor=acc(ibms,5126,"MAT4")
gltf["skins"].append({"name":"AetherfallHumanoidRig","joints":joint_nodes,
                      "skeleton":joint_nodes[0],"inverseBindMatrices":ibm_accessor})

# Original skeletal animation keyframes imported as a normal Godot AnimationPlayer.
def qx(a):return (math.sin(a/2),0.,0.,math.cos(a/2))
def qz(a):return (0.,0.,math.sin(a/2),math.cos(a/2))
def track(clip,node,keyframes,time_list,channel_name="rotation"):
    time_accessor=acc(time_list,5126,"SCALAR",track_minmax=True)
    val_accessor=acc(keyframes,5126,"VEC4")
    si=len(clip["samplers"])
    clip["samplers"].append({"input":time_accessor,"output":val_accessor,"interpolation":"LINEAR"})
    clip["channels"].append({"sampler":si,"target":{"node":node,"path":channel_name}})

for name,duration,amp,rate in [("Idle",2.0,.012,0.0),("Walk",.90,.33,1.),("Run",.63,.56,1.),
                               ("Jump",.90,.32,0.0),("Wave",2.0,.24,0.0)]:
    clip={"name":name,"samplers":[],"channels":[]}
    times=[0.,duration*.25,duration*.5,duration*.75,duration]
    for jkey,phase,axis in [
        ("thigh_l",0.,"x"),("thigh_r",math.pi,"x"),
        ("shin_l",math.pi*.5,"x"),("shin_r",math.pi*1.5,"x"),
        ("upper_l",math.pi,"x"),("upper_r",0.,"x"),
        ("lower_l",0.,"x"),("lower_r",0.,"x"),
        ("spine",0.,"x"),("head",0.,"x")]:
        vals=[]
        for t in times:
            p=t/duration
            if name=="Idle":
                angle=(.01 if jkey.startswith("thigh") else .017)*math.sin(p*TAU+phase)
            elif name in ("Walk","Run"):
                angle=amp*math.sin(p*TAU+phase)
                if jkey.startswith("shin"):angle=max(0.,angle)*.7
                if jkey.startswith("lower"):angle=-.11+angle*.2
                if jkey=="spine":angle=-.04 if name=="Run" else 0.
                if jkey=="head":angle=.02*math.cos(p*TAU)
            elif name=="Jump":
                angle=(-.25 if jkey=="thigh_l" else .22 if jkey=="thigh_r" else
                       -.21 if jkey.startswith("upper") else .05)
                angle*=math.sin(p*math.pi)
            else:
                angle=0.0
                if jkey=="upper_r":angle=-.18
            vals.append(qx(angle))
        if name=="Wave" and jkey=="upper_r":
            vals=[qz(1.42 if t>0 else 0.) for t in times]
        track(clip,joint_nodes[BONE[jkey]],vals,times)
    gltf["animations"].append(clip)

# finalize embedded data URI (compatible with Godot's glTF 2.0 importer)
gltf["buffers"].append({"byteLength":len(buffer),
    "uri":"data:application/octet-stream;base64,"+base64.b64encode(buffer).decode("ascii")})
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps(gltf,separators=(',',':')),encoding="utf-8")
print("Generated",OUT,len(gltf["meshes"]),"original skinned meshes",
      len(gltf["animations"]),"animation clips",len(buffer),"bytes of vertex/animation data")
assert len(gltf["meshes"])>80 and len(gltf["skins"])==1
