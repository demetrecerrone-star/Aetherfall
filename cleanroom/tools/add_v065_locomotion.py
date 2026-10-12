#!/usr/bin/env python3
"""Add first-pass gameplay animation clips to the recovered v0.6.5 skinned GLB.
Never edits any existing model mesh, material, skin weights or bind geometry.
These author-designed preview gaits are provisional until final mocap retargeting.
"""
import argparse, json, math, struct
from pathlib import Path

CLIPS = ("standing_relax","idle","look_around","walk","run","jump","sit","wave")
BONES = ("thigh_l","thigh_r","calf_l","calf_r","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","spine_01","spine_02","Head")
def quat_mul(a,b):
    x,y,z,w=a;p,q,r,s=b
    return (w*p+x*s+y*r-z*q,w*q-x*r+y*s+z*p,w*r+x*q-y*p+z*s,w*s-x*p-y*q-z*r)
def axis_quat(axis,ang):
    s=math.sin(ang/2);return (s if axis=="x" else 0.,s if axis=="y" else 0.,s if axis=="z" else 0.,math.cos(ang/2))
def pose(name,bone,t):
    wave=math.sin(2*math.pi*t)
    if name in ("walk","run"):
        amp=.28 if name=="walk" else .46
        leg=wave if bone.endswith("_l") else -wave
        if bone.startswith("thigh_"):return ("x",amp*leg)
        if bone.startswith("calf_"):return ("x",(.30 if name=="walk" else .47)*max(0.,-leg))
        if bone.startswith("upperarm_"):return ("x",-.35*amp*leg)
        if bone.startswith("lowerarm_"):return ("x",-.10-.12*amp*leg)
        if bone=="spine_01":return ("x",-.025 if name=="run" else 0.)
        if bone=="spine_02":return ("z",.018*wave)
        if bone=="Head":return ("x",.012*math.cos(2*math.pi*t))
    if name=="wave":
        if bone=="upperarm_r":return ("z",-.5*math.sin(math.pi*t))
        if bone=="lowerarm_r":return ("z",.38*math.sin(math.pi*t)*math.sin(4*math.pi*t))
    if name=="look_around" and bone=="Head":return ("y",.18*math.sin(2*math.pi*t))
    if name=="jump":
        if bone.startswith("thigh_"):return ("x",-.12*math.sin(math.pi*t))
        if bone.startswith("calf_"):return ("x",.22*math.sin(math.pi*t))
    if name=="sit":
        if bone.startswith("thigh_"):return ("x",-.08)
        if bone.startswith("calf_"):return ("x",.12)
    if bone=="spine_01":return ("x",.009*wave)
    if bone=="Head":return ("x",.007*wave)
    return ("x",0.)

def main(source,target):
    raw=source.read_bytes()
    assert raw[:4]==b"glTF" and struct.unpack_from("<I",raw,8)[0]==len(raw)
    json_size,json_type=struct.unpack_from("<I4s",raw,12)
    assert json_type==b"JSON"
    doc=json.loads(raw[20:20+json_size].decode("utf-8"))
    pos=20+json_size
    binary_size,binary_type=struct.unpack_from("<I4s",raw,pos)
    assert binary_type==b"BIN\\x00".decode("unicode_escape").encode("latin1")
    buffer=bytearray(raw[pos+8:pos+8+binary_size])
    joints={n.get("name"):i for i,n in enumerate(doc["nodes"])}
    assert all(name in joints for name in BONES)
    assert 65 in [len(s["joints"]) for s in doc["skins"]]
    assert not doc.get("animations"),"Do not overwrite original authored clips"
    doc.setdefault("animations",[])
    while len(buffer)%4:buffer.append(0)
    def accessor(rows,kind,check_time=False):
        flat=[float(x) for row in rows for x in (row if isinstance(row,(tuple,list)) else [row])]
        offset=len(buffer)
        buffer.extend(struct.pack("<"+"f"*len(flat),*flat))
        view=len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer":0,"byteOffset":offset,"byteLength":4*len(flat)})
        obj={"bufferView":view,"componentType":5126,"count":len(rows),"type":kind}
        if check_time:obj.update({"min":[min(flat)],"max":[max(flat)]})
        aid=len(doc["accessors"]);doc["accessors"].append(obj)
        while len(buffer)%4:buffer.append(0)
        return aid
    durations={"standing_relax":2.1,"idle":2.1,"look_around":2.1,"walk":.92,"run":.64,"jump":.9,"sit":1.25,"wave":1.6}
    for clip in CLIPS:
        times=[durations[clip]*i/8 for i in range(9)]
        times_ref=accessor(times,"SCALAR",True)
        animation={"name":clip,"samplers":[],"channels":[]}
        for bone in BONES:
            node=joints[bone];rest=doc["nodes"][node].get("rotation",[0,0,0,1])
            quats=[]
            for i in range(9):
                axis,angle=pose(clip,bone,i/8)
                q=quat_mul(rest,axis_quat(axis,angle))
                norm=math.sqrt(sum(v*v for v in q))
                quats.append(tuple(v/norm for v in q))
            rotations_ref=accessor(quats,"VEC4")
            sid=len(animation["samplers"])
            animation["samplers"].append({"input":times_ref,"output":rotations_ref,"interpolation":"LINEAR"})
            animation["channels"].append({"sampler":sid,"target":{"node":node,"path":"rotation"}})
        doc["animations"].append(animation)
    doc["buffers"][0]["byteLength"]=len(buffer)
    data=json.dumps(doc,separators=(",",":"),ensure_ascii=False).encode("utf-8")
    data+=b" " *((-len(data))%4)
    result=b"glTF"+struct.pack("<II",2,12+8+len(data)+8+len(buffer))
    result+=struct.pack("<I4s",len(data),b"JSON")+data+struct.pack("<I4s",len(buffer),b"BIN\\x00".decode("unicode_escape").encode("latin1"))+buffer
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(result)
    assert len(doc["animations"])==8 and struct.unpack_from("<I",result,8)[0]==len(result)
    print("AETHERFALL_V065_ANIM_OK: 65-joint modular male; eight preview locomotion clips; %d bytes"%len(result))
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("source",type=Path);p.add_argument("target",type=Path)
    args=p.parse_args();main(args.source,args.target)
