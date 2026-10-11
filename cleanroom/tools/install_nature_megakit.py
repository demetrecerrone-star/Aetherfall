#!/usr/bin/env python3
"""Safely install the user's trimmed CC0 Quaternius Stylized Nature MegaKit.
Use the exact archive prepared from their uploaded Standard edition.
"""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import sys

ARCHIVE = Path("Aetherfall-Nature-Assets-For-GitHub.zip")
DEST = Path("cleanroom")
EXPECTED = {
    "Bush_Common", "Bush_Common_Flowers", "Pine_1", "Pine_2", "Pine_3",
    "Pine_4", "Pine_5", "CommonTree_1", "CommonTree_2", "CommonTree_3",
    "Grass_Common_Short", "Grass_Wispy_Short", "Fern_1", "Clover_1",
}

def main() -> None:
    if not ARCHIVE.is_file():
        sys.exit(
            "AETHERFALL_NATURE_MISSING: Add the prepared 6.3 MB "
            "Aetherfall-Nature-Assets-For-GitHub.zip to the root of "
            "feature/quaternius-nature-megakit-import. "
            "The nature-preview build will not ship procedural fallbacks."
        )
    if ARCHIVE.stat().st_size > 15_000_000:
        sys.exit("AETHERFALL_NATURE_FAIL: Unexpected oversized nature bundle")
    with ZipFile(ARCHIVE) as z:
        bad = z.testzip()
        if bad:
            sys.exit("AETHERFALL_NATURE_FAIL: Archive CRC error: " + bad)
        names = set(z.namelist())
        required = {"models/nature/" + name + ".glb" for name in EXPECTED}
        required |= {"nature-manifest.json", "LICENSE-Quaternius-Nature.txt"}
        if not required <= names:
            sys.exit("AETHERFALL_NATURE_FAIL: Missing models: " + repr(sorted(required - names)))
        manifest = json.loads(z.read("nature-manifest.json"))
        if manifest.get("license") != "CC0 1.0":
            sys.exit("AETHERFALL_NATURE_FAIL: Unverified archive license")
        metadata = {entry["asset"]: entry for entry in manifest.get("assets", [])}
        if not EXPECTED <= metadata.keys():
            sys.exit("AETHERFALL_NATURE_FAIL: Missing checksums")
        for name in EXPECTED:
            member = "models/nature/" + name + ".glb"
            info = z.getinfo(member)
            if not 500 < info.file_size < 4_000_000:
                sys.exit("AETHERFALL_NATURE_FAIL: Unexpected model size: " + member)
            blob = z.read(member)
            if blob[:4] != b"glTF" or int.from_bytes(blob[8:12], "little") != len(blob):
                sys.exit("AETHERFALL_NATURE_FAIL: Invalid GLB: " + member)
            if hashlib.sha256(blob).hexdigest() != metadata[name]["sha256"]:
                sys.exit("AETHERFALL_NATURE_FAIL: Digest mismatch: " + member)
            dst = DEST / member
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(blob)
    print(f"AETHERFALL_NATURE_MODELS_OK: {len(EXPECTED)} verified CC0 optimized GLBs")

if __name__ == "__main__":
    main()
