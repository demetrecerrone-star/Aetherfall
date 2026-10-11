# Aetherfall Starter Town — Approved Environment Roadmap

## Build permission

**Do not create, export, queue, or upload an Android APK unless the user explicitly asks for an APK.** Finishing a pass or source commit is not permission to build. Use commits marked `[skip ci]` when staging changes on branches whose GitHub Actions workflows otherwise export an APK. No automatic phone builds for this work-in-progress.

## Pass 1 — Marketplace and lawn (active)

- Exactly four copies of the preferred Quaternius `MarketStand_1` backed/striped-awning stall, arranged at the four diagonal marketplace corners with open customer sides facing inward toward the central walking circuit.
- Keep two appropriately sized rustic oak benches on the main square. Remove the two extra benches toward the front gate/edge of the grass.
- Fix the disproportionate front/gate-side cottage doors: avoid stretching the one-storey `House_4` model vertically to fill the height of a multi-storey building.
- Dense, **short lawn-style** grass throughout lawn regions. Use efficient instanced chunks, with grass excluded from paving, road shoulders and solid obstacles.
- No player character, joystick, sprint, collision or market-circulation regressions.

## Pass 2 — Road and cobblestone redesign

- Replace fragmented paving with a consistent cobblestone surface/material.
- Roads and paths connect all building doors to the main square.
- Improve paving/grass boundaries, intersections and transitions.

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
