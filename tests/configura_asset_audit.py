#!/usr/bin/env python3
"""Non-destructive audit of the *existing* universal avatars, NOT new Tripo uploads."""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
records = {}
for gender in ("male", "female"):
    p = root / "cleanroom" / "models" / "universal" / f"{gender}_runtime.bin"
    b = p.read_bytes()
    assert len(b) > 1_000_000 and b[:4] == b"glTF", f"Invalid GLB data: {p}"
    version, byte_count, json_len, chunk_type = struct.unpack_from("<IIII", b, 4)
    assert version == 2 and byte_count == len(b) and chunk_type == 0x4E4F534A
    data = json.loads(b[20:20 + json_len].decode("utf8").strip())
    bone_counts = [len(s.get("joints", [])) for s in data.get("skins", [])]
    clips = {x.get("name") for x in data.get("animations", [])}
    assert 65 in bone_counts, (gender, bone_counts)
    assert {"Idle_Loop", "Walk_Loop", "Sprint_Loop"} <= clips, (gender, clips)
    assert len(clips) >= 20, (gender, len(clips))
    records[gender] = {"bytes": len(b), "skin_joint_counts": bone_counts,
                       "animation_count": len(clips), "essential_animations": sorted(
                           {"Idle_Loop", "Walk_Loop", "Sprint_Loop"} & clips)}
    print("AETHERFALL_UNIVERSAL_65_BONE_OK", gender, len(b), len(clips))
out = root / "builds" / "configura_asset_audit.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({
    "status": "source-asset-compatibility-only",
    "characters": records,
    "approved_tripo_assets_imported": False,
    "clothing_fit_and_deformation_verified": False,
    "starter_town_gameplay_tested": False,
    "note": "Existing Quaternius Universal runtime assets, not five newly approved Tripo GLBs."
}, indent=2))
print("AETHERFALL_CONFIGURA_ASSET_AUDIT", out)
