# Aetherfall Starter Town — Approved Environment Roadmap

## Build permission

**Do not create, export, queue, or upload an Android APK unless the user explicitly asks for an APK.** Finishing a pass or source commit is not permission to build. Use commits marked `[skip ci]` when staging changes on branches whose GitHub Actions workflows otherwise export an APK. No automatic phone builds for this work-in-progress. Work is on `feature/starter-town-pass2-roads`, which is intentionally excluded from push-triggered Android export; commit messages also use `[skip ci]`.

## Pass 1 — Marketplace and lawn (source changes staged)

- Exactly four copies of the preferred Quaternius `MarketStand_1` backed/striped-awning stall, arranged at the four diagonal marketplace corners with open customer sides facing inward toward the central walking circuit.
- Keep two appropriately sized rustic oak benches on the main square. Remove the two extra benches toward the front gate/edge of the grass.
- Fix the disproportionate front/gate-side cottage doors: avoid stretching the one-storey `House_4` model vertically to fill the height of a multi-storey building.
- Dense, **short lawn-style** grass throughout lawn regions. Use efficient instanced chunks, with grass excluded from paving, road shoulders and solid obstacles.
- No player character, joystick, sprint, collision or market-circulation regressions.

## Pass 2 — Road and cobblestone redesign (source changes staged)

- Investigated Quaternius Medieval Village MegaKit (300+ modular pieces, including floors). The 20 optimized Quaternius GLBs already in the project do not include street/road tiles. Filling the streets with hundreds of decorative modular 3D stones would add unnecessary draw calls and collision complexity for Android.
- Selected Poly Haven [Cobblestone Floor 001](https://polyhaven.com/a/cobblestone_floor_001) (CC0; uneven worn medieval stones, dirt and moss in gaps) rather than the original rectangular [Cobblestone Pavement](https://polyhaven.com/a/cobblestone_pavement). Existing texture pipeline downloads the 1K diffuse and packs it as `textures/cobble.bin` when a build is explicitly requested.
- Removed the three stacked EntryRoad/CrossRoad/MarketSquare BoxMesh slabs. `cleanroom/road_network.gd` unions all connected paving regions into one world-UV-mapped medieval cobblestone mesh with a narrow continuous dirt verge.
- Roads include a gate-to-square boulevard, east-west cross street, central market, and short entry paths/doorstep landings for each of ten shop/residence entrances. Routes across the front of buildings avoid crossing through house cores.
- Foot grounding and grass exclusion query the same road rectangles, maintaining matching ground heights and leaving a continuous lawn outside the paved footprint.
- Materials and geometry are optimized for Godot GL Compatibility using a row-merged mesh (rather than hundreds of independent meshes).
- Source edits and regression assertions exist, but full Godot runtime and phone screenshots are **not yet verified**. No APK has been generated.


## Pass 3 — Mountain valley, timber wall and closed gate (source changes staged)

- Replaces flat stone rectangle with three low-poly, irregular ridgelines along the north/back, west and east. Cliffs rise beyond the already-playable bounds, avoiding the need to create an exterior world.
- Replaces old stone wall facade and individual buttress decorations with continuous opaque timber palisades. Logs and sharpened tips use **two MultiMesh batches**, retaining simple narrow rectangular collision boundaries and aligned camera blockers. Supports/crossbeams make the interior appear engineered rather than a featureless wooden fence.
- Keeps gatehouse watch towers at the proven 2.3 m gameplay collision radius, but visually integrates them with timber walls and wooden gatehouse.
- Removes the see-through portcullis. Two **fully solid oak gate leaves** overlap the tower opening, with dark wood plank seams, iron straps, hinges and a heavy overhead timber lintel. Gate is NEVER openable.
- Adds `zone_transfer.gd` as a reusable scene-transition controller with a loading overlay and retained character/inventory/equipment/progress dictionary.
- Walking into the approach zone at the main gate (narrow central corridor and front of the closed doors) registers the named destination `res://areas/valley_outskirts.tscn`. When that scene becomes available, transition occurs with loading progress while the previous scene is unloaded. When not yet authored, show a short **nonmodal** notice rather than falsely opening the gate or loading an empty map.
- This is the **foundation** for Iruna Online-like discrete zones. The next area's exterior terrain and reverse-transfer arrival point are a separate future task, not fabricated as part of Pass 3.
- **No APK** or Android export has been requested or created. Godot runtime and phone visual QA remain outstanding.

## Passes 4–9

4. Medieval town decoration, wagons, props, flowerbeds and signs.
5. Lighting, shadows, atmosphere and day/night foundation.
6. NPC residents, merchants, guards, patrols and idle behavior.
7. Interactive shops, guild, inn and separately loaded interiors.
8. Ambient audio, footsteps, music and location soundscapes.
9. Mobile performance, collision audit and town polish.

## Validation

Static source and asset checks may be done at any time. Godot runtime checks or other automated builds can be arranged without exporting an APK only if their workflow cannot generate an APK. On-device visual review happens **only** after the user requests a new APK.
