import argparse, zipfile, struct, hashlib, copy

def entries(blob):
    assert blob[:4] == b"GDPC"
    count = struct.unpack_from("<I", blob, 104)[0]
    pos = 108
    out = {}
    for _ in range(count):
        begin = pos
        n = struct.unpack_from("<I",blob,pos)[0]; pos+=4
        name=blob[pos:pos+n].rstrip(b"\0").decode("utf8");pos+=n+36
        out[name]=blob[begin:pos]
    assert pos==len(blob)
    return blob[:104],out

def entry(name,data):
    path=name.encode("utf8");path+=b"\0"*((-len(path))%4)
    return struct.pack("<I",len(path))+path+struct.pack("<QQ",0,len(data))+hashlib.md5(data).digest()+struct.pack("<I",0)

def main(base_name,template_name,out_name):
    required=["title_backdrop.gdc","title_backdrop.gd.remap","title_screen.gdc","title_screen.gd.remap","title_screen.tscn.remap","loading_screen.gdc","loading_screen.gd.remap","loading_screen.tscn.remap","menu_ambience.gdc","menu_ambience.gd.remap"]
    with zipfile.ZipFile(base_name) as base,zipfile.ZipFile(template_name) as temp:
        original=set(base.namelist());tmpl=set(temp.namelist())
        extra=["assets/"+s for s in required]
        extra += [s for s in sorted(tmpl-original) if s.startswith("assets/.godot/exported/") and ("-title_screen.scn" in s or "-loading_screen.scn" in s)]
        assert len(extra)==12 and all(s in tmpl and s not in original for s in extra)
        config=temp.read("assets/project.binary")
        assert b"res://title_screen.tscn" in config and b"AetherfallAmbience" in config
        header, index=entries(base.read("assets/assets.sparsepck"))
        _,tidx=entries(temp.read("assets/assets.sparsepck"))
        for s in extra:
            asset=s[7:]
            assert asset in tidx and asset not in index
            index[asset]=entry(asset,temp.read(s))
        index["project.binary"]=entry("project.binary",config)
        sparse=header+struct.pack("<I",len(index))+b"".join(index.values())
        assert len(entries(sparse)[1])==len(index)
        with zipfile.ZipFile(out_name,"w",allowZip64=True) as out:
            for zi in base.infolist():
                n=zi.filename
                if n.startswith("META-INF/"): continue
                payload=config if n=="assets/project.binary" else sparse if n=="assets/assets.sparsepck" else base.read(n)
                out.writestr(copy.copy(zi),payload)
            for n in extra:
                out.writestr(n,temp.read(n),compress_type=zipfile.ZIP_DEFLATED)
        with zipfile.ZipFile(out_name) as out:
            for zi in base.infolist():
                if zi.filename.startswith("META-INF/") or zi.filename in ("assets/project.binary","assets/assets.sparsepck"):continue
                assert out.read(zi.filename)==base.read(zi.filename), "modified original: "+zi.filename
            assert len(entries(out.read("assets/assets.sparsepck"))[1])==len(index)
    print("AETHERFALL_EXACT_APK_PATCH_OK: 12 title files inserted without changing any gameplay assets")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--base",required=True)
    p.add_argument("--template",required=True)
    p.add_argument("--output",required=True)
    a=p.parse_args()
    main(a.base,a.template,a.output)
