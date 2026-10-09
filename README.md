# Aetherfall

An **original, Android-first, 3D anime-style, solo-friendly online RPG** built with Godot 4. The project is inspired by the *mechanical feel* of classic mobile MMORPGs but does not use their art or code.

## v0.1: Movement Lab

The current milestone is an **offline controller prototype**: a third-person 3D character, camera-relative movement, touch joystick, right-side camera orbit, jump/sprint, avatar palette variations, and a stylized test village. It is **not** an APK, and multiplayer, accounts, combat, or persistent progression have not yet been implemented.

- Open `project.godot` in Godot 4.6 or newer, then press F5.
- Desktop: WASD / arrows, Space (jump), Shift (sprint), right-drag mouse (orbit), R (camera center).
- Android: left virtual stick, right-side swipe to orbit, JUMP, RUN, CENTER, HAIR, OUTFIT.
- See `docs/TEST_PLAN.md` for validation. Android export requires configured Android SDK and Godot export templates.

## Roadmap

1. Verify movement/camera on Android hardware.
2. Replace procedural avatar with an original rigged 3D anime character and animation tree.
3. Add NPC interaction and an enemy combat prototype.
4. Introduce a server-authoritative online shared-zone backend.
5. Expand into quests, equipment, levels, crafting, parties, and solo-friendly dungeons.

The online design will keep character progression, loot, damage, and inventory authoritative on the server. The early movement-lab prototype intentionally runs offline.