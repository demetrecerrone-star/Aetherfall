#!/usr/bin/env python3
"""Validate user-provided GLBs and stage byte-identical runtime copies for Configura.

Use within Aetherfall repository (experimental branch):
python3 tools/stage_tripo_configura_candidates.py --male /path/male-muscular.glb --female /path/female-curvy.glb

No source mutation, bone renaming, retargeting, rigging, or model-generation requests.
The local .bin candidates are intentionally gitignored in this PUBLIC repository.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/characters/configura_candidates"
FINGERS = ("HandIndex", "HandMiddle", "HandPinky", "HandRing", "HandThumb")
EXPECTED = {
    "male": "da52c6f06a4f790ec7b61388f6c606419c68d2225abc77dfa45067fdd22ed649",
    "female": "4b09dcb61d65b9f3d12eee5673b2c7153fe5acdf2e61c2c3847fa9130cbe9eca",
}


def audit(path: Path, expected_digest: str) -> dict:
    raw = path.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != expected_digest:
        raise ValueError(f"Unexpected input digest for {path.name}; refusing unreviewed replacement")
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise ValueError(f"{path.name} is not a binary glTF")
    version, length, json_len, kind = struct.unpack_from("<IIII", raw, 4)
    if version != 2 or length != len(raw) or kind != 0x4E4F534A:
        raise ValueError(f"{path.name} failed GLB framing validation")
    doc = json.loads(raw[20:20 + json_len].decode("utf-8").strip())
    skins = doc.get("skins", [])
    if len(skins) != 1 or len(skins[0].get("joints", [])) != 65:
        raise ValueError(f"{path.name}: expected exactly one 65-joint skin")
    names = [doc["nodes"][index].get("name", "") for index in skins[0]["joints"]]
    if len(set(names)) != 65 or any(not n.startswith("mixamorig:") for n in names):
        raise ValueError(f"{path.name}: missing or duplicate Mixamo naming")
    fingers = [name for name in names if any(marker in name for marker in FINGERS)]
    if len(fingers) != 40:
        raise ValueError(f"{path.name}: expected all 40 finger joints, got {len(fingers)}")
    primitives = [p for m in doc.get("meshes", []) for p in m.get("primitives", [])]
    if not primitives or any(
        not {"POSITION", "NORMAL", "WEIGHTS_0", "JOINTS_0"} <= set(p.get("attributes", {}))
        for p in primitives
    ):
        raise ValueError(f"{path.name}: not all meshes are skinned")
    return {
        "sha256": digest,
        "bytes": len(raw),
        "bones": names,
        "mesh_count": len(doc.get("meshes", [])),
        "triangles": sum(doc["accessors"][p["indices"]]["count"] // 3 for p in primitives),
        "animations": len(doc.get("animations", [])),
        "materials": len(doc.get("materials", [])),
        "finger_joint_count": len(fingers),
    }


def main() -> None:
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--male", type=Path, required=True)
    cli.add_argument("--female", type=Path, required=True)
    args = cli.parse_args()
    sources = {"male": args.male, "female": args.female}
    results = {gender: audit(source, EXPECTED[gender]) for gender, source in sources.items()}
    if results["male"]["bones"] != results["female"]["bones"]:
        raise SystemExit("Candidate skeleton names/order differ, must retarget before runtime")
    DEST.mkdir(parents=True, exist_ok=True)
    for gender, source in sources.items():
        target = DEST / (gender + "_runtime.bin")
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != results[gender]["sha256"]:
            raise SystemExit("Refusing to overwrite a different staged model: " + str(target))
        shutil.copyfile(source, target)
        assert hashlib.sha256(target.read_bytes()).hexdigest() == results[gender]["sha256"]
    manifest = {
        "phase": "Configura visual prototype, original bones/weights preserved",
        "production_ready": False,
        "animation_retarged": False,
        "eyes_independently_colorable": False,
        "hair_swappable": False,
        "original_sources_changed": False,
        "characters": results,
    }
    (DEST / "candidate_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("AETHERFALL_TRIPO_CONFIGURA_CANDIDATES_STAGED: 2 models, 65 bones, 40 finger joints each")


if __name__ == "__main__":
    main()
