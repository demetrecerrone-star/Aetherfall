# Aetherfall CC0 Scenery Integration (Android)

This folder holds optimized, self-contained Quaternius GLB scene models.
The original 20-model bundle was prepared from user-provided CC0 packs.

All replacements run inside the existing `cleanroom/starter_town.tscn` APK.
The character rig, joystick, camera, and gameplay collision are unchanged.
`res://scenery_replacements.gd` uses each GLB's actual mesh bounds to
fit the original house/stall/prop area, hides the old visible primitive meshes,
and retains the original blockers and regressions. When a requested GLB has
not yet been imported, the original appearance is retained automatically.

Planned GLB names (20): House_1–4, Inn, Blacksmith, MarketStand_1–2,
Stall_Empty, Barrel, Crate_Wooden, FarmCrate_Apple, Anvil, Lantern_Wall,
BirchTree_1, MapleTree_1, Bush, Bush_Large, Bush_Flowers, Grass_Small.

The glTF assets must be present under `cleanroom/models/scenery/`.
Do not copy the entire large source packs into the mobile APK; only the
selected optimized GLBs. Preserve the original packs' CC0 license files.

Source: Quaternius Medieval Village Pack (2020), Medieval Village MegaKit,
Fantasy Props MegaKit, and the supplied glTF vegetation collection.
Each pack's included license should be retained alongside its archive.
No player-character replacement is intended in this pass.

## Pass 3 merchandise-display fix
The source `MarketStand_1.glb` includes a raised display shelf above its own
lower wooden desk. `starter_town.gd` now lowers exactly 192 imported wood
vertices by 0.245427 source-model units, flush with the desk, at runtime.
The roof/canopy, frame, legs, and original collision volumes remain untouched.
This remains effective when the original 20-model archive is unpacked in CI.
The scenery asset regression checks the shelf geometry on each signed APK build.
