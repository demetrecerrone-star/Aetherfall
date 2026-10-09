# Aetherfall v0.2 Character Lab — test checklist

## CI gate
- [x] Repository initializes with Godot 4.6.3 headlessly once pipeline reports green.
- [x] Runtime smoke test (when green) catches GDScript parse and first-scene setup errors.
- [x] Android arm64 build export is uploaded as an artifact on successful run.

## First launch — Samsung Galaxy S23 FE (or equivalent)
- [ ] Installed in **landscape**.
- [ ] Third-person humanoid rendered with moving face and hair; not flat sprites.
- [ ] Walk, run, jump and camera rotation all work without errors.
- [ ] Main camera pulls in front of blocking houses correctly.
- [ ] Tap **✦ LOOKS** to display character studio overlay.
- [ ] Change **BODY FRAME**, **SKIN**, **HAIRSTYLE**, **HAIR COLOR**, **EYE COLOR**, **OUTFIT TYPE**, **OUTFIT COLOR**; character visibly updates.
- [ ] Close the studio, continue moving; no lost controls.
- [ ] Tap **WAVE** and verify right arm raises for the emote.
- [ ] Tap **ZOOM +** and **ZOOM −** and observe camera distance change with collision safety.
- [ ] Tap HAIR and OUTFIT quick buttons; same appearance settings update.
- [ ] Quit and relaunch the app; choices persist.
- [ ] Check 20:9 and 16:9 layout for touch button overlaps or text clipping.
- [ ] No unusual lag when rotating the camera while running.
- [ ] Collision capsule, floor, house walls and fountain behave normally.

## Update signing
- [ ] Configure GitHub Actions repository signing secrets before expecting update-in-place APKs.
- [ ] Archive keystore securely offline; do not commit it.
- [ ] Confirm identical signer and increased version code between consecutive debug builds.

## Scope boundaries
- No multiplayer, character accounts, server sync, quests, combat or inventory in v0.2.
- Character art is procedurally assembled on a Skeleton3D using bone attachments; it is a functional avatar and animation prototype, not a final sculpted/skinned commercial character mesh.
