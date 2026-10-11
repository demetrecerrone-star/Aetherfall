#!/usr/bin/env python3
"""Prepare seven CC0 Poly Haven diffuse maps for Aetherfall Starter Town.

The Poly Haven API is queried only by this GitHub Actions build step. Assets are
resized to 512/1024 px to minimize mobile GPU use, encoded as JPEG, and saved
with .bin extension so Godot preserves their exact bytes inside Android PCKs.
The runtime decodes them with Image.load_jpg_from_buffer; it does NOT require
an internet connection.
"""
from __future__ import annotations

import hashlib
import io
import json
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps

ASSETS = {
    # Mossy/mud-grouted medieval cobbles are more fitting for the valley town
    # than the original clean rectangular urban pavement.
    "cobble": ("cobblestone_floor_001", 1024),
    "grass": ("leafy_grass", 1024),
    "dirt": ("dirt", 512),
    "plaster": ("plastered_wall", 512),
    "wood": ("wood_planks", 512),
    "roof": ("roof_tiles", 512),
    "stone": ("stone_wall", 512),
}
OUTPUT = Path("cleanroom/textures")
USER_AGENT = "AetherfallGameBuild/0.2S (CC0 texture attribution: polyhaven.com)"
HEADERS = {"User-Agent": USER_AGENT, "Accept": "application/json"}
MAX_BYTES = 15 * 1024 * 1024


def get(url: str, content_type: str = "") -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=40) as response:
        blob = response.read(MAX_BYTES + 1)
        if len(blob) > MAX_BYTES:
            raise ValueError(f"Asset exceeds maximum transfer size: {url}")
        if not blob:
            raise ValueError(f"Empty downloaded asset: {url}")
        return blob


def file_record(tree: dict) -> dict:
    # Poly Haven /files/{id} nests maps by type, resolution, and file format.
    layers = [(k, v) for k, v in tree.items() if "diffuse" in k.lower() or k.lower() in ("diff", "albedo", "basecolor")]
    if not layers:
        raise ValueError("No diffuse map in Poly Haven API response: " + str(list(tree)))
    for _, maps in layers:
        for size in ("1k", "2k"):
            variants = maps.get(size, {}) if isinstance(maps, dict) else {}
            if not isinstance(variants, dict):
                continue
            for ext in ("jpg", "jpeg", "png"):
                record = variants.get(ext)
                if isinstance(record, dict) and record.get("url"):
                    return record
    raise ValueError("No supported 1K diffuse JPG/PNG in available file variants")


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {"source": "https://polyhaven.com", "license": "CC0", "assets": {}}
    for group, (asset_id, resolution) in ASSETS.items():
        listing = json.loads(get(f"https://api.polyhaven.com/files/{asset_id}"))
        entry = file_record(listing)
        raw = get(entry["url"])
        if entry.get("md5") and hashlib.md5(raw).hexdigest().lower() != entry["md5"].lower():
            raise ValueError(f"Poly Haven checksum mismatch: {asset_id}")
        with Image.open(io.BytesIO(raw)) as original:
            image = ImageOps.exif_transpose(original).convert("RGB")
            image = image.resize((resolution, resolution), Image.Resampling.LANCZOS)
            buffer = io.BytesIO()
            image.save(buffer, "JPEG", quality=85, subsampling=0, optimize=True)
            payload = buffer.getvalue()
        if payload[:3] != b"\xff\xd8\xff":
            raise ValueError(f"JPEG encoding invalid: {asset_id}")
        target = OUTPUT / f"{group}.bin"
        target.write_bytes(payload)
        manifest["assets"][group] = {
            "asset": asset_id,
            "link": f"https://polyhaven.com/a/{asset_id}",
            "resolution": resolution,
            "source_md5": entry.get("md5"),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "bytes": len(payload),
        }
        print(f"AETHERFALL_TEXTURE_OK: {group} ({asset_id}), {resolution}px, {len(payload)} bytes")
    (OUTPUT / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("AETHERFALL_TEXTURES_READY: all 7 CC0 albedo maps generated")


if __name__ == "__main__":
    main()
