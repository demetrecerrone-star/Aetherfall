# Aetherfall Unity — development roadmap
_Last updated 2026-10-14. Planning document; milestones are not claims of completed runtime features._

## Scope and branch discipline
- **unity-reboot**: preserve existing title/login experience and Android Build Automation testing.
- **world-builder-prototype**: procedural town creation, scene-generation automation, visual review, and later character/monster prototypes.
- Do not merge unfinished 3D work into the Android build branch without an actual Unity Editor compile and Android smoke test.
- Target editor: Unity 6000.3.26f1; Android-first performance budget.

## Current sequence

- [x] **Milestone 0A — Title/login source.** Source assets, opening video, UI code and scene registered on `unity-reboot`. Real Android compile/runtime confirmation is pending.
- [ ] **Milestone 0B — First working Unity Android APK.** Validate title video, Skip, transition, login UI, orientation, safe-area layout and device performance. Check Unity Build Automation revision rather than replaying an outdated commit.
- [x] **Milestone 1A — World Builder source prototype.** Deterministic Unity C# editor generator on `world-builder-prototype`. Gate market, irregular walls, winding residential lanes and guild-run town hall on a 6 m hill. Source checks only.
- [ ] **Milestone 1B — Unity Editor scene-generation and screenshot workflow.** **Added to the path at the user's request.** Run the actual generator on a Unity-licensed editor runner (cloud-capable CI or development workstation); save `Assets/Scenes/StarterTown.unity` and generated terrain/material assets. Capture overhead and street-level screenshots or render frames; publish preview artifacts for phone review. Verify generated scene loads and renders. Do not mistake Python/source checks for an Editor test.
- [ ] **Milestone 1C — Approve town blockout visually.** Review path widths, hill gradient, roads, sightlines, walls, collisions and guild/market layout. Revise from screenshots before adding decorative models.
- [ ] **Milestone 2 — Stylized environment asset integration.** Replace basic boxes with appropriately licensed modular buildings, roofs, stairs, roads, trees and fountain details. Build LODs, material atlases and mobile-friendly colliders. Capture new screenshots after every substantial pass.
- [ ] **Milestone 3 — Player-character foundation.** Inspect current `Documentation/male.glb` and `Documentation/female.glb` for scale, materials, topology and skeletons. Choose one common humanoid rig/bone convention. Import through a supported glTF importer or convert to FBX; test idle, walk, run and turn. Do not assume models are already rigged or UMA compatible.
- [ ] **Milestone 4 — Character customization.** Modular hair, heads, skin tones and equipment attachment, avoiding mesh clipping; later evaluate UMA 2 compatibility and Unity-version support before committing to it. Save reproducible appearance presets. Verify silhouettes on Android.
- [ ] **Milestone 4B — Modular equipment pipeline.** After the common humanoid rig is validated, define data-driven equipment slots (head, chest, hands, legs, feet, main hand, off hand, back, and accessories). Build sample cloth/leather/plate outfits with rigged or fitted meshes; use shared bone names and equipment anchors for swords, staves, bows, shields and bags. Include body-mesh hiding and fit variants to avoid clipping. Define stable item IDs, stats and rarity separately from 3D visuals, with a simple equip/unequip inventory test and mobile rendering budget. Later connect drops, crafting, vendors, save data and server-authoritative MMO inventory. Confirm model licenses and Android/Unity runtime before expansion.
- [ ] **Milestone 5 — NPC inhabitants and guild government.** Add town-gate guards, shopkeepers, guildmaster, registration and contract board interactions, starter quests and bounded pedestrian paths.
- [ ] **Milestone 6 — First monster family and animation system.** Start with one creature (e.g., slime or wolf), 3D model + appropriate Generic/creature rig, idle/wander/attack/hit/death clips, colliders, health/hit events, and deterministic spawn zones **outside** safe town walls. Reuse controllers and VFX across variants, not necessarily humanoid skeletons.
- [ ] **Milestone 7 — First playable town-to-field loop.** Player controls, interaction, exit/loading, monsters, combat and return to guild. Test real Android FPS, thermal behavior, memory and nav.
- [ ] **Milestone 8 — Expand world and content tools.** Reusable town blueprints, encounter spawn tables, quest content, named NPC profiles and persistent MMO systems as the network design becomes concrete.

## Creative direction / gameplay rules
- Classic anime-inspired JRPG character shapes, clean silhouettes, readable expressions and equipment.
- Starter town is governed by its local Adventurers' Guild; hilltop guild hall doubles as town hall, with registration, civic notices, quests and guard leadership.
- Gate-adjacent market is the first social hub. A curving street climbs past residences toward the guild district; the perimeter is not square.
- World generation runs in the editor, then publishes one **saved shared scene**; don't randomize every player's home town.
- Characters and monsters are separate asset pipelines: shared humanoid animator for players/townsfolk where practical; species-specific rig/animations for monsters.
- Keep mobile and later MMO performance in mind: LODs, mesh/material budgets, pooled monsters, distance-based animation update, culling and network-authoritative combat design when networking is implemented.

## Preferred asset-production pipeline (Blender optional)
The earlier Blender attempts have not consistently achieved the approved anime-JRPG quality, especially hair geometry, character proportions, clipping and equipment fit. **Do not make hand-modeling in Blender the critical path** to shipping Aetherfall.

1. **Characters:** Inspect existing male/female GLBs, then use a consistent, properly rigged anime base from owned or suitably licensed sources if those GLBs are unsuitable. Verify scale, textures, rig mapping, Unity Humanoid support, animation and Android performance. Consider a dedicated anime-character creator where its export rights and avatar proportions work; do not assume VRM/GLB is automatically Unity-ready.
2. **Weapons and static accessories:** Prefer prebuilt licensed modular weapons, Tripo-generated starting geometry when the result passes visual and topology checks, and editor-based Unity placement through attachment anchors. Assign item IDs and gameplay stats independently of visuals.
3. **Armor and wearable accessories:** Prefer pre-rigged armor packs explicitly compatible with the chosen shared skeleton/body proportions. Fit-test each wearable in Unity under idle, walk, run and attack; correct penetrating meshes or reject the asset. Tripo output alone does not guarantee wearable rigging, deformation or quality.
4. **Monsters:** Start with ready-to-animate creatures from licensed assets or vetted generated models, each with an appropriate creature rig or procedural animation approach. Reuse AI/health/spawn logic independently of species model.
5. **Unity automation:** Import and organize prefabs, material presets, collision, animation controllers, equipment slots, preview scenes and screenshot evidence. Use Blender only for narrowly scoped conversions or repairs if a reproducible script solves the issue, rather than relying on difficult manual artistry.
6. **Approval gate:** Provide actual Unity-rendered screenshots of the model **wearing the gear** before approving it. No promise of high-quality 3D visuals merely from source code or concept imagery.

## Review gates
1. Review a screenshot/render after every meaningful **visual** milestone.
2. Verify Unity Editor scene creation and script compilation, not just static source tests.
3. Promote from prototype branch to `unity-reboot` only after screenshots and runtime checks pass.
4. Give the user an installable APK from a confirmed successful build for hands-on testing.

## Current blockers
- Unity scene generation with screenshots has not yet been configured or demonstrated.
- Existing GLBs have not yet been validated in Unity as fully animated humanoid characters.
- No monsters are implemented in the Unity reboot.
