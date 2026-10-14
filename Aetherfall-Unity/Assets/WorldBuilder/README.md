# Aetherfall World Builder - organic districts prototype 0.2

This tool implements the approved **procedurally generated, then permanently saved** town.
It does not run during gameplay and does **not** alter the game's title/login startup scene.

## Working branch
world-builder-prototype (isolated from unity-reboot while Unity Cloud APK debugging continues).

## Generate and edit
1. Open Aetherfall-Unity in Unity 6000.3.
2. Modify Assets/WorldBuilder/starter-town.json if desired.
3. Select **Aetherfall > World Builder > Generate Starter Town**.
4. The editor creates Assets/Scenes/StarterTown.unity, a saved, editable 3D scene.
5. Commit the generated scene and Materials folder if accepting this buildout.
6. **Do not add the prototype scene to Android build profiles yet**. First review appearance
   and replace simple geometry with modular assets. All players will use the same saved scene.

## Organic starter town plan
- Nominal 250 x 240 m town footprint, with an irregular perimeter of 16 angled wall sections rather than rectangular walls.
- 18 m south gate enters a lively market neighborhood: fountain plaza, market stalls, supply shop, bakery, blacksmith, apothecary, and inn.
- A winding street leaves the market ring and travels past cottage plots to a **separate guild quarter** in the north: guild hall, training yard, and shrine.
- The guild functions as the starter town's administrative town hall, not merely a quest office: registration, public orders, contracts and town-guard leadership are centralized there.
- A gentle, walkable **6 m northern hill** lifts the guild hall above the market so it can overlook the town. Roads follow the slope; the scene saves the collidable terrain mesh as a Unity asset.
- A second residential lane loops around houses and connects back to the guild approach; short footpaths lead to services.
- 8 residential plots, woodland beyond the irregular walls and waist-high shrubs.
- Default reproducible seed 77421, daytime directional light, elevated preview camera.
- Collision only on solid geometry; decorative leaves, bushes, water and paths do not block players.
- Editable materials saved under Assets/WorldBuilder/Materials.
- No expensive realtime point lights or runtime mesh regeneration.

## Not yet implemented
This is a blockout generator, not finished anime architecture, guild-government gameplay, NPC behavior, combat,
player controls, collision QA, or an Android-tested scene. The fountain water is a
placeholder. Pitched roofs use primitives. Building interiors are not present.
Furniture and props should use separately licensed modular assets later.

## Validation
Use Python standard library to run
  python3 Assets/WorldBuilder/tests/test_town_preset.py
Then generate in Unity Editor and review a screenshot before integrating. Width/depth in the current preset describe the nominal prototype bounds; the 0.2 wall/road points are authored for this footprint, not rescaled on editing those values.
