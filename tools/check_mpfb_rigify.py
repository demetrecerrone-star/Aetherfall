"""Verify MPFB and Rigify load inside Blender before changing the playable avatar.

This stage does not substitute the existing 17-bone Godot game skeleton;
a future retarget/bake step is required for MPFB/Rigify characters.
"""
import bpy
import addon_utils
import importlib
import json
from pathlib import Path

assert bpy.app.version >= (4,2,0), f"MPFB requires Blender 4.2+, got {bpy.app.version_string}"
addons = {}
for label, module_name in (
    ("MPFB", "bl_ext.blender_org.mpfb"),
    ("Rigify", "bl_ext.blender_org.rigify"),
):
    try:
        package = importlib.import_module(module_name)
        addon_utils.enable(module_name, default_set=True)
        enabled = module_name in bpy.context.preferences.addons
        assert enabled, f"{label} installed but not enabled"
        addons[label] = {
            "module": module_name,
            "enabled": enabled,
            "file": str(getattr(package, "__file__", "")),
        }
        print("AETHERFALL_ADDON_READY:", label, module_name)
    except Exception as exc:
        raise RuntimeError(f"{label} unavailable; install Blender extension then retry: {exc}") from exc

# Preserve existing game rig. Audit the Blender modeling source separately.
source = Path("tools/blender_character_pipeline.py")
assert source.exists()
out = Path("builds/aetherfall_addons_verified.json")
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps({"blender":bpy.app.version_string,"addons":addons,"game_rig_untouched":True},indent=2))
print("AETHERFALL_MPFB_RIGIFY_OK")
