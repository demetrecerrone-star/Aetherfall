# Aetherfall World Builder - organic districts prototype 0.2

This tool implements the approved **procedurally generated, then permanently saved** town.
It does not run during gameplay and does **not** alter the game's title/login startup scene.

## Working branch
world-builder-prototype (isolated from unity-reboot while Unity Cloud APK debugging continues).

## Generate, save, and see the real 3D town
The `Assets/Editor/AetherfallTownPreviewCapture.cs` editor script now creates
five **real Unity camera screenshots**: overhead, entrance market, winding
residential road, guild-run hilltop town hall, and the overlook back toward the
market. This code has source checks but **has not yet executed in Unity**.

### Via the Unity Editor (recommended first verification)
1. Open `Aetherfall-Unity` in **Unity 6000.3.26f1**.
2. Select **Aetherfall > World Builder > Generate Town + Capture Screenshots**.
3. The editor saves `Assets/Scenes/StarterTown.unity`, the mesh in
   `Assets/WorldBuilder/Generated/` and materials in
   `Assets/WorldBuilder/Materials/`.
4. Open `Aetherfall-Unity/Builds/StarterTownPreview/` for five 1600 x 900 PNGs.
5. Review screenshots, tune the town and regenerate before accepting the
   generated scene into the game's main branch.

### Via a properly licensed Unity Editor runner
Run from a shell that has a **graphics-capable Unity Editor session**:
```bash
/path/to/Unity -batchmode -quit \
  -projectPath "/path/to/Aetherfall-Unity" \
  -executeMethod Aetherfall.Editor.AetherfallTownPreviewCapture.GenerateAndCapture \
  -logFile "/path/to/town-preview.log"
```
**Do not use `-nographics`**; that disables the graphics device needed for
`Camera.Render()`. A headless VM may require a configured display/GPU or
software renderer. The project does not yet have a provisioned CI runner with
graphics and Unity activation. Do not claim screenshots exist just because
source checks passed. After the runner is available, an artifact-upload job
can collect `Aetherfall-Unity/Builds/StarterTownPreview/*.png` and publish
them for review from a phone.

### Preserve the currently building Android APK
Town generation is confined to the `world-builder-prototype` branch. It does
not change `EditorBuildSettings`, the opening video, the title/login
scene, or the currently configured `unity-reboot` Android build target.
Do not add the prototype scene to the Android build until the scene compiles,
renders and receives visual approval.

## Organic starter town plan
- Nominal 250 x 240 m town footprint, with an irregular perimeter of 16 angled wall sections rather than rectangular walls.
- 18 m south gate enters a lively market neighborhood: fountain plaza, market stalls, supply shop, bakery, blacksmith, apothecary, and inn.
- A winding street leaves the market ring and travels past cottage plots to a **separate guild quarter** in the north: guild hall, training yard, and shrine.
- The guild functions as the starter town's administrative town hall, not merely a quest office: registration, public orders, contracts and town-guard leadership are centralized there. It has a blockout porch, gold charter crest and blue civic banners.
- A gentle, walkable **6 m northern hill** lifts the guild hall above the market so it can overlook the town. Roads follow the slope; the scene saves the collidable terrain mesh as a Unity asset.
- A second residential lane loops around houses and connects back to the guild approach; short footpaths lead to services.
- 8 residential plots, woodland beyond the irregular walls and waist-high shrubs. Housing blockouts now include simple timber framing, shutters and roof ridge caps.
- Four non-solid named navigation anchors: player gate spawn, market interaction, guild registration and field exit.
- Default reproducible seed 77421, daytime directional light, elevated preview camera.
- Empty scene anchors mark the entrance spawn, market, guild registration and outside-field exit.
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
