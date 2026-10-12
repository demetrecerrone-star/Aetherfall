#!/usr/bin/env python3
"""Retarget the existing seven authored Mixamo/Aetherfall clips to the v0.6.5
modular character. Preserve original mesh, skin, materials, equipment and bind
pose. Sample 64 semantic bones, including shoulders, knees, toes and fingers.
"""
import argparse, json, math, struct
from bisect import bisect_right
from pathlib import Path

CLIPS=("standing_relax","idle","look_around","walk","run","jump","sit")

def mul(a,b):
    x,y,z,w=a;p,q,r,s=b
    return (w*p+x*s+y*r-z*q,w*q-x*r+y*s+z*p,w*r+x*q-y*p+z*s,w*s-x*p-y*q-z*r)
def norm(q):
    m=math.sqrt(sum(t*t for t in q))
    return tuple(t/m for t in q)
def inv(q):
    x,y,z,w=norm(q)
    return (-x,-y,-z,w)
def slerp(a,b,t):
    a=norm(a);b=norm(b)
    d=sum(x*y for x,y in zip(a,b))
    if d<0:
        b=tuple(-v for v in b);d=-d
    if d>.9995:
        return norm(tuple((1-t)*x+t*y for x,y in zip(a,b)))
    theta=math.acos(max(-1,min(1,d)))
    return norm(tuple((math.sin((1-t)*theta)*x+math.sin(t*theta)*y)/math.sin(theta) for x,y in zip(a,b)))
def read(path):
    data=path.read_bytes()
    assert data[:4]==b"glTF" and struct.unpack_from("<I",data,8)[0]==len(data),path
    n,tag=struct.unpack_from("<I4s",data,12)
    assert tag==b"JSON"
    doc=json.loads(data[20:20+n].decode("utf-8"))
    ofs=20+n
    size,tag=struct.unpack_from("<I4s",data,ofs)
    assert tag==b"BIN\x00"
    return doc,bytearray(data[ofs+8:ofs+8+size])
def values(doc,data,accessor_index):
    a=doc["accessors"][accessor_index];v=doc["bufferViews"][a["bufferView"]]
    assert a["componentType"]==5126
    k={"SCALAR":1,"VEC4":4}[a["type"]]
    stride=v.get("byteStride",4*k)
    ofs=v.get("byteOffset",0)+a.get("byteOffset",0)
    return [struct.unpack_from("<"+"f"*k,data,ofs+i*stride) if k!=1
            else struct.unpack_from("<f",data,ofs+i*stride)[0] for i in range(a["count"])]
def global_rest(doc):
    parent={ch:i for i,node in enumerate(doc["nodes"]) for ch in node.get("children",[])}
    cache={}
    def get(i):
        if i not in cache:
            local=norm(doc["nodes"][i].get("rotation",(0,0,0,1)))
            cache[i]=norm(mul(get(parent[i]),local)) if i in parent else local
        return cache[i]
    return {i:get(i) for i in range(len(doc["nodes"]))}
def bone_names():
    m={"Hips":"pelvis","Spine":"spine_01","Spine1":"spine_02","Spine2":"spine_03",
       "Neck":"neck_01","Head":"Head"}
    for side,short in (("Left","l"),("Right","r")):
        for key,name in (("UpLeg","thigh"),("Leg","calf"),("Foot","foot"),("ToeBase","ball"),
                         ("Toe_End","ball_leaf"),("Shoulder","clavicle"),("Arm","upperarm"),
                         ("ForeArm","lowerarm"),("Hand","hand")):
            m[side+key]=name+"_"+short
        for finger in ("Index","Middle","Pinky","Ring","Thumb"):
            for i in range(1,5):
                segment="%02d"%i
                if i==4:segment+="_leaf"
                m[side+"Hand"+finger+str(i)]=finger.lower()+"_"+segment+"_"+short
    return m
def sample(track,t):
    if track is None:return None
    ts,qs,mode=track
    if t<=ts[0]:return norm(qs[0])
    if t>=ts[-1]:return norm(qs[-1])
    i=bisect_right(ts,t)-1
    return norm(qs[i]) if mode=="STEP" else slerp(qs[i],qs[i+1],(t-ts[i])/(ts[i+1]-ts[i]))

