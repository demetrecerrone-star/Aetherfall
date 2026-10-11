#!/usr/bin/env python3
"""Install verified CC0 Quaternius assets without a manual GitHub upload.

Prefer the user's prepared, SHA-256-manifested optimized archive if it has
been checked into the repo. Otherwise obtain the creator's original Standard
pack from their public OpenGameArt mirror and repack just 16 glTF models as
small standalone GLBs with 512px embedded textures.
"""
from pathlib import Path
from zipfile import ZipFile
from urllib.request import Request, urlopen
from PIL import Image
import hashlib
import io
import json
import shutil
import struct
import sys
import tempfile
import time

ARCHIVE = Path("Aetherfall-Nature-Assets-For-GitHub.zip")
DEST = Path("cleanroom/models/nature")
SOURCE_URL = "https://opengameart.org/sites/default/files/stylized_nature_megakitstandard.zip"
EXPECTED = {
    "Bush_Common", "Bush_Common_Flowers", "Pine_1", "Pine_2", "Pine_3",
    "Pine_4", "Pine_5", "CommonTree_1", "CommonTree_2", "CommonTree_3",
    "Grass_Common_Short", "Grass_Wispy_Short", "Fern_1", "Clover_1",
    "Flower_3_Group", "Flower_4_Group",
}


def check_glb(content: bytes, name: str) -> None:
    if (len(content) < 1000 or content[:4] != b"glTF"
            or struct.unpack_from("<I", content, 8)[0] != len(content)):
        sys.exit("AETHERFALL_NATURE_FAIL: Invalid GLB: " + name)


def load_prepared_archive() -> None:
    if ARCHIVE.stat().st_size > 15_000_000:
        sys.exit("AETHERFALL_NATURE_FAIL: Unexpectedly large prepared archive")
    with ZipFile(ARCHIVE) as z:
        if z.testzip():
            sys.exit("AETHERFALL_NATURE_FAIL: ZIP CRC error")
        required = {"models/nature/" + name + ".glb" for name in EXPECTED}
        required |= {"nature-manifest.json", "LICENSE-Quaternius-Nature.txt"}
        if not required <= set(z.namelist()):
            sys.exit("AETHERFALL_NATURE_FAIL: Missing prepared assets")
        manifest = json.loads(z.read("nature-manifest.json"))
        if manifest.get("license") != "CC0 1.0":
            sys.exit("AETHERFALL_NATURE_FAIL: Prepared license not verified")
        digests = {e["asset"]: e["sha256"] for e in manifest.get("assets", [])}
        DEST.mkdir(parents=True, exist_ok=True)
        for name in sorted(EXPECTED):
            member = "models/nature/" + name + ".glb"
            raw = z.read(member)
            check_glb(raw, name)
            if hashlib.sha256(raw).hexdigest() != digests.get(name):
                sys.exit("AETHERFALL_NATURE_FAIL: SHA256 mismatch: " + name)
            (DEST / (name + ".glb")).write_bytes(raw)


def downloaded_original(destination: Path) -> None:
    print("AETHERFALL_NATURE_DOWNLOAD: Obtaining original creator CC0 Standard pack")
    for attempt in range(3):
        try:
            req = Request(SOURCE_URL, headers={"User-Agent": "AetherfallGodotAssetBuilder/1.0"})
            with urlopen(req, timeout=180) as response, destination.open("wb") as target:
                shutil.copyfileobj(response, target)
            size = destination.stat().st_size
            if not 30_000_000 < size < 145_000_000:
                raise ValueError("Unexpected original archive size: " + str(size))
            with ZipFile(destination) as original:
                if "License_Standard.txt" not in original.namelist():
                    raise ValueError("Missing author's license")
                for name in EXPECTED:
                    if ("glTF/" + name + ".gltf") not in original.namelist():
                        raise ValueError("Missing creator model: " + name)
            print("AETHERFALL_NATURE_SOURCE_OK: %d bytes" % size)
            return
        except Exception as exc:
            print("AETHERFALL_NATURE_DOWNLOAD_RETRY: %r" % exc)
            if attempt == 2:
                raise
            time.sleep(3)


def padded(raw: bytes, pad: bytes = b"\x00") -> bytes:
    return raw + pad * ((-len(raw)) % 4)


def model_to_glb(z: ZipFile, name: str) -> bytes:
    model = json.loads(z.read("glTF/" + name + ".gltf"))
    buffers = model.get("buffers", [])
    if len(buffers) != 1:
        raise ValueError("Unsupported glTF buffers for " + name)
    binary_name = buffers[0]["uri"]
    if binary_name != name + ".bin":
        raise ValueError("Unsafe/unexpected binary input for " + name)
    content = bytearray(padded(z.read("glTF/" + binary_name)))
    for image in model.get("images", []):
        if "uri" not in image:
            continue
        fname = image.pop("uri")
        if not fname.endswith(".png") or "/" in fname or ".." in fname:
            raise ValueError("Unsafe image reference: " + fname)
        art = Image.open(io.BytesIO(z.read("glTF/" + fname))).convert("RGBA")
        if max(art.size) > 512:
            art.thumbnail((512, 512), Image.Resampling.LANCZOS)
        pic = io.BytesIO()
        art.save(pic, format="PNG", optimize=True)
        png = pic.getvalue()
        index = len(model.setdefault("bufferViews", []))
        model["bufferViews"].append({
            "buffer": 0, "byteOffset": len(content), "byteLength": len(png)
        })
        content.extend(padded(png))
        image["bufferView"] = index
        image["mimeType"] = "image/png"
    buffers[0] = {"byteLength": len(content)}
    json_blob = padded(json.dumps(model, separators=(",", ":"), ensure_ascii=False)
                       .encode("utf8"), b" ")
    bin_blob = padded(bytes(content))
    size = 12 + 8 + len(json_blob) + 8 + len(bin_blob)
    return (struct.pack("<4sII", b"glTF", 2, size)
            + struct.pack("<I4s", len(json_blob), b"JSON") + json_blob
            + struct.pack("<I4s", len(bin_blob), b"BIN\x00") + bin_blob)


def prepare_from_original(original_path: Path) -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    with ZipFile(original_path) as original:
        if original.testzip():
            sys.exit("AETHERFALL_NATURE_FAIL: Original ZIP CRC error")
        for name in sorted(EXPECTED):
            packed = model_to_glb(original, name)
            check_glb(packed, name)
            if len(packed) > 4_000_000:
                sys.exit("AETHERFALL_NATURE_FAIL: Oversize converted GLB " + name)
            (DEST / (name + ".glb")).write_bytes(packed)
    print("AETHERFALL_NATURE_SOURCE: official Quaternius CC0 Standard archive")


def main() -> None:
    if ARCHIVE.is_file():
        load_prepared_archive()
        print("AETHERFALL_NATURE_SOURCE: user-prepared optimized ZIP")
    else:
        with tempfile.TemporaryDirectory(prefix="aetherfall-nature-") as tempdir:
            original_path = Path(tempdir) / "nature-standard.zip"
            downloaded_original(original_path)
            prepare_from_original(original_path)
    count = len(list(DEST.glob("*.glb")))
    if count != len(EXPECTED):
        sys.exit("AETHERFALL_NATURE_FAIL: Bad final model count")
    total_bytes = sum(path.stat().st_size for path in DEST.glob("*.glb"))
    print("AETHERFALL_NATURE_MODELS_OK: %d validated CC0 GLBs, %d bytes" %
          (count, total_bytes))


if __name__ == "__main__":
    main()
