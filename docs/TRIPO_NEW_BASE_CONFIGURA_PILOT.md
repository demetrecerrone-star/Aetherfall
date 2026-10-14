# Aetherfall | New Tripo character candidates — Configura pilot

**Scope:** The two user-uploaded bald and untextured GLBs (Oct 14, 2026).
**Status:** Importable/rigged prototype. Not a fully customizable or animated playable character yet.
**Safety:** No bone names, transforms, weights, vertex data, meshes, or original assets have been altered.

## Inputs / fingerprints

| Candidate | Original filename | SHA-256 | Skeleton | Mesh objects |
|---|---|---|---|---|
| Male | `male-muscular.glb` | `da52c6f06a4f790ec7b61388f6c606419c68d2225abc77dfa45067fdd22ed649` | 65 `mixamorig:` joints | 65 |
| Female | `female-curvy.glb` | `4b09dcb61d65b9f3d12eee5673b2c7153fe5acdf2e61c2c3847fa9130cbe9eca` | 65 `mixamorig:` joints | 63 |

Both have **40 finger joints**, four joint influences per vertex, normal+position data,
**no textures/materials, no morph targets, no animation clips**, and matching
ordered bone names. This is structural compatibility, not proof that
animations/garments will fit or deform correctly. Mesh count does not imply
swappable hairstyles/eyes/clothing.

## Staging the original GLBs (locally)

The repository is PUBLIC, so **user-uploaded candidate binaries are excluded via
`.gitignore`**. The source GLBs live in the local review ZIP delivered to the owner.
Do not publish the original files without reviewing the artist's distribution rights.

1. Obtain the user-provided `male-muscular.glb` and `female-curvy.glb`.
2. In this branch, run:

   ```bash
   python3 tools/stage_tripo_configura_candidates.py --male /path/male-muscular.glb --female /path/female-curvy.glb
   ```

3. Two *byte-identical* runtime copies are staged under
   `assets/characters/configura_candidates/male_runtime.bin` and `female_runtime.bin`.
   Hash verification is mandatory and prevents accidental model replacement.
4. Install the pinned Configura addon:

   ```bash
   git submodule update --init third_party/configura
   python3 tools/install_configura_experiment.py
   ```

5. Open `scenes/configura_candidate_studio.tscn` in Godot 4.6.
   This standalone test scene offers model switching and a **whole-model tint**
   only, plus `CharacterState` save/load. This is not yet the fully generated
   Configura character creator interface. No APK is built by these steps.

## Current limitations / next acceptance gates

- New body mesh parts must be meaningfully separated for *hair* and *eye iris*
  options, rather than changing the color of every mesh at once.
- Determine fit to existing peasant clothes without erasing the approved
  male/female silhouettes.
- Transfer/retarget existing 65-bone animations and exercise every finger
  gripping weapon handles and stance transitions. Do not automatically copy
  animations just because joint names match: bind/rest transforms can differ.
- Show actual in-engine front, side, rear screenshots, then the character creator
  save/load with hair and eye-color options.
- Test Android camera, touch inputs, UI safe areas, locomotion, garment and
  sword grip before creating or shipping any APK.

Existing `main`, protected Starter Town baseline, and installed Android APK
remain untouched.
