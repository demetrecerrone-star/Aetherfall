# Aetherfall — Unity Reboot, Stage 1 (Title + Login)

**A fresh Unity project, separate from the original Godot Aetherfall.**

This is an **interactive, image-backed 2.5D front-end prototype** based on the approved low-poly-inspired Aetherfall designs. It is *not yet* a real-time 3D castle, and the two uploaded GLB models are parked in `Documentation/` for a later 3D character stage rather than falsely presenting the illustrated characters as imported Unity meshes.

## What's implemented

- Landscape **Tap to Begin** title screen showing the two adventurers and distant castle.
- Camera-like **push-in transition** that enlarges and pans toward the castle and reveals the gate view; the screens overlap without fading to black.
- Subtle animated light motes and background motion.
- Castle gate **login panel on the right**, drawn with actual Unity UI controls.
- Blank, editable **email and password** input fields. Envelope, lock, and show/hide password icons remain visible.
- Actual **Log In**, **Create Account**, **Google Login**, and **Settings** buttons.
- Android and desktop keyboard/touch support, landscape design, basic safe-area offsets, Android Back / Escape to return to title.
- **No mock authentication:** login and Google account actions show a transparent 'not connected' message. No credentials are stored or transmitted. Real sign-in requires a trusted provider and a proper account backend.

## Open the Unity project

1. Install **Unity 6.3 LTS**, preferably **6000.3.26f1**, with the **Android Build Support** module (Android SDK/NDK and OpenJDK included).
2. Extract this folder, and in **Unity Hub > Add project from disk**, select `Aetherfall-Unity` (the folder containing `Assets`, `Packages`, `ProjectSettings`).
3. Unity will import the `com.unity.ugui` (uGUI) and URP packages. The editor script under `Assets/Editor` automatically creates `Assets/Scenes/AetherfallFrontEnd.unity` and adds it to Build Settings; if necessary, manually choose **Aetherfall > Set Up Title and Login Scene**.
4. Open that scene if not already open and **Play**. Tap/click anywhere on the title scene to approach the castle gate. Click Back/Escape from login to return to title.
5. To make a **development APK**, use **Aetherfall > Build Android Preview APK**. Output: `Builds/Aetherfall-Unity-Login-Preview.apk`. A Unity installation is required; this ZIP by itself is not an installable Android app.

## Build via GitHub Actions (Android phone-friendly)

The recommended route is Unity Build Automation connected to the `unity-reboot` GitHub branch. A GameCI workflow is also included for builders with valid compatible CI licensing; modern Unity Personal licensing does not support legacy manual ALF/ULF activation. See `Documentation/BUILD_APK.md` for phone-only setup. The project ZIP itself is not an APK; no Unity build has been run yet.

## Security / Android note

The preview package ID is `com.demetrecerrone.aetherfall.unitydev` so it **does not collide with the prior Godot installation**. It uses development signing only. For update-safe Android releases, configure a permanent keystore and then set the final package ID before the first public release. Never commit keystores, service keys, passwords, Firebase files or OAuth secrets.

**Google Login is a UI placeholder, not OAuth or Google Play Games integration.** Google Authentication/Play Games requires provider registration, OAuth configuration, app signing certificate SHA-1/SHA-256, client IDs, and a properly configured SDK. We will connect it after the visual frontend is approved.

## Roadmap after visual signoff

- Separate authored **3D castle environment** with camera moves, low-poly architecture and layered geometry, replacing the two image backdrops.
- Import and prepare the supplied `male.glb` and `female.glb` (located in `Documentation` until the glTF importer and rigs are ready); decide on humanoid rig and true gameplay appearance.
- Integrate **UMA 2** for the character creator after verifying its Unity 6.3 compatibility with the chosen base meshes.
- Secure account registration and Google sign-in; character selection; then starter town and MMO systems.

## Sources and ownership

Backgrounds are from the Aetherfall design concepts approved in this conversation. They serve as visual targets, not a claim about live game graphics. The UI frame and icon textures are newly generated project assets. No external proprietary asset packs are bundled.

## Known limitations

- Unity Editor and Android APK export **have not been run** in this environment (Unity Editor is unavailable here). Code structure and asset contract were checked outside Unity; validation in the Unity Editor is still required.
- Motion is **parallax-style 2.5D**, not a 3D camera traveling through actual castle geometry yet.
- Account buttons deliberately do not claim to authenticate users. The next milestone adds a secure account backend.
- URP is installed, but a production URP renderer/pipeline configuration will be set up alongside the first actual 3D scene.
