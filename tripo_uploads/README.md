# Upload Tripo's final animated GLB here

**Android-only Aetherfall character test. Not the main game.**

From Chrome on your phone, open this GitHub directory and use **Add file → Upload files**.
Choose the downloaded **anime+adventurer+3d+model.glb** (the file that includes the
Mixamo skeleton and both `walk` and `run` animations). You can keep its original
filename. Commit directly to branch `feature/tripo-mixamo-character-test`.

A GitHub Actions workflow will automatically:
1. Check the GLB for distributed bone weights and both animation clips.
2. Import the actual textured Tripo character into a separate Godot 4.6.3 project.
3. Run Mixamo skeleton, playback and UI smoke tests.
4. Export a signed ARM64 Android debug APK under package
   `com.demetrecerrone.aetherfall.tripotest`.
5. Publish the APK as a build artifact.

This folder is only for Aetherfall test/prototype assets, not a production-release integration.

Validated user file: 2,572,872 bytes; SHA-256
`323b387655bbe0989c27f65377783ddab6d5ce17fee6047b5dedd37d3a80cd02`.

**Licensing:** Verify commercial-use rights from Tripo before distributing this character in a game.
