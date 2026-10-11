# Aetherfall • Stylized Nature MegaKit test branch

**Branch:** `feature/quaternius-nature-megakit-import`

The prior approved Starter Town Pass 3 is unchanged. This branch uses the
user-supplied Quaternius Stylized Nature MegaKit **Standard** (CC0) pack
to replace most procedural hedges and trees and to supply real instanced grass.
The optional medieval weapons and RPG items are **not** included in this pass.

## One-time asset staging

The selected assets were converted from the user's 100 MB source archive into
`Aetherfall-Nature-Assets-For-GitHub.zip` (~6.3 MB, 14 self-contained GLBs).
Place that archive **at the repository root on this branch**, next to
`Aetherfall-Scenery-Assets-For-GitHub.zip`. Do not extract it manually in GitHub.

GitHub Actions runs `cleanroom/tools/install_nature_megakit.py` to validate
the CC0 manifest and SHA-256 hashes, unpack selected GLBs into
`cleanroom/models/nature/`, import them with Godot 4.6.3, run regression
and native-asset tests, then export and certificate-check the signed Android APK.

**Important:** If the archive is not staged, the nature-preview APK build
deliberately fails with `AETHERFALL_NATURE_MISSING` rather than silently
shipping the old placeholder grass/trees.

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