def build(original,authored,output):
    dst,buf=read(original)
    src,sbuf=read(authored)
    assert 65 in [len(s["joints"]) for s in src["skins"]]
    assert 65 in [len(s["joints"]) for s in dst["skins"]]
    assert not dst.get("animations"),"Original creator source is already animated; do not overwrite"
    dn={x.get("name"):i for i,x in enumerate(dst["nodes"])}
    sn={x.get("name"):i for i,x in enumerate(src["nodes"])}
    matches=[(sn["mixamorig:"+old],dn[new],new) for old,new in bone_names().items()
             if "mixamorig:"+old in sn and new in dn]
    assert len(matches)>=60,"Too few correct semantic bone matches"
    sr=global_rest(src);dr=global_rest(dst)
    align=mul(dr[dn["pelvis"]],inv(sr[sn["mixamorig:Hips"]]))
    ialign=inv(align)
    while len(buf)%4:buf.append(0)
    def acc(rows,kind,time=False):
        flat=[float(n) for row in rows for n in (row if isinstance(row,(tuple,list)) else (row,))]
        ofs=len(buf);buf.extend(struct.pack("<"+"f"*len(flat),*flat))
        vi=len(dst["bufferViews"]);dst["bufferViews"].append(
            {"buffer":0,"byteOffset":ofs,"byteLength":4*len(flat)})
        a={"bufferView":vi,"componentType":5126,"count":len(rows),"type":kind}
        if time:a.update({"min":[min(flat)],"max":[max(flat)]})
        ai=len(dst["accessors"]);dst["accessors"].append(a)
        while len(buf)%4:buf.append(0)
        return ai
    report={}
    for clip in CLIPS:
        source_clip=next((a for a in src["animations"] if a.get("name","").lower()==clip),None)
        assert source_clip is not None,"Missing authored animation "+clip
        tracks={};length=0
        for channel in source_clip["channels"]:
            if channel["target"]["path"]!="rotation":continue
            s=source_clip["samplers"][channel["sampler"]]
            mode=s.get("interpolation","LINEAR")
            assert mode in ("LINEAR","STEP")
            times=values(src,sbuf,s["input"]);qs=values(src,sbuf,s["output"])
            assert len(times)==len(qs) and len(times)>=2
            tracks[channel["target"]["node"]]=(times,qs,mode)
            length=max(length,times[-1])
        assert length>=.4,"Suspiciously short authored animation"
        frames=max(12,round(length*30))
        timeline=[length*i/frames for i in range(frames+1)]
        ta=acc(timeline,"SCALAR",True)
        anim={"name":clip,"channels":[],"samplers":[]}
        motion={}
        for si,di,name in matches:
            track=tracks.get(si)
            if track is None:continue
            rest_src=norm(src["nodes"][si].get("rotation",(0,0,0,1)))
            rest_dst=norm(dst["nodes"][di].get("rotation",(0,0,0,1)))
            sg=sr[si];tg=dr[di]
            rotations=[]
            for t in timeline:
                local=mul(inv(rest_src),sample(track,t))
                world=mul(mul(sg,local),inv(sg))
                delta=mul(mul(align,world),ialign)
                target_delta=mul(mul(inv(tg),delta),tg)
                q=norm(mul(rest_dst,target_delta))
                if rotations and sum(x*y for x,y in zip(q,rotations[-1]))<0:
                    q=tuple(-v for v in q)
                rotations.append(q)
            d=max(2*math.acos(min(1.,abs(sum(x*y for x,y in zip(rotations[0],q)))))
                  for q in rotations)
            motion[name]=round(math.degrees(d),1)
            out=acc(rotations,"VEC4")
            sm=len(anim["samplers"])
            anim["samplers"].append({"input":ta,"output":out,"interpolation":"LINEAR"})
            anim["channels"].append({"sampler":sm,"target":{"node":di,"path":"rotation"}})
        assert len(anim["channels"])>=60,clip
        if clip in ("walk","run"):
            assert motion.get("calf_l",0)>20 and motion.get("calf_r",0)>20, "Legs must actually bend"
        if clip=="idle":
            assert length>5 and motion.get("Head",0)>5, "Use fully authored breathing/weight shift"
        dst.setdefault("animations",[]).append(anim)
        report[clip]={"duration_s":round(length,2),"channels":len(anim["channels"]),
                      "left_knee_deg":motion.get("calf_l"),"right_knee_deg":motion.get("calf_r"),
                      "left_arm_deg":motion.get("upperarm_l"),"right_arm_deg":motion.get("upperarm_r")}
    # Wave remains the original creator's provisional preview clip.
    dur=1.6;frames=24
    times=acc([dur*i/frames for i in range(frames+1)],"SCALAR",True)
    wave={"name":"wave","channels":[],"samplers":[]}
    for name,strength in (("upperarm_r",-.72),("lowerarm_r",.35),("spine_02",.07)):
        ni=dn[name];rest=dst["nodes"][ni].get("rotation",(0,0,0,1));qs=[]
        for i in range(frames+1):
            env=math.sin(math.pi*i/frames)
            angle=strength*env*(math.sin(4*math.pi*i/frames) if name=="lowerarm_r" else 1)
            q=norm(mul(rest,(0,0,math.sin(angle/2),math.cos(angle/2))))
            qs.append(q)
        out=acc(qs,"VEC4");sid=len(wave["samplers"])
        wave["samplers"].append({"input":times,"output":out,"interpolation":"LINEAR"})
        wave["channels"].append({"sampler":sid,"target":{"node":ni,"path":"rotation"}})
    dst["animations"].append(wave)
    dst["buffers"][0]["byteLength"]=len(buf)
    meta=json.dumps(dst,separators=(",",":"),ensure_ascii=False).encode()
    meta+=b" "*((-len(meta))%4)
    data=b"glTF"+struct.pack("<II",2,12+8+len(meta)+8+len(buf))
    data+=struct.pack("<I4s",len(meta),b"JSON")+meta
    data+=struct.pack("<I4s",len(buf),b"BIN\x00")+buf
    assert struct.unpack_from("<I",data,8)[0]==len(data)
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(data)
    print("AETHERFALL_MIXAMO_RETARGET_OK:",len(matches),"mapped joints; 7 authored clips")
    print(json.dumps(report,sort_keys=True))

if __name__=="__main__":
    a=argparse.ArgumentParser()
    a.add_argument("creator",type=Path)
    a.add_argument("authored",type=Path)
    a.add_argument("output",type=Path)
    args=a.parse_args()
    build(args.creator,args.authored,args.output)
