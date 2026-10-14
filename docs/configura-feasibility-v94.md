# Aetherfall v94 — Configura evaluation (separate experimental branch)

Upstream: https://github.com/Team-Figoose/Configura
Pinned revision: 0a7b08b74a5a7e684d3242cf3f1140cffed023cb
License: MIT (original license remains with the submodule/addon)

**Status:** Initial compatibility smoke test, NOT a shipped character creator or an APK.
The base branch remains \`feature/universal-characters-rebuild\`; no production gameplay scenes, movements, controls, or signing settings have been changed.

## Why a submodule and a staging script?

Configura's repository nests the plugin in \`addons/Configura\` and bundles sample
Blender assets under \`!example\`. This experiment pins upstream source in
\`third_party/configura\` and copies *only* the addon code/assets, excluding
large sample Blender models, into Godot's expected \`addons/Configura\` path.
\`third_party/.gdignore\` prevents Godot registering duplicated global classes.

After cloning this *experimental* branch:

\`\`\`sh
git submodule update --init third_party/configura
python3 tools/install_configura_experiment.py
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/configura_smoke.gd
\`\`\`

The branch-specific GitHub Action runs this installation automatically.

## What the checks establish

1. The published Godot 4.6 Configura editor addon parses in Aetherfall Godot 4.6.3.
2. Hair-choice and eye-color options can be represented by Configura and
   saved/restored using a \`CharacterState\` resource.
3. The *existing* male/female Universal Base model binaries are 65-joint GLBs
   with locomotion animations. Those are NOT the new approved Tripo character files.
4. Project entry scene, Starter Town source, touchscreen controls, camera, sprint,
   and existing Android signing workflow remain unchanged.

## Not yet established

- The five originally uploaded Tripo GLBs are not presently tracked by this branch;
  they must be recovered through an available upload/artifact source or added with
  authorization before production integration.
- No Configura-generated UI has yet been linked to either Tripo model.
- Hair mesh swaps, eye material rendering, fitted peasant clothing, animation
  deformation, and Android frame time are **not visually verified**.
- Configura does not automatically conform armor to different bodies or transfer
  skin weights. Blender weight transfer / reusable fitted garment templates are
  still necessary.

**Acceptance criteria for a subsequent production candidate:** both approved
65-bone Tripo avatars, hairstyle/eye variation, an actual peasant outfit fitted
and skinned to each body, idle/walk/sprint deformation checks, screen captures,
touch controls and camera regression checks, and a permanently signed APK.

Do not merge this experiment into a playable branch or represent it as a
finished v94 Android release until those tests pass.
