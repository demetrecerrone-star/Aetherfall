# Aetherfall World Builder - prototype 0.1

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

## First blockout
- 220 x 190 m town inside a walled frontier settlement.
- 18 m southern gateway, defensive towers, central paved fountain square.
- Guild, inn, blacksmith, general shop, healing shrine, bakery, apothecary, market, training yard.
- 8 residential plot slots, outer woodland and waist-high shrubs.
- Default reproducible seed 77421, daytime directional light, elevated preview camera.
- Collision only on solid geometry; decorative leaves, bushes, water and paths do not block players.
- Editable materials saved under Assets/WorldBuilder/Materials.
- No expensive realtime point lights or runtime mesh regeneration.

## Not yet implemented
This is a blockout generator, not finished anime architecture, NPC behavior, combat,
player controls, collision QA, or an Android-tested scene. The fountain water is a
placeholder. Pitched roofs use primitives. Building interiors are not present.
Furniture and props should use separately licensed modular assets later.

## Validation
Use Python standard library to run
  python3 Assets/WorldBuilder/tests/test_town_preset.py
Then generate in Unity Editor and review a screenshot before integrating.
