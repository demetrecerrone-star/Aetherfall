# Tripo fitted peasant player test

This experimental branch is based on the working Universal character branch. Install **both** user-provided fitted character GLBs into `cleanroom/models/tripo/`, with their original GLB bytes stored under these filenames:

- `male_peasant_runtime.bin`
- `female_peasant_runtime.bin`

The provided conversation ZIP `Aetherfall-Tripo-Godot-Integration-Install.zip` includes those two files, their structural reports, and installation instructions.

The Starter Town loader uses the Tripo models only if *both* files exist. Otherwise it loads the last-tested Quaternius Universal characters. The Tripo models have 65 Mixamo bones, 15 modular body regions, 15 fitted garment meshes and exactly 3 native clips. Male idle = `standing_relax`; female idle = `idle`; both have `walk` and `run`. No combat or interaction animations are asserted. Concealed torso/pelvis/leg/foot meshes are hidden, exposed head/arms/hands remain; outfit and skin fade together near the camera.

After copying to `cleanroom/models/tripo/`:

```bash
godot --headless --editor --path cleanroom --quit
godot --headless --path cleanroom --script res://tests/tripo_peasant_preview_test.gd
```

Follow with desktop/Android screenshots and walking/sprinting tests. The offline draft renders had noticeable loose sleeves / floating hands; don't merge these draft models into production until visual fitting is corrected. The files are not yet included in GitHub and no Tripo APK has been signed. The existing source/build and signing credentials are untouched. The Android export preset includes `models/tripo/*.bin` for when the files are staged in CI.
