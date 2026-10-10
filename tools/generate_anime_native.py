#!/usr/bin/env python3
"""Aetherfall: original Blender-native anime adventurer, not an MPFB/VRoid asset.

Generates a fresh stylized watertight-ish humanoid from lofted organic meshes,
projected facial geometry, layered pointed anime hair, a fitted fantasy outfit,
and a 22-joint authored armature. Every mesh has actual deform weights.

Run: blender -b -t 2 --python tools/generate_anime_native.py
The 4 hairstyle GLBs are intentionally independent for offline Android testing.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

OUT=Path("builds/anime-native")
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
MATH_TAU=math.tau
RIG=None
PARTS=[]
STYLE_OBJECTS={}

def mat(name,color,rough=.68,metal=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    b=m.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value=(*color,1)
        b.inputs["Roughness"].default_value=rough
        b.inputs["Metallic"].default_value=metal
    return m

skin=mat("Cel_Warm_Almond",(0.66,0.405,0.33),.76)
hair=mat("Anime_Blue_Black",(0.022,0.032,0.094),.47)
hair_light=mat("Anime_Cobalt_Highlights",(0.060,0.108,0.255),.53)
white=mat("Anime_Sclera",(0.95,0.88,0.82),.55)
iris=mat("Anime_Sapphire_Iris",(0.035,0.35,0.61),.38)
pupil=mat("Anime_Eye_Black",(0.009,0.017,0.042),.42)
glint=mat("Anime_Eye_Catchlight",(1,1,0.92),.3)
lash=mat("Anime_Liner",(0.013,0.018,0.035),.71)
lips=mat("Anime_Lips",(0.51,0.23,0.24),.74)
coat=mat("Adventurer_Navy_Coat",(0.046,0.082,0.17),.81)
leather=mat("Adventurer_Oxblood_Leather",(0.16,0.064,0.076),.84)
trim=mat("Adventurer_Antique_Gold",(0.71,0.47,0.20),.4,.45)
linen=mat("Adventurer_Linen",(0.69,0.64,0.56),.91)
boots=mat("Adventurer_Dark_Boot",(0.042,0.048,0.065),.86)
steel=mat("Adventurer_Blue_Steel",(0.19,0.26,0.34),.4,.55)

def mk_mesh(name,verts,faces,material,region=None,style=None):
    me=bpy.data.meshes.new(name+"Mesh")
    me.from_pydata(verts,[],faces)
    me.update()
    ob=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    for p in me.polygons:
        p.use_smooth=True
    ob["region"]=region or ""
    if style:
        ob["hair_style"]=style
        STYLE_OBJECTS.setdefault(style,[]).append(ob)
    PARTS.append(ob)
    return ob

def ellipse_loft(name,sections,material,sides=20,region=None,style=None,caps=True):
    # Each section = (z,cx,cy,rx,ry); smooth organic taper and ring blending.
    verts=[]
    faces=[]
    for z,cx,cy,rx,ry in sections:
        for j in range(sides):
            a=MATH_TAU*j/sides
            verts.append((cx+rx*math.cos(a),cy+ry*math.sin(a),z))
    for i in range(len(sections)-1):
        for j in range(sides):
            a=i*sides+j
            b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    if caps:
        faces.append(tuple(range(sides-1,-1,-1)))
        faces.append(tuple((len(sections)-1)*sides+j for j in range(sides)))
    return mk_mesh(name,verts,faces,material,region,style)

def tube(name,points,radii,material,sides=12,region=None,style=None):
    # Variable-width swept strand/cuff/limb, with an end cap.
    points=[Vector(p) for p in points]
    verts=[]
    faces=[]
    for i,p in enumerate(points):
        forward=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        normal=Vector((0,1,0))
        if abs(forward.dot(normal))>.90:
            normal=Vector((1,0,0))
        u=forward.cross(normal).normalized()
        v=forward.cross(u).normalized()
        for j in range(sides):
            a=MATH_TAU*j/sides
            q=p+radii[i]*(u*math.cos(a)+v*math.sin(a))
            verts.append(tuple(q))
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(range(sides-1,-1,-1)))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return mk_mesh(name,verts,faces,material,region,style)

def globe(name,center,radii,material,rings=15,sides=24,region=None,style=None):
    verts=[]
    faces=[]
    cx,cy,cz=center
    rx,ry,rz=radii
    for k in range(rings+1):
        t=math.pi*(k+.001)/(rings+.002)
        for i in range(sides):
            a=MATH_TAU*i/sides
            verts.append((cx+rx*math.sin(t)*math.cos(a),
                          cy+ry*math.sin(t)*math.sin(a),
                          cz+rz*math.cos(t)))
    for k in range(rings):
        for i in range(sides):
            a=k*sides+i;b=k*sides+(i+1)%sides
            # Top-to-bottom UV ellipsoids need reversed winding relative
            # to vertically ascending lofts; outward normals are essential.
            faces.append((a,a+sides,b+sides,b))
    return mk_mesh(name,verts,faces,material,region,style)

def patch(name,cx,cz,rx,rz,material,depth=.004,region="head"):
    # Project onto front ellipsoid, avoiding flat floating face polygons.
    def face_y(x,z):
        t=((x/.143)**2+((z-1.585)/.194)**2)
        return -.014-.112*math.sqrt(max(.055,1-t))-depth
    verts=[(cx,face_y(cx,cz),cz)]
    sides=22
    for j in range(sides):
        a=j*MATH_TAU/sides
        x=cx+rx*math.cos(a)
        z=cz+rz*math.sin(a)
        verts.append((x,face_y(x,z),z))
    faces=[(0,i+1,(i+1)%sides+1) for i in range(sides)]
    return mk_mesh(name,verts,faces,material,region)

# Original anime character body: compact torso, longer tapered legs, large
# tapered face, articulated arms and hands; all beneath the skinned coat.
ellipse_loft("Skin_Torso",[
    (.82,0,.006,.170,.114),(.97,0,.005,.172,.128),
    (1.08,0,0,.159,.127),(1.20,0,0,.224,.135),
    (1.33,0,.003,.218,.132),(1.39,0,.008,.129,.107)],skin,32,"torso")
ellipse_loft("Skin_Neck",[(1.335,0,0,.062,.059),
    (1.418,0,0,.050,.052),(1.482,0,-.001,.051,.052)],skin,20,"head")
globe("Skin_Anime_Head",(0,-.014,1.585),(.143,.112,.194),skin,22,32,"head")
for side,label in [(-1,"L"),(1,"R")]:
    globe("Skin_Ear_"+label,(side*.145,-.008,1.574),(.033,.028,.064),skin,10,12,"head")
    tube("Skin_UpperArm_"+label,[(side*.204,0,1.291),
        (side*.285,0,1.190),(side*.351,0,1.088)],
        [.091,.081,.061],skin,18,"arm_"+label)
    tube("Skin_Forearm_"+label,[(side*.355,0,1.093),
        (side*.398,-.008,.970),(side*.446,-.008,.855)],
        [.066,.061,.045],skin,18,"arm_"+label)
    globe("Skin_Hand_"+label,(side*.453,-.010,.819),(.053,.035,.088),skin,12,14,"hand_"+label)
    tube("Skin_Leg_"+label,[(side*.115,.0,.86),
        (side*.125,.0,.66),(side*.128,.009,.47),
        (side*.125,.018,.34),(side*.124,.018,.17)],
        [.122,.100,.085,.066,.055],skin,20,"leg_"+label)
    globe("Skin_Foot_"+label,(side*.125,-.067,.080),(.074,.158,.067),skin,12,18,"foot_"+label)

# Anime eye placement is on the *front*, facing Blender -Y.
for side,label in [(-1,"L"),(1,"R")]:
    x=side*.064
    patch("Face_%s_UpperLash"%label,x,1.600,.043,.026,lash,.009)
    patch("Face_%s_Sclera"%label,x,1.599,.037,.019,white,.013)
    patch("Face_%s_Iris"%label,x+side*.002,1.598,.016,.018,iris,.017)
    patch("Face_%s_Pupil"%label,x+side*.002,1.598,.009,.013,pupil,.022)
    patch("Face_%s_Catchlight"%label,x-side*.004,1.605,.005,.006,glint,.027)
    patch("Face_%s_Eyebrow"%label,x,1.646,.038,.007,lash,.012)
patch("Face_Nose_Shadow",0,1.541,.010,.006,lips,.009)
patch("Face_Lower_Lip",0,1.493,.023,.006,lips,.009)

# Fitted original adventurer outfit and separately skinned sleeves/boots.
ellipse_loft("Outfit_Tunic",[
    (.84,0,0,.183,.130),(.97,0,0,.185,.145),
    (1.10,0,0,.169,.145),(1.22,0,.003,.233,.155),
    (1.327,0,.004,.227,.152)],coat,32,"torso")
ellipse_loft("Outfit_Leather_Surcoat",[
    (.935,0,-.001,.189,.154),(1.020,0,-.001,.174,.154),
    (1.145,0,0,.239,.160),(1.269,0,0,.225,.158)],leather,32,"torso")
ellipse_loft("Outfit_Embroidered_Collar",[
    (1.332,0,0,.076,.074),(1.369,0,0,.079,.074),
    (1.397,0,0,.077,.072)],linen,24,"torso")
ellipse_loft("Outfit_Belt",[(.920,0,0,.195,.164),
   (.958,0,0,.195,.163)],boots,28,"torso")
ellipse_loft("Outfit_Belt_Gold",[(.930,0,0,.197,.169),
   (.939,0,0,.197,.169)],trim,28,"torso")
for side,label in [(-1,"L"),(1,"R")]:
    tube("Outfit_Leather_Sleeve_"+label,
         [(side*.207,0,1.287),(side*.283,0,1.18),
          (side*.350,0,1.072)], [.098,.089,.076],leather,18,"arm_"+label)
    tube("Outfit_Bracer_"+label,
         [(side*.366,-.004,1.066),(side*.395,-.006,.950),
          (side*.427,-.008,.869)], [.080,.078,.065],boots,18,"arm_"+label)
    globe("Outfit_Pauldron_"+label,(side*.245,.003,1.279),
         (.115,.139,.086),steel,10,16,"arm_"+label)
    tube("Outfit_Pauldron_Gold_"+label,
         [(side*.242,-.127,1.292),(side*.254,-.134,1.260),
          (side*.261,-.122,1.230)], [.009,.008,.006],trim,10,"arm_"+label)
    ellipse_loft("Outfit_Trousers_"+label,[
         (.34,side*.124,.011,.075,.077),
         (.48,side*.130,.009,.091,.086),
         (.68,side*.124,0,.111,.107),
         (.84,side*.112,0,.127,.126)],coat,20,"leg_"+label)
    ellipse_loft("Outfit_Boot_"+label,[
         (.055,side*.124,-.023,.091,.133),
         (.12,side*.125,-.015,.086,.112),
         (.29,side*.124,.015,.075,.087),
         (.42,side*.128,.019,.076,.086)],boots,20,"leg_"+label)
    globe("Outfit_ClosedToe_"+label,(side*.124,-.099,.066),
          (.092,.128,.051),boots,12,20,"foot_"+label)
    ellipse_loft("Outfit_BootUpperGold_"+label,[
         (.391,side*.128,.019,.080,.091),
         (.411,side*.128,.019,.080,.091)],trim,20,"leg_"+label)
    # Long asymmetric cloth tails with folds; double-sided material in Godot.
    tube("Outfit_SplitTail_"+label,
         [(side*.120,.119,.953),(side*.136,.153,.77),
          (side*.175,.161,.566)], [.071,.091,.048],coat,10,"torso")
# Central buckle and jacket lapels.
globe("Outfit_Belt_Buckle",(0,-.172,.938),(.047,.017,.033),trim,9,14,"torso")
for side,label in [(-1,"L"),(1,"R")]:
    tube("Outfit_Lapel_Gold_"+label,
         [(side*.044,-.167,1.269),(side*.093,-.176,1.182),
          (side*.073,-.167,1.081)], [.015,.020,.010],trim,10,"torso")

# Four distinct genuine volumetric hairstyles with individual sculpted blades.
def create_hair(style):
    def name(s):
        return "Hair_%s_%s"%(style,s)
    globe(name("Scalp"),(0,-.012,1.717),(.148,.119,.100),
          hair,12,26,"head",style)
    sizes={"Windswept":12,"Long":10,"Short":9,"Ponytail":10}
    for i in range(sizes[style]):
        u=(i/(sizes[style]-1)-.5)
        x=u*.232
        flip=(.025 if style=="Windswept" else -.006)
        tip_z={"Windswept":1.590,"Long":1.560,
               "Short":1.643,"Ponytail":1.607}[style]
        strand_end=(x+flip+math.sin(i*1.8)*.009,
                    -.142-math.sin(i*.7)*.012,
                    tip_z+math.cos(i*1.9)*.024)
        tube(name("Forelock%02d"%i),
             [(x*.60,-.070,1.787),
              (x*.98+flip*.4,-.134,1.701),
              strand_end],
             [.033,.026,.004],hair_light if i%5==0 else hair,8,"head",style)
    for side,label in [(-1,"L"),(1,"R")]:
        for i in range(4):
            length={"Windswept":1.518,"Long":1.321,
                    "Short":1.578,"Ponytail":1.544}[style]
            tube(name("%sTemple%02d"%(label,i)),
                 [(side*.098,.002,1.755),
                  (side*(.145+i*.008),-.049,1.630),
                  (side*(.148+i*.009),-.034,length+i*.022)],
                 [.033,.023,.003],hair_light if i==1 else hair,9,"head",style)
    back_count=12 if style=="Long" else 6
    for i in range(back_count):
        x=(i/max(1,back_count-1)-.5)*.265
        z={"Windswept":1.574,"Long":1.258,"Short":1.636,
           "Ponytail":1.609}[style]
        tube(name("Back%02d"%i),
             [(x*.55,.047,1.761),(x*.9,.115,1.583),
              (x*1.1,.082,z+.04*math.cos(i))],
             [.030,.029,.004],hair if i%4 else hair_light,8,"head",style)
    if style=="Ponytail":
        globe(name("HairTie"),(0,.117,1.711),(.044,.048,.047),trim,10,14,"head",style)
        for i in range(10):
            x=(i/9-.5)*.097
            tube(name("PonyBundle%02d"%i),
                 [(x*.3,.12,1.700),(x*.7,.205,1.537),
                  (x*1.6,.172,1.321+.05*math.sin(i))],
                 [.022,.022,.002],hair_light if i%5==0 else hair,8,"head",style)
for style in ("Windswept","Long","Short","Ponytail"):
    create_hair(style)

# Build small, complete humanoid skinning skeleton (22 deform bones).
bpy.ops.object.armature_add(enter_editmode=False,location=(0,0,0))
RIG=bpy.context.object
RIG.name="Aetherfall_Anime_Runtime_Rig"
bpy.ops.object.mode_set(mode="EDIT")
RIG.data.edit_bones.remove(RIG.data.edit_bones[0])
def bone(name,head,tail,parent=None):
    b=RIG.data.edit_bones.new(name)
    b.head=head
    b.tail=tail
    b.use_connect=False
    if parent:
        b.parent=RIG.data.edit_bones[parent]
    return b
bone("DEF-root",(0,0,.01),(0,0,.13))
bone("DEF-hips",(0,0,.87),(0,0,1.00),"DEF-root")
bone("DEF-spine",(0,0,1.00),(0,0,1.16),"DEF-hips")
bone("DEF-chest",(0,0,1.16),(0,0,1.35),"DEF-spine")
bone("DEF-neck",(0,0,1.35),(0,0,1.47),"DEF-chest")
bone("DEF-head",(0,0,1.48),(0,0,1.76),"DEF-neck")
for side,label in [(-1,"L"),(1,"R")]:
    bone("DEF-shoulder."+label,(side*.110,0,1.340),(side*.239,0,1.293),"DEF-chest")
    bone("DEF-upper_arm."+label,(side*.239,0,1.293),(side*.355,0,1.087),"DEF-shoulder."+label)
    bone("DEF-forearm."+label,(side*.355,0,1.087),(side*.446,0,.862),"DEF-upper_arm."+label)
    bone("DEF-hand."+label,(side*.446,0,.862),(side*.456,0,.765),"DEF-forearm."+label)
    bone("DEF-thigh."+label,(side*.112,0,.862),(side*.128,0,.476),"DEF-hips")
    bone("DEF-shin."+label,(side*.128,0,.476),(side*.125,0,.128),"DEF-thigh."+label)
    bone("DEF-foot."+label,(side*.125,0,.128),(side*.125,-.13,.060),"DEF-shin."+label)
    bone("DEF-toe."+label,(side*.125,-.13,.060),(side*.125,-.193,.052),"DEF-foot."+label)
bpy.ops.object.mode_set(mode="OBJECT")
BONE_NAMES={b.name for b in RIG.data.bones}
assert len(BONE_NAMES)==22,("Expected 22 joints",len(BONE_NAMES))

def bone_dist(p,b):
    # Distance to finite centerline, not infinite bone axis.
    a=Vector(b.head_local);end=Vector(b.tail_local)
    v=end-a
    t=max(0,min(1,(p-a).dot(v)/max(v.length_squared,1e-8)))
    return (p-(a+t*v)).length

for ob in PARTS:
    region=ob.get("region","")
    if region=="head":
        allowed=["DEF-head"]
    elif region=="torso":
        allowed=["DEF-hips","DEF-spine","DEF-chest","DEF-neck"]
    elif region.startswith("hand_"):
        allowed=["DEF-hand."+region[-1]]
    elif region.startswith("arm_"):
        allowed=["DEF-shoulder."+region[-1],"DEF-upper_arm."+region[-1],
                 "DEF-forearm."+region[-1],"DEF-hand."+region[-1]]
    elif region.startswith("foot_"):
        allowed=["DEF-foot."+region[-1],"DEF-toe."+region[-1]]
    elif region.startswith("leg_"):
        allowed=["DEF-thigh."+region[-1],"DEF-shin."+region[-1],"DEF-foot."+region[-1]]
    else:
        raise AssertionError("Mesh without bind region: "+ob.name)
    groups={name:ob.vertex_groups.new(name=name) for name in allowed}
    for v in ob.data.vertices:
        p=Vector(v.co)
        if len(allowed)==1:
            assigned=[(allowed[0],1.0)]
        else:
            weights=[]
            for name in allowed:
                dist=bone_dist(p,RIG.data.bones[name])
                weights.append((name,1/max(.012,dist)**3))
            assigned=sorted(weights,key=lambda item:item[1],reverse=True)[:4]
        total=sum(weight for _,weight in assigned)
        for name,weight in assigned:
            groups[name].add([v.index],weight/total,"REPLACE")
        assert total>0
    mod=ob.modifiers.new("Anime deform","ARMATURE")
    mod.object=RIG
    assert len(ob.data.vertices)>0

# Save fully editable Blender authoring source and four Godot-friendly GLBs.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"Aetherfall-Anime-Native.blend"))
export_info={}
for style in ("Windswept","Long","Short","Ponytail"):
    bpy.ops.object.select_all(action="DESELECT")
    RIG.select_set(True)
    for ob in PARTS:
        visible=not ob.name.startswith("Hair_") or ob.get("hair_style")==style
        ob.select_set(visible)
    bpy.context.view_layer.objects.active=RIG
    output=OUT/("anime-%s.glb"%style.lower())
    bpy.ops.export_scene.gltf(filepath=str(output),
        export_format="GLB",use_selection=True,
        export_skins=True,export_animations=False,
        export_materials="EXPORT")
    assert output.is_file() and output.stat().st_size>40000
    export_info[style]={"bytes":output.stat().st_size,
        "hair_meshes":len(STYLE_OBJECTS[style])}
# Render visual proof from the NEW model rather than prior MPFB previews.
for ob in PARTS:
    ob.hide_render=ob.name.startswith("Hair_") and ob.get("hair_style")!="Windswept"
ground=mat("Stage_Gray",(0.20,0.25,0.32),.85)
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.065))
floor=bpy.context.object
floor.name="PreviewFloor"
floor.dimensions=(12,12,.13)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
floor.data.materials.append(ground)
def light(name,loc,power):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=power
    data.shape="DISK"
    data.size=4
    ob=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(ob)
    ob.location=loc
    direction=Vector((0,0,1.0))-ob.location
    ob.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()
light("Key",(3,-4,6),450)
light("Fill",(-3,-1,5),280)
cam_data=bpy.data.cameras.new("PreviewCamera")
cam=bpy.data.objects.new("PreviewCamera",cam_data)
bpy.context.collection.objects.link(cam)
cam.location=(2.35,-4.0,2.18)
cam.rotation_euler=(Vector((0,0,1.04))-cam.location).to_track_quat("-Z","Y").to_euler()
cam_data.type="ORTHO"
cam_data.ortho_scale=2.45
bpy.context.scene.camera=cam
scene=bpy.context.scene
# CPU path works on headless Actions workers without libEGL.so.
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=12
scene.render.resolution_x=600
scene.render.resolution_y=900
scene.render.resolution_percentage=75
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(OUT/"anime-native-preview.png")
scene.world.color=(.17,.19,.24)
bpy.ops.render.render(write_still=True)
info={"generator":"Blender-native original anime model",
      "vrm_source":False,"mpfb_source":False,"bones":len(BONE_NAMES),
      "mesh_count":len(PARTS),
      "style_exports":export_info,
      "runtime_package_separate":True}
(OUT/"model-info.json").write_text(json.dumps(info,indent=2))
print("AETHERFALL_ANIME_NATIVE_GENERATION_OK "+json.dumps(info))
