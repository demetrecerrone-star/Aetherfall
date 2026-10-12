# Tripo fitted peasant player test

This experimental branch is based on the working Universal character branch. Install **both** user-provided fitted character GLBs into `cleanroom/models/tripo/`, with their original GLB bytes stored under these filenames:

- `male_peasant_runtime.bin`
- `female_peasant_runtime.bin`

The provided conversation ZIP `Aetherfall-Tripo-Godot-Integration-Install.zip` includes those two character files, their structural reports, and installation instructions. The original loose fitted garment meshes inside those drafts are now treated as reference-only.

The Starter Town loader uses the Tripo models only if *both* files exist. Otherwise it loads the last-tested Quaternius Universal characters. The Tripo models have 65 Mixamo bones, 15 modular body regions and exactly 3 native clips. Male idle = `standing_relax`; female idle = `idle`; both have `walk` and `run`. No combat or interaction animations are asserted. Runtime starter clothing is now generated from those modular body regions with the same `Skin`, skeleton path, transforms, bone indices and weights as the character. The older `AF_Gear_peasant_*` draft meshes are hidden. This removes the rigid/floating-shell behavior while keeping outfit and skin together for camera fading.

After copying to `cleanroom/models/tripo/`:

```bash
godot --headless --editor --path cleanroom --quit
godot --headless --path cleanroom --script res://tests/tripo_peasant_preview_test.gd
```

Follow with desktop/Android screenshots and walking/sprinting tests. The previous offline draft renders showed loose sleeves / floating hands; that draft-garment path is now disabled and the regression test requires body-derived skinned clothing plus hidden legacy pieces. The two Tripo character binaries are still not committed to GitHub, so a Tripo APK cannot be reproduced by CI until those files are staged. The existing source/build and signing credentials are untouched. The Android export preset includes `models/tripo/*.bin` for when the files are staged in CI.
