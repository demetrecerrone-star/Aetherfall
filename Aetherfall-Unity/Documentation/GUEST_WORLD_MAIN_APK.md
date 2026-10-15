# Aetherfall: Guest World in Main Android APK

## Intended user experience

The original main Android application opens with the Aetherfall title,
cinematic, and login panel. Choose **Play as Guest** to enter the actual
baked 3D StarterTown scene without entering credentials or registering.

The initial guest player is a **temporary stylized blockout avatar**, not
the approved final anime player model. This is a local exploration milestone:
no network login, persistent characters, quests or multiplayer yet.

**Android controls:** left on-screen joystick to walk; drag right side to look;
tap Sprint to toggle walk/sprint; Exit returns to the title/login scene.
The main game remains landscape-locked and retains the same Android package ID.

## Build / integration

- Source branch: **unity-reboot**
- Project Subdirectory: **Aetherfall-Unity**
- Android build target: **aetherfall-android**
- Unity Editor: **6000.3.26f1**
- Scenes required and enforced by editor setup:
  1. Assets/Scenes/AetherfallFrontEnd.unity
  2. Assets/Scenes/StarterTown.unity

The project automatically generates the deterministic town **in the Unity
Editor**, using Assets/Editor/AetherfallWorldBuilder.cs and
Assets/WorldBuilder/starter-town.json. Both scenes are then included in
EditorBuildSettings in the correct order. This avoids relying on the separate
town-preview configuration, which previously shipped only the login UI.

Optional explicit **Build Automation Pre-Export Method** for this main
configuration: \`Aetherfall.Editor.AetherfallMainBuildPreExport.PreExport\`.
This hook prepares the same scenes and is not needed when editor import has
already run its InitializeOnLoad callback.

**Important:** If Build Automation has an explicit scene override pointing
only to AetherfallFrontEnd, disable that override or include BOTH scenes.
The runtime Guest action reports when the town is not packaged, rather than
pretending an account was created. Check log message
\`AETHERFALL_GUEST_WORLD_READY\` during import/prebuild.

## QA steps

1. Verify the Unity Cloud build actually compiles (GitHub source tests alone
   do not compile Unity C# or generate the scene).
2. Install the APK from the aetherfall-android target.
3. Verify orientation on the title screen and login.
4. Tap to begin; tap **Play as Guest** without entering login information.
5. Town must load and show the 3D market, wall/gate, roads and distant guild
   hall; a player avatar appears near the south gate.
6. Use joystick, camera drag, sprint and Exit; confirm no login overlay
   appears on the town.
7. Take real Android screenshots and inspect world geometry and controls.

**World is not finished art:** buildings, foliage, materials, animation and
player appearance remain subject to real-device reviews. Avoid claiming the
game has functional accounts or multiplayer yet.
