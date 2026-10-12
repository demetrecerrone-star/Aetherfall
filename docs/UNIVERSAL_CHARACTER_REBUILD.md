# Aetherfall Universal Character Rebuild — Experimental Branch

## Purpose
Replace the incompatible hand/arm posing on the recovered v0.6.5 modular character with a matched Quaternius Universal Base foundation. This branch starts from the **signed Build #141 source**, retaining all Starter Town, marketplace, fountain, scenery, controls, and Android signing. **Do not change the release branch** until the replacement is visually verified on a phone.

## Verified source archive inventory
- **Universal Base Characters (Standard, CC0):** distinct full-body male and female Godot glTF models, each a 65-joint skinned skeleton; hairstyles, brows and beard meshes.
- **Universal Animation Library 1 (Standard, CC0):** 43 glTF/GLB clips.
- **Universal Animation Library 2 (Standard, CC0):** 43 more clips, including attacks, blocks, climbing and resource gathering.
- All four inspected skeletons (male base, female base, UAL1 mannequin, UAL2 mannequin) have **identical sets of 65 joint names**. Rest poses and body proportions differ slightly, so add local-rest-pose correction and preserve the target's bone lengths.
- Use the non-root-motion GLB variants for current virtual-joystick movement; reserve _RM versions for deliberate root-motion melee actions.

## Prepared outside the APK
The user-uploaded archives were combined into two self-contained textured 65-bone GLBs, one male and one female, each with 25 imported animations. Source builder is `build_universal_characters.py`, distributed alongside the two prototype models in the conversation artifact **Aetherfall-Universal-Character-Foundation-Prototypes.zip**.

Source inputs: `Universal Base Characters[Standard] (2).zip`, `Universal Animation Library[Standard] (1).zip`, `Universal Animation Library 2[Standard].zip`.
The generator retargets each source bone's relative local quaternion onto the target's own rest pose; it discards mismatched bone translation tracks except additive pelvis motion, to protect fingers and limb length. It embeds original textures within each result.

## Next steps and gates
1. Import both proof-of-concept GLBs into a temporary Godot 4.6.3 character preview scene and validate import, textures, bone count, animation names, hands and foot planting at idle/walk/sprint.
2. Replace only playable character visuals in the experimental Starter Town; keep scene controller, camera, collision, town content and HUD intact.
3. Reconnect character appearance/hairstyles, outfit attachments, inventory and weapon action slots, then test on Android. Do not call the replacement finished based only on animation channel count.
4. Route melee/defense animations through a state machine; use existing idle/movement behavior while action clips play.
5. Only after an approved phone screenshot and signed APK should this branch replace the previous character implementation.

## Other available asset packs
Quaternius Medieval Weapons, Village, Fantasy Props, Nature, Crops, Dungeon and NPC/Monster packs have been uploaded. Review individual licenses before publishing raw assets in a public repository. In particular, the uploaded Bestiary pack has **Quaternius Asset License 1.0**, not CC0; it allows distributing a game but forbids redistributing the extracted pack as assets.

## First playable in-town replacement (Universal Base)
The current experimental branch now loads **both** supplied Universal Base
male and female instead of the old v0.6.5 or Tripo player. Both GLBs and their
embedded textures plus 25 authored action animations are stored permanently
in GitHub under `cleanroom/models/universal/*.bin`. The game uses the original
Starter Town controller and 1.62 actor scale with a 0.62 model fit factor,
matching an approximately 1.8-metre player. Idle_Loop, Walk_Loop, Sprint_Loop,
and Idle_FoldArms_Loop power the existing controls and POSE button. The new
INTERACT button previews the matching authored action on either sex. The old
LOOKS panel and v0.6.5 fallback are disconnected on this branch; detailed
Universal character customization will be reimplemented after mobile QA.
The isolated release-quality branch feature/avatar-creator-v065-town-integration
retains Build #141 unchanged. The experimental signed APK passes required
both-sex skeleton/25-animation/Android pack checks before phone testing.

## Build #145 — player-height adjustment after phone screenshots
User approved the overall Universal Base male/female animation appearance in
Build #144, including the slightly playful running style, but requested that
the characters be somewhat shorter relative to the town. Lower both models'
visual scale uniformly from 0.620 to **0.575** (7.26% smaller), without changing
the controller's global scale, movement speed, road collision, camera orbit,
sprint toggle or original 25 animation clips. The existing world-space boot
contact solver reads `_model.scale.y` and recalibrates on each import and
male/female switch. Character QA now requires the same 0.575 scale and near-
road grounded feet on both sexes. No change to fountain/market/nature/scenery.

## Build #146: walk-under market stall camera + calmer running
Phone feedback says the awning fills the view when the camera slips under it.
Low counter collision remains, but the previous oversized 2m camera AABB
above it is replaced with a compact below-waist camera blocker. Quaternius
market canopy geometry now fades dynamically if the roof obstructs the
camera-to-character line or the camera is inside its footprint, restoring
textures and opacity when the view clears. Only canopy meshes are faded when
separate; when merged with the full stall mesh, the imported model fades
smoothly rather than blocking the view. The four diagonally placed stands
track occlusion independently. House walls, town borders, camera-orbit behavior
and walk collision remain unchanged.
Both male and female now use the library's `Jog_Fwd_Loop` animation for
the RUN state in place of the exaggerated `Sprint_Loop`. Actual movement
speed and sprint toggle are preserved. Add regression for awning visibility,
restoration, wall collision and alternate character locomotion.
