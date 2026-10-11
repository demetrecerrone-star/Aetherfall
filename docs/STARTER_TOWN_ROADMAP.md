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


## Pass 3 — Mountain valley, timber wall and closed gate

- Mountains/cliffs along the rear and sides of the village; reinforced timber palisades along accessible boundaries.
- Main solid wooden double gate remains **visually closed at all times**; it does not open.
- On approach, trigger **Iruna Online-style zone loading**: show a dedicated area loading screen and load the separately authored next region. Retain player identity, inventory and progress.
- No need to render an explorable outer world beyond the starter-town boundary.

## Passes 4–9

4. Medieval town decoration, wagons, props, flowerbeds and signs.
5. Lighting, shadows, atmosphere and day/night foundation.
6. NPC residents, merchants, guards, patrols and idle behavior.
7. Interactive shops, guild, inn and separately loaded interiors.
8. Ambient audio, footsteps, music and location soundscapes.
9. Mobile performance, collision audit and town polish.

## Validation

Static source and asset checks may be done at any time. Godot runtime checks or other automated builds can be arranged without exporting an APK only if their workflow cannot generate an APK. On-device visual review happens **only** after the user requests a new APK.
