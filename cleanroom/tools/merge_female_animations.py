#!/usr/bin/env python3
"""Build a female game-ready GLB by copying compatible rig animations by bone name.

No mesh, skin, or material data is copied from the male model. The female geometry,
original idle, look_around and jump are preserved. A GitHub Actions check validates
both models before the new GLB is ever packed into an Android APK.
"""
from __future__ import annotations
import argparse
import copy
import json
import struct
from pathlib import Path

MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942
MISSING = ("standing_relax", "walk", "run", "sit")
EXPECTED = set(MISSING) | {"idle", "look_around", "jump"}


def load_glb(path: Path):
    raw = path.read_bytes()
    assert len(raw) > 32 and raw[:4] == MAGIC, f"{path}: invalid GLB header"
    magic, version, declared = struct.unpack_from("<4sII", raw)
    assert version == 2 and declared == len(raw), f"{path}: invalid GLB v2 length"
    offset = 12
    chunks = {}
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        payload = raw[offset:offset + length]
        assert len(payload) == length, f"{path}: truncated chunk"
        chunks[kind] = payload
        offset += length
    gltf = json.loads(chunks[JSON_CHUNK].rstrip(b" \x00").decode("utf-8"))
    assert len(gltf.get("buffers", [])) == 1, f"{path}: expected one embedded BIN buffer"
    binary = chunks[BIN_CHUNK]
    assert len(binary) >= gltf["buffers"][0]["byteLength"]
    return gltf, binary


def encode_glb(gltf: dict, binary: bytes) -> bytes:
    json_data = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    json_data += b" " * ((-len(json_data)) % 4)
    binary += b"\x00" * ((-len(binary)) % 4)
    length = 12 + 8 + len(json_data) + 8 + len(binary)
    return (
        struct.pack("<4sII", MAGIC, 2, length)
        + struct.pack("<II", len(json_data), JSON_CHUNK)
        + json_data
        + struct.pack("<II", len(binary), BIN_CHUNK)
        + binary
    )


def skin_bone_names(gltf: dict) -> list[str]:
    assert len(gltf.get("skins", [])) >= 1, "Model must have a skinned rig"
    indices = gltf["skins"][0].get("joints", [])
    return [str(gltf["nodes"][n].get("name", "")) for n in indices]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--male", required=True, type=Path)
    parser.add_argument("--female", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    male, male_bin = load_glb(args.male)
    female, female_bin = load_glb(args.female)
    male_joint_names = skin_bone_names(male)
    female_joint_names = skin_bone_names(female)
    assert len(male_joint_names) == len(female_joint_names) == 65
    assert len(set(male_joint_names)) == 65
    assert set(male_joint_names) == set(female_joint_names), "Rig bones do not match"

    # Important: do not assume matching numeric indices across two GLBs.
    male_nodes = {node.get("name"): i for i, node in enumerate(male["nodes"])}
    female_nodes = {node.get("name"): i for i, node in enumerate(female["nodes"])}
    assert len(male_nodes) == len(male["nodes"]), "Duplicate source node names"
    assert len(female_nodes) == len(female["nodes"]), "Duplicate destination node names"

    # Warn about differing bone rest transforms. Identity retargeting works for
    # rigs sharing a conventional Mixamo hierarchy; this is a prototype test.
    max_distance = 0.0
    for name in male_joint_names:
        src, dst = male["nodes"][male_nodes[name]], female["nodes"][female_nodes[name]]
        if "translation" in src and "translation" in dst:
            delta = sum((float(a)-float(b))**2 for a,b in zip(src["translation"],dst["translation"])) ** 0.5
            max_distance = max(max_distance, delta)
    print(f"Rig names identical (65). Largest local translation offset: {max_distance:.5f} m")

    female_clips = {str(a.get("name","")).lower() for a in female.get("animations",[])}
    male_clips = {str(a.get("name","")).lower(): a for a in male.get("animations",[])}
    assert {"idle","look_around","jump"} <= female_clips
    assert set(MISSING) <= set(male_clips)

    female.setdefault("bufferViews", [])
    female.setdefault("accessors", [])
    female.setdefault("animations", [])
    binary = bytearray(female_bin[:female["buffers"][0]["byteLength"]])
    imported = []
    for name in MISSING:
        source_anim = male_clips[name]
        animation = copy.deepcopy(source_anim)
        accessor_map = {}
        view_map = {}

        def transfer_accessor(old_index: int) -> int:
            if old_index in accessor_map:
                return accessor_map[old_index]
            original = male["accessors"][old_index]
            assert "sparse" not in original, "Sparse animation accessor unsupported"
            old_view_index = original["bufferView"]
            if old_view_index not in view_map:
                source_view = male["bufferViews"][old_view_index]
                assert source_view.get("buffer", 0) == 0
                binary.extend(b"\x00" * ((-len(binary)) % 4))
                start = source_view.get("byteOffset", 0)
                length = source_view["byteLength"]
                data = male_bin[start:start + length]
                assert len(data) == length
                new_view = copy.deepcopy(source_view)
                new_view["buffer"] = 0
                new_view["byteOffset"] = len(binary)
                new_view["byteLength"] = length
                view_map[old_view_index] = len(female["bufferViews"])
                female["bufferViews"].append(new_view)
                binary.extend(data)
            new_accessor = copy.deepcopy(original)
            new_accessor["bufferView"] = view_map[old_view_index]
            accessor_map[old_index] = len(female["accessors"])
            female["accessors"].append(new_accessor)
            return accessor_map[old_index]

        for sampler in animation.get("samplers", []):
            sampler["input"] = transfer_accessor(sampler["input"])
            sampler["output"] = transfer_accessor(sampler["output"])

        for channel in animation.get("channels", []):
            target = channel["target"]
            source_node = male["nodes"][target["node"]]
            name_of_node = source_node.get("name")
            assert name_of_node in female_nodes, "No destination node for animation: " + str(name_of_node)
            assert name_of_node in set(male_joint_names), "Animation attempts to move non-rig node: " + str(name_of_node)
            target["node"] = female_nodes[name_of_node]
        female["animations"].append(animation)
        imported.append(name)

    female["buffers"][0]["byteLength"] = len(binary)
    finished_clips = {str(a.get("name","")).lower() for a in female["animations"]}
    assert EXPECTED <= finished_clips
    assert len(skin_bone_names(female)) == 65
    output = encode_glb(female, bytes(binary))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(output)
    check, _ = load_glb(args.output)
    assert EXPECTED <= {str(a.get("name","")).lower() for a in check["animations"]}
    print(f"Transferred {imported}; female mesh and original 3 animations preserved")
    print(f"OUTPUT {args.output} {len(output)} bytes; all 7 clips present")


if __name__ == "__main__":
    main()
