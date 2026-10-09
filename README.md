# Aetherfall

**Aetherfall** is an original Android-first anime-style 3D RPG, designed for shared online zones and solo-friendly quests/dungeons. It is not an Iruna Online clone: all generated art and code here are original.

## Current milestone — v0.3 Original Rigged Character

v0.3 remains an **offline RPG prototype**. Multiplayer/server systems have not yet been implemented. The character is no longer made from assembled Godot spheres and boxes.

- **Original skinned glTF model:** a genuine 3D mesh asset built using a portable, self-contained Python generator (`tools/generate_avatar.py`). The asset has **92 original skinned meshes**, one **17-bone humanoid armature**, and hand-authored looping **Idle, Walk, Run, Jump, Wave** skeletal animation clips.
- Smooth joined loft geometry for torso, jawline, limbs, face, hair, boots and outfit layers. The generated character is an **independently imported glTF asset** with skeletal skinning, not the old 3D procedural Node3D doll. Artwork is an original stylized prototype and **not yet a professionally sculpted commercial-quality anime model**.
- Four separate hairstyle geometries, three outfit variants, wearable materials and saved customization (frame, skin, eye shade, hair, outfit).
- Equipment sockets included on both hand bones to prepare for weapon attachments. First actual equipment objects are deferred to a later update.
- Existing mobile-friendly third-person camera, controls and right-docked character studio remain intact.
- GitHub CI regenerates the deterministic glTF, checks model import and animation, then exports a **v0.3** ARM64 debug APK.

### Building locally with Godot 4.6.3

Generate the actual mesh asset **before** launching Godot:

```bash
python3 tools/generate_avatar.py
```

The generator needs only standard Python 3 and emits `assets/characters/aetherfall_adventurer.gltf`. Godot automatically imports it as a scene once the project is opened. The CI build also uploads the generated **source model artifact** separately so artists can work with the character outside Godot.

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
