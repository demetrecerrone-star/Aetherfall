# Verified Starter Town runtime model

Place the verified **65-joint Tripo/Mixamo GLB** here with this exact filename:

`models/tripo_adventurer.glb` (relative to the `cleanroom/` Godot project)

The model must have exactly one 65-joint skin and embedded `walk` and `run` animations. The game opens it as raw binary using `FileAccess`; do not substitute a Blender Rigify model or unanimated VRoid export.

The model is intentionally excluded from existing source commits because it originated as a separately provided asset. Upload it to this folder in GitHub to trigger **Aetherfall Starter Town Android APK**. The workflow validates the model, signs the APK with existing Aetherfall Actions secrets, and attaches the APK as a downloadable artifact.

This build uses a distinct Android package (`com.demetrecerrone.aetherfall.startertown`) to protect the existing installed prototypes. After visual approval, align package identity/versioning with the installed Starter Town if in-place updates are needed.
