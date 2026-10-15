# Aetherfall — Isolated Unity Cloud Android Town Preview

**Purpose:** generate Aetherfall's actual 3D StarterTown scene in the Unity
Editor used by Unity Build Automation and ship it as a separate Android APK.
This is a fast, phone-first visual testing path, independent of the main
landscape-locked title/login build.

## 1. Make a NEW Build Automation configuration (do NOT edit aetherfall-android)

In the same Unity Cloud organization/project:
- Name: `aetherfall-town-preview`
- Platform: Android, output: APK (development/testing)
- Unity Editor: `6000.3.26f1`
- GitHub repository: `demetrecerrone-star/Aetherfall`
- Git branch: **`world-builder-prototype`**
- Project subfolder: **`Aetherfall-Unity`**
- New build (latest branch commit), not Replay of an earlier revision.
- Under **Advanced Settings → Script hooks → Pre-Export Method**, enter:
  `Aetherfall.Editor.AetherfallTownPreviewBuild.PreExport`
- Under **Advanced Settings → Scenes**, **do not override the scene list**
  with the title/login scene. The pre-export method selects the generated
  `Assets/Scenes/StarterTown.unity` in the Unity Editor.
- Signing: use the development/test signing available in the config. This
  preview has its own Android application ID and does not overwrite the
  existing Aetherfall app.

Check the Unity configuration before building. Do not replace
`aetherfall-android` or switch its Git source branch.

## 2. What Pre-Export does

Once the Unity Editor compiles our source files, Unity Build Automation calls
`Aetherfall.Editor.AetherfallTownPreviewBuild.PreExport`.

It:
1. Reads `Assets/WorldBuilder/starter-town.json`.
2. Runs the deterministic `AetherfallWorldBuilder.GenerateStarterTown()`
   Editor method.
3. Generates `Assets/Scenes/StarterTown.unity`, terrain mesh/material assets,
   roads, walls, houses, forests, guild civic notices and 4 navigation markers.
4. Sets the selected build scene to StarterTown, distinct from login.
5. Sets the unique APK package ID
   `com.demetrecerrone.aetherfall.townpreview`.
6. Locks the Android preview to landscape-left.

**Caveat:** We have added this pre-export source path, but it has **not yet
been tested by a real Unity Cloud build**. Build Automation scene overrides,
hook ordering, shader import or Unity API compilation may require iteration.
Read the Unity build logs before saying the preview is playable.

## 3. What the phone preview shows

The APK loads the actual built Unity town. A simple onscreen tour cycles
between five camera viewpoints:
1. Overhead map
2. South gate and market
3. Residential winding road
4. Guild-run hilltop town hall
5. Overlook down toward the marketplace

Use **PREV**/**NEXT** to change views and swipe in a perspective view to
rotate the camera around the target. The preview intentionally runs at a
conservative 30 FPS while we evaluate mobile performance.

The tour is a **3D layout review**, not a character-control, quest, or
multiplayer build. Take regular Android screenshots while viewing each
perspective and send them in ChatGPT for feedback. The separate
`AetherfallTownPreviewCapture.cs` editor capture tool can still produce
five 1600x900 PNGs on a graphics-enabled desktop/runner.

## 4. Current implementation status

- [x] Editor procedural town generator source (not Unity runtime verified)
- [x] Five-view Unity Editor screenshot capture source (not executed)
- [x] Unity Cloud pre-export source for a separate preview target (not executed)
- [x] Lightweight Android camera tour source (not device tested)
- [x] Source validation workflow
- [ ] Create second **Unity Cloud Build Automation configuration** above
- [ ] Run build and inspect compilation/hooks
- [ ] Install town preview APK on Android phone, review real screenshots
- [ ] Adjust road widths, guild hill, collision, camera and assets from feedback
- [ ] Promote verified town to main Android game's scene-loading pipeline

## Build troubleshooting

- **Build still shows login:** The pre-export hook wasn't selected, the
  wrong source branch was built, or Build Automation has a Scenes override.
  Look in logs for `AETHERFALL TOWN PREVIEW READY`.
- **Generated scene not found:** Check Editor script compilation, project
  subfolder and `Assets/WorldBuilder/starter-town.json`.
- **Pink materials:** Verify render pipeline/shader support. The generator
  currently prefers URP/Lit with Standard fallback.
- **Blank scene:** Confirm the generated scene was included in the APK and
  that the camera/controller received the StarterTown scene.
- **APK collision with current app:** Verify the new package ID in build logs.
- **No screenshot ZIP from cloud:** Expected. This path creates a phone-viewable
  3D APK. The editor PNG exporter still needs a graphical Unity session.

## Safety and separation

The main branch `unity-reboot` and its `aetherfall-android` build target
must remain untouched until the town preview passes visual and Android QA.
The pre-export hook intentionally modifies BuildSettings only inside the
isolated preview build's temporary Unity checkout.
