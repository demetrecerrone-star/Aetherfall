# Aetherfall • Stylized Nature MegaKit test branch

**Branch:** `feature/quaternius-nature-megakit-import`

The prior approved Starter Town Pass 3 is unchanged. This branch uses the
user-supplied Quaternius Stylized Nature MegaKit **Standard** (CC0) pack
to replace most procedural hedges and trees and to supply real instanced grass.
The optional medieval weapons and RPG items are **not** included in this pass.

## Fully automatic asset staging — no manual upload needed

The user-supplied 100 MB Quaternius Standard archive was analyzed locally.
The GitHub Actions build obtains the **same freely distributed CC0 Standard pack**
directly from the creator's OpenGameArt mirror, selecting 14 compatible glTF
models and converting them to embedded-texture GLBs with 512px textures.

The optional `Aetherfall-Nature-Assets-For-GitHub.zip` (~6.3 MB) is supported
for offline/import-speed optimization, but it does **not** need to be uploaded
for this branch to build. If it exists, the installer validates its manifest
and SHA-256 hashes instead of downloading the larger source archive.

The installer is `cleanroom/tools/install_nature_megakit.py`, running before
the Godot imports and strict native-asset QA. Missing or broken downloads and
imports fail CI rather than quietly shipping temporary foliage.

## Approved changes

- **Camera:** unchanged — still collides with buildings and towers
- **Roads:** wide gate road and marketplace kept; secondary cross-street
  slightly narrower but passable
- **Bushes:** two overlapping real `Bush_Common` models create subdued,
  roughly 0.95–1.02 m tall elongated hedges; flowering bushes add variety
- **Trees:** textured `Pine_1/2/4/5` and `CommonTree_1/2/3` imports,
  darker solid-cutout foliage, fitted to existing tree collision footprints
- **Grass:** Quaternius `Grass_Common_Short` material/geometry at roughly
  0.19 m, instanced in existing 8 m chunks, absent from roads and paths

Fallbacks are retained for local editing, but the native asset QA is strict
in the CI signed nature-preview build. No character/animation/weapon changes.

**Source/license:** Stylized Nature MegaKit Standard by Quaternius, CC0 1.0.
https://quaternius.com/packs/stylizednaturemegakit.html
