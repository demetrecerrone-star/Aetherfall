#!/usr/bin/env python3
"""Reconstruct exact user-supplied fitted Tripo peasant GLBs from binary git shards.

No external website or temporary session needed at CI build time.
"""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "models" / "tripo"
FILES = {
    "male": (10, 5237784, "54eb9ef721a8150b78081ed47f6cac6cb0f56e1e4aacb9a6ded25c2cc6535127"),
    "female": (10, 4983920, "9a7b81dfad1ee52f95ab9abb006eebaa44e028f2af677188905a2a750efdb986"),
}
for sex, (count, length, checksum) in FILES.items():
    pieces = [ROOT / f"{sex}_peasant.part{i:02d}" for i in range(count)]
    raw = b"".join(part.read_bytes() for part in pieces)
    assert len(raw) == length, (sex, len(raw))
    assert hashlib.sha256(raw).hexdigest() == checksum, "Tripo model SHA mismatch"
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
    size = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    assert len(doc["skins"][0]["joints"]) == 65
    assert len(doc["animations"]) == 3
    clips = {x.get("name", "").lower() for x in doc["animations"]}
    assert {"walk", "run", ("idle" if sex == "female" else "standing_relax")} <= clips
    assert len(doc.get("images", [])) >= 2
    mesh_names = [n.get("name","") for n in doc["nodes"] if "mesh" in n]
    assert sum(n.startswith("AF_Gear_") for n in mesh_names) == 15
    assert sum(n.startswith("AF_") and not n.startswith("AF_Gear_") for n in mesh_names) == 15
    output = ROOT / f"{sex}_runtime.bin"
    output.write_bytes(raw)
    print("AETHERFALL_TRIPO_READY",sex,len(raw),"bytes",checksum)
