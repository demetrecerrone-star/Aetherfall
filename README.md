# Aetherfall

**Aetherfall** is an original Android-first anime-style 3D RPG, designed for shared online zones and solo-friendly quests/dungeons. It is not an Iruna Online clone: all generated art and code here are original.

## Current milestone — v0.2 Character Lab

This is a **local/offline foundation prototype**, not yet an MMO. On a successful Android build, the game provides:

- Procedural **Skeleton3D** humanoid prototype with reusable named bones, attached outfit geometry and smooth, bone-driven idle / walk / run / jump / wave states.
- In-world **LOOKS** studio with two body frames, six skin tones, four hairstyles, six hair shades, five eye shades, three outfit types and six outfit palettes.
- Appearance saved locally to `user://aetherfall_appearance_v02.json` and loaded when reopened.
- Third-person camera, mobile joystick, sprint/jump/recenter and small collision-enabled outdoor test village.
- Unique Android package identifier `com.demetrecerrone.aetherfall`; version code **2**.
- GitHub Actions builds the arm64 **APK** from the Godot 4.6.3 project. CI smoke tests the scene to detect parse/runtime errors.

### Artwork status

The v0.2 avatar is a **procedural, skeleton-driven prototype**, not a finished artist-designed or imported skinned anime character. It is deliberately modular so high-quality licensed/original rigged GLB art can replace it later without rewriting controls or the save format.

### Running locally

Open `project.godot` in Godot 4.6.3, press F5. Desktop controls: WASD/arrows, Space for jump, Shift to run, right-drag for camera and R to recenter. Android controls: left joystick, right-side camera swipe, RUN, JUMP, CENTER, HAIR/OUTFIT buttons and **✦ LOOKS** for full appearance.

The android source APK is available as an artifact of a **successful** [Android debug workflow](https://github.com/demetrecerrone-star/Aetherfall/actions/workflows/android-debug.yml).

## IMPORTANT — signing and updates

GitHub Actions uses a temporary debug signing key **unless** the repository contains all three Actions secrets:
`AETHERFALL_KEYSTORE_B64`, `AETHERFALL_KEY_ALIAS`, and `AETHERFALL_KEY_PASSWORD`.

Without stable secrets, signing certificates change each build, so a new APK may require uninstalling the old one first. `version/code=2` **alone does not make an APK updatable**. Do not store keys/passwords in the public repository or upload signing credentials to chat.

For production, generate an upload keystore **and keep an offline backup**, then add its base64 (single line), alias and password as GitHub Actions secrets. Use that same key on *every future build*. See `docs/SIGNING.md`. Since the initial v0.1 build used an ephemeral key, switching to a new stable key will require a **one-time reinstall** from v0.1.

## Roadmap

- **v0.1** Android prototype: environment, movement, touch controls (compiled; phone behavior not independently verified).
- **v0.2** Skeleton-driven character lab and appearance persistence (**in progress / build-test**).
- **v0.3** Target selection, enemy AI, attack animations, damage/hit feedback.
- **v0.4** Inventory, starter weapons, XP progression, equipment preview.
- **v0.5** NPCs, first quests, starting village expansion.
- **v0.6+** Authenticated online world, server-authoritative state, parties, chat, persistent characters.

No networking, player accounts, multiplayer, combat, commerce or MMO backend is claimed to be implemented in v0.2.
