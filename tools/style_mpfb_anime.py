"""Original, editable anime hair + fantasy-adventurer armor for MPFB + Rigify.

Authoring dimensions match MPFB's 1.695-m Blender character. Every mesh receives
actual transferred human-body deform weights rather than rigid world geometry.
The four hairstyles remain individually editable and export as separate GLBs.
"""
import math
import bpy
from mathutils import Vector, kdtree

TAU=math.tau

def material(name,hex_color,roughness=.7,metallic=0.0):
    # Convert authored sRGB colors to Blender node linear space.
    srgb=[int(hex_color[i:i+2],16)/255.0 for i in (0,2,4)]
    color=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in srgb)
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value=(*color,1)
        bsdf.inputs["Roughness"].default_value=roughness
        bsdf.inputs["Metallic"].default_value=metallic
    return mat

def build_character(human,rig):
    ink=material("Aetherfall_BlueBlack_Anime_Hair","232944",.55)
    bright=material("Aetherfall_Hair_Sapphire_Rim","384a78",.56)
    shirt=material("Aetherfall_Midnight_Tunic","263b5c",.9)
    leather=material("Aetherfall_Leather_Jacket","422f33",.82)
    gold=material("Aetherfall_Gold_Trim","c6a066",.38,.52)
    dark=material("Aetherfall_Soft_Boots","1d2635",.9)
    moss=material("Aetherfall_Fantasy_Cloth","53747f",.88)
    # Fabric underlay on actual MPFB topology prevents exposed skin from
    # appearing through outfit overlays, especially torso and upper thighs.
    base_index=len(human.data.materials)
    for mat in (shirt,dark):
        human.data.materials.append(mat)
    for face in human.data.polygons:
        vs=[human.data.vertices[i].co for i in face.vertices]
        mx=sum(v.x for v in vs)/len(vs)
        mz=sum(v.z for v in vs)/len(vs)
        exposed_head=mz>=1.365
        exposed_hands=abs(mx)>.435 and .77<mz<1.11
        if exposed_head or exposed_hands:
            face.material_index=0
        elif mz<.425:
            face.material_index=base_index+1
        else:
            face.material_index=base_index
    objects=[]

    # Only MPFB vertices with real Rigify deformation weights can donate.
    # Mask and detailed-helper vertices are deliberately excluded: those
    # were the source of the original "Unweighted accessory vertex" failure.
    valid={bone.name for bone in rig.data.bones if bone.use_deform}
    donor_weights={}
    for source in human.data.vertices:
        weights=sorted((
            (human.vertex_groups[group.group].name,group.weight)
            for group in source.groups
            if group.weight>0
            and human.vertex_groups[group.group].name in valid
        ),key=lambda entry:entry[1],reverse=True)[:4]
        total=sum(weight for _,weight in weights)
        if total>1e-8:
            donor_weights[source.index]=tuple((name,weight/total) for name,weight in weights)
    assert len(donor_weights)>1000,"Too few fully weighted MPFB donor vertices"

    def make_tree(indices):
        tree=kdtree.KDTree(len(indices))
        for index in indices:
            tree.insert(human.data.vertices[index].co,index)
        tree.balance()
        return tree

    all_indices=list(donor_weights)
    kd=make_tree(all_indices)
    # An accessory belonging to one leg/arm must never borrow weights from
    # its opposite side when donor geometry is close to the body midline.
    side_trees={
        side:make_tree([i for i in all_indices
                        if side*human.data.vertices[i].co.x>.025])
        for side in (-1,1)
    }

    def bind(obj,weight_anchor=None):
        obj.parent=None
        for mod in tuple(obj.modifiers):
            if mod.type=="ARMATURE":
                obj.modifiers.remove(mod)
        arm=obj.modifiers.new("Rigify deformation","ARMATURE")
        arm.object=rig
        left="_Left" in obj.name
        right="_Right" in obj.name
        donor_tree=side_trees[-1] if left else side_trees[1] if right else kd
        groups={}
        for v in obj.data.vertices:
            # Bangs and ponytails bind to the head even when their tips
            # approach shoulders. Armor, trousers and boots sample each
            # mesh vertex, retaining smooth deformation over joints.
            p=Vector(weight_anchor) if weight_anchor is not None else v.co
            samples=donor_tree.find_n(p,1 if weight_anchor is not None else 4)
            assert samples, "No weighted MPFB donor for %s"%obj.name
            blend={}
            for _,index,distance in samples:
                # Every entry was prevalidated above; no unweighted helper
                # can participate in the interpolation or normalization.
                importance=1.0/max(distance,0.0005)**2
                for name,weight in donor_weights[index]:
                    blend[name]=blend.get(name,0.0)+importance*weight
            assigned=sorted(blend.items(),key=lambda item:item[1],reverse=True)[:4]
            total=sum(weight for _,weight in assigned)
            assert total>1e-8, "Unweighted accessory vertex: %s[%d]"%(obj.name,v.index)
            for name,weight in assigned:
                if name not in groups:
                    groups[name]=obj.vertex_groups.new(name=name)
                groups[name].add([v.index],weight/total,"REPLACE")
        # Validation is explicit, so a future helper-geometry regression
        # fails here rather than silently exporting rigid accessories.
        for v in obj.data.vertices:
            total=sum(g.weight for g in v.groups
                      if obj.vertex_groups[g.group].name in valid)
            assert abs(total-1.0)<1e-3, "Bad accessory skin weights: %s[%d] %.4f"%(obj.name,v.index,total)
        objects.append(obj)
        return obj

    def mesh(name,points,polys,mat,anchor=None):
        datablock=bpy.data.meshes.new(name+"Mesh")
        datablock.from_pydata(points,[],polys)
        datablock.update()
        item=bpy.data.objects.new(name,datablock)
        bpy.context.collection.objects.link(item)
        datablock.materials.append(mat)
        for polygon in datablock.polygons:
            polygon.use_smooth=True
        return bind(item,anchor)

    def ellipse_loft(name,sections,mat,n=24,anchor=None):
        # rings = [(z, rx, ry, center_y)]; vertical ellipses
        verts=[];faces=[]
        for z,rx,ry,cy in sections:
            for j in range(n):
                a=j*TAU/n
                verts.append((rx*math.cos(a),cy+ry*math.sin(a),z))
        for k in range(len(sections)-1):
            for j in range(n):
                a=k*n+j;b=k*n+(j+1)%n
                faces.append((a,b,b+n,a+n))
        faces.append(tuple(range(n-1,-1,-1)))
        faces.append(tuple((len(sections)-1)*n+i for i in range(n)))
        return mesh(name,verts,faces,mat,anchor)

    def tapered_strand(name,control,radius,mat,anchor):
        # Bézier tube with a *real taper* to sharp anime hair tips.
        a,b,c=[Vector(p) for p in control]
        pts=[];faces=[]
        rings=8; sides=7
        for k in range(rings):
            t=k/(rings-1)
            pt=(1-t)**2*a+2*(1-t)*t*b+t*t*c
            tangent=(2*(1-t)*(b-a)+2*t*(c-b)).normalized()
            axis=Vector((1,0,0))
            if abs(tangent.dot(axis))>.90:
                axis=Vector((0,1,0))
            u=tangent.cross(axis).normalized()
            v=tangent.cross(u).normalized()
            width=radius*(1-.90*t)*(0.92+0.12*math.sin(t*math.pi))
            for j in range(sides):
                angle=TAU*j/sides
                point=pt+width*(u*math.cos(angle)+v*math.sin(angle))
                pts.append(tuple(point))
        for k in range(rings-1):
            for j in range(sides):
                x=k*sides+j;y=k*sides+(j+1)%sides
                faces.append((x,y,y+sides,x+sides))
        return mesh(name,pts,faces,mat,anchor)

    # Adult stylized head top is approximately z=1.69. Instead of a bald
    # painted dome, each style has its own 3D scalp shell and individual tufts.
    scalp_anchor=(0,-.06,1.635)
    head_center=Vector((0,-.042,1.562))
    for style in ("Windswept","Long","Short","Ponytail"):
        pts=[];polys=[];sides=28;levels=8
        for row in range(levels):
            theta=(.07+1.18*row/(levels-1))
            for j in range(sides):
                phi=TAU*j/sides
                x=.101*math.sin(theta)*math.cos(phi)
                y=-.042+.113*math.sin(theta)*math.sin(phi)
                # Raised hairline on the forehead; hair cap doesn't mask eyes.
                face=max(0, -math.sin(phi))
                z=1.565+.137*math.cos(theta)+.025*face*math.sin(theta)
                pts.append((x,y,z))
        for row in range(levels-1):
            for j in range(sides):
                u=row*sides+j;v=row*sides+(j+1)%sides
                polys.append((u,v,v+sides,u+sides))
        mesh("Hair_"+style+"_Crown",pts,polys,ink,scalp_anchor)

        # Unique 3D fringe shapes and directions. Different tip heights give
        # recognizable front silhouettes, not interchangeable flat quads.
        count={"Windswept":11,"Long":9,"Short":7,"Ponytail":8}[style]
        for i in range(count):
            u=i/max(1,count-1)
            x=(u-.5)*.167
            start=(x*.53,-.075,1.686-.015*abs(x))
            if style=="Windswept":
                tip=(x+.035,-.171,1.565+.018*math.sin(i*.7))
                bend=(x+.026,-.135,1.653)
            elif style=="Short":
                tip=(x-.008,-.161,1.605+.015*math.sin(i*1.4))
                bend=(x,-.147,1.665)
            elif style=="Long":
                tip=(x-.018,-.173,1.575+.012*math.sin(i*.8))
                bend=(x-.014,-.154,1.649)
            else:
                tip=(x-.005,-.169,1.598+.010*math.cos(i))
                bend=(x,-.139,1.665)
            tapered_strand("Hair_%s_Bang%02d"%(style,i),[start,bend,tip],
                           .014 if style!="Short" else .013,
                           bright if i%4==0 else ink,scalp_anchor)

        # Back locks vary radically: the ponytail has a raised tie and one
        # long tapered bundle; long hair reaches the shoulder blades; short
        # hair terminates above the ears.
        if style=="Long":
            for i in range(12):
                a=(i/11-.5)*.188
                tapered_strand("Hair_Long_Back%02d"%i,
                    [(a*.80,.045,1.660),(a*1.13,.103,1.45),(a*1.22,.066,1.245+.035*math.sin(i))],
                    .016,bright if i%5==0 else ink,scalp_anchor)
        elif style=="Ponytail":
            for i in range(11):
                a=(i/10-.5)*.11
                tapered_strand("Hair_Ponytail_Bundle%02d"%i,
                    [(a*.4,.067,1.627),(a,.155,1.54),(a*1.3,.118,1.290+.040*math.sin(i))],
                    .019,bright if i%4==0 else ink,scalp_anchor)
            ellipse_loft("Hair_Ponytail_Tie",[(1.606,.042,.035,.093),
                         (1.627,.047,.036,.094),(1.648,.038,.032,.090)],gold,16,scalp_anchor)
        elif style=="Windswept":
            for i in range(6):
                a=(i/5-.5)*.18
                tapered_strand("Hair_Windswept_Back%02d"%i,
                    [(a*.5,.015,1.67),(a+.025,.080,1.625),(a+.040,.071,1.543)],
                    .018,ink,scalp_anchor)
        else:
            for i in range(6):
                a=(i/5-.5)*.177
                tapered_strand("Hair_Short_Back%02d"%i,
                    [(a*.55,.027,1.669),(a,.082,1.632),(a,.045,1.575)],
                    .012,ink,scalp_anchor)

    # Tailored adventurer clothing: a dark fitted base, layered leather
    # surcoat, gold hem, boots, collar, segmented guards, and long split tails.
    # All sections are 3D skinned meshes, not decal images.
    ellipse_loft("Outfit_Adventurer_Tunic",[
        (.83,.190,.133,-.008),(.91,.181,.128,-.009),
        (1.03,.168,.137,-.011),(1.18,.210,.139,-.008),
        (1.255,.213,.120,-.010)],shirt)
    ellipse_loft("Outfit_Adventurer_Surcoat",[
        (.895,.204,.146,-.012),(1.01,.176,.150,-.012),
        (1.15,.218,.149,-.011),(1.238,.219,.136,-.010)],leather)
    ellipse_loft("Outfit_Adventurer_Collar",[
        (1.275,.083,.086,-.028),(1.31,.076,.080,-.028),
        (1.341,.083,.087,-.027)],dark,18)
    ellipse_loft("Outfit_Adventurer_GoldWaistBand",[
        (.915,.187,.153,-.010),(.94,.189,.153,-.010)],gold,30)

    # Armor plaques on upper arms and bracer cuffs on forearms.
    for side,sname in [(-1,"Left"),(1,"Right")]:
        # Joints lie around x=.25..45 (arms hang at z~1.08).
        x=side*.286
        pts=[(x+side*dx,yy,zz) for dx,yy,zz in
          [(-.063,-.10,1.235),(.058,-.11,1.225),
           (.072,-.077,1.105),(-.075,-.067,1.102),
           (-.061,-.125,1.21),(.060,-.130,1.20)]]
        faces=[(0,1,5,4),(0,4,3),(1,2,5),(4,5,2,3)]
        mesh("Outfit_Adventurer_%sPauldron"%sname,pts,faces,leather)
        # Align bracers to the actual Rigify forearm bones instead of
        # leaving rigid vertical cylinders hanging below wrists.
        forearms=[rig.data.bones[n] for n in ("DEF-forearm.L","DEF-forearm.R")]
        forearm=min(forearms,key=lambda b:abs(b.head_local.x-side*.4))
        start=forearm.head_local
        finish=forearm.tail_local
        forward=(finish-start).normalized()
        u=forward.cross(Vector((0,0,1))).normalized()
        v=forward.cross(u).normalized()
        verts=[];faces=[]
        for t,rad in ((.15,.065),(.65,.061),(.90,.051)):
            center=start.lerp(finish,t)
            for j in range(12):
                a=TAU*j/12
                p=center+rad*(u*math.cos(a)+v*math.sin(a))
                verts.append(tuple(p))
        for k in range(2):
            for j in range(12):
                p=k*12+j;q=k*12+(j+1)%12
                faces.append((p,q,q+12,p+12))
        mesh("Outfit_Adventurer_%sBracer"%sname,verts,faces,dark)
        # Proper full-length cloth trousers so the MPFB human skin does not
        # remain exposed between surcoat tails and boots.
        trousers=[]; trouser_faces=[]
        sections=[(.375,.071,.073,side*.137,-.005),
                  (.46,.082,.079,side*.146,-.002),
                  (.61,.087,.087,side*.157,-.008),
                  (.745,.099,.098,side*.151,-.008),
                  (.865,.104,.103,side*.134,-.011)]
        for z,rx,ry,cx,cy in sections:
            for j in range(18):
                a=TAU*j/18
                trousers.append((cx+rx*math.cos(a),cy+ry*math.sin(a),z))
        for k in range(len(sections)-1):
            for j in range(18):
                p=k*18+j;q=k*18+(j+1)%18
                trouser_faces.append((p,q,q+18,p+18))
        mesh("Outfit_Adventurer_%sTrousers"%sname,
             trousers,trouser_faces,shirt)
        # Boots around human shins; keep forward sole shorter than knees.
        verts=[];faces=[]
        for z,rx,ry in ((.045,.086,.126),(.16,.071,.087),
                         (.29,.068,.075),(.41,.061,.068)):
            for j in range(18):
                a=TAU*j/18
                verts.append((side*.134+rx*math.cos(a),
                              -.002+ry*math.sin(a),z))
        for k in range(3):
            for j in range(18):
                p=k*18+j;q=k*18+(j+1)%18
                faces.append((p,q,q+18,p+18))
        mesh("Outfit_Adventurer_%sBoot"%sname,verts,faces,dark)

    # A buckle with a clear glowing-metal highlight; belt and lapped waistcoat
    # occupy visible separate meshes for future outfit recoloring.
    verts=[(-.038,-.171,.904),(.038,-.171,.904),
           (.038,-.177,.957),(-.038,-.177,.957)]
    mesh("Outfit_Adventurer_Buckle",verts,[(0,1,2,3)],gold)
    for side,sname in ((-1,"Left"),(1,"Right")):
        verts=[(side*.035,-.158,.927),(side*.158,-.133,.915),
               (side*.191,-.093,.688),(side*.050,-.153,.719)]
        mesh("Outfit_Adventurer_%sSplitCoatTail"%sname,
             verts,[(0,1,2,3)],moss)
    assert len(objects)>65, "Anime hair and outfit did not generate"
    return objects
