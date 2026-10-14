"""Aetherfall v95: non-destructive clothing mesh diagnostics.

Run after importing the latest approved character into Blender:
    blender -b character.blend --python tools/inspect_clothing_v95.py

Produces a JSON report. Does not change geometry or export over an approved model.
"""
import bpy
import json
from pathlib import Path

OUT = Path("builds/character_v95_clothing_audit.json")
OUT.parent.mkdir(parents=True, exist_ok=True)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
clothes = [o for o in meshes if any(s in o.name.lower() for s in
    ("tunic", "shirt", "sleeve", "belt", "trouser", "outfit", "cloth", "boot"))]
report = {"source": bpy.data.filepath, "mesh_count": len(meshes),
          "clothing_mesh_count": len(clothes), "clothing": []}
for obj in clothes:
    armature_modifiers = [m for m in obj.modifiers if m.type == "ARMATURE"]
    groups = {g.name for g in obj.vertex_groups}
    report["clothing"].append({
        "name": obj.name,
        "vertices": len(obj.data.vertices),
        "armature_modifiers": len(armature_modifiers),
        "armature_targets": [m.object.name if m.object else None for m in armature_modifiers],
        "deform_groups": sorted(groups),
        "bounds_local": [[min(v.co[i] for v in obj.data.vertices),
                          max(v.co[i] for v in obj.data.vertices)]
                         for i in range(3)] if obj.data.vertices else [],
    })
OUT.write_text(json.dumps(report, indent=2))
print("AETHERFALL_V95_AUDIT:", OUT, "clothing meshes:", len(clothes))
if not clothes:
    raise RuntimeError("No clothing meshes found; verify the approved model was loaded")
