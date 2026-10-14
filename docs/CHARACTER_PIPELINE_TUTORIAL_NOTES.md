# Aetherfall — tutorial-derived character pipeline (v94 target)

These are Aetherfall-specific working rules distilled from the October 12–14, 2026 Blender/Godot tutorials and character QA discussions. This note preserves decisions; it is not evidence that the v94 character integration or Android APK is complete.

## Production guardrails
- Preserve the approved male anime silhouette and curvier female anime silhouette; use tasteful clothing designs. Peasant garments must look like real loose medieval tunic/trousers, leather belt, and boots rather than body paint.
- Keep the five original Tripo GLBs unchanged as archival inputs. Make edited/export copies. Keep the last known playable build and Starter Town intact.
- Treat the two existing matching **65-bone** skinned character rigs as the standard. Preserve exact hierarchy, vertex groups/weights, UVs, materials, rest pose, and playable animations. Do not swap in an unrelated armature or accidentally export an extra 66th bone.
- Segment **copies in Blender**, not with Tripo's destructive mesh segmentation: body regions (head/neck/torso/pelvis/arms/hands/legs/feet) remain separate skinned meshes. Keep cut seams and normals clean.

## Clothing production sequence (each body separately)
1. Import original base GLB and garment GLB; check transforms, bone names/count, object origin, rest pose and scale.
2. Fit garment shells to the intended body silhouette. For realistic loose tunic drape, use cloth settle **offline** in Blender if helpful; do not depend on Android runtime cloth physics for the base outfit.
3. For each shirt/sleeve/trouser/belt/boot mesh, transfer the nearby body's deform vertex groups; apply the **same armature** and inspect skin binding. Correct nearest-body correspondence where layered/overlapping pieces could transfer from the wrong region.
4. Normalize and smooth weights, limit influences to Godot-compatible maximum, use Preserve Volume where effective, and use Corrective Smooth carefully after deform correction. Manually fix shoulder/armpit, elbow, wrist, upper-back, waist/belt, knee and ankle failures.
5. Keep tunic torso/sleeves/belt/trousers/boots separable for equipment swaps. Hide covered **body** regions to prevent poke-through; selectively hide covered lower clothing parts where necessary.
6. QA on bind/rest pose, idle, walk cycle phases, run/sprint, turning, jumps, arm elevation, twists, crouches and combat-ready extremes. Inspect front, back, side and closeups for seams, clipping, exploding vertices, texture/normal issues.
7. Export GLB with shared skin, textures and animations. Validate meshes really deform on the skeleton; detect floating/static clothing shells and unexpected duplicate body layers.
8. In Godot 4.6.3, reuse PlayerController/camera/touch UI/town. Replace the avatar *visual/model* resource, not physics/input. Use BoneMap/SkeletonProfileHumanoid only if actual retargeting is necessary.
9. Run Godot scene/import checks and Android emulator smoke QA, obtain real screenshots of both dressed characters at milestones, then use existing protected GitHub Actions persistent signing identity for the release APK. Verify APK certificate, package ID, version code, and installation/update path before calling it finished.

## Modular equipment architecture
- Use data-driven item definitions: item ID, equipment slot, body-fit type, mesh/scene path, coverage regions, clothing layer, occlusion rule, optional stats/dyes and attachment/deformation profile.
- Example slots: chest, legs, hands, feet; reserve ranger and knight gear as future swappable upgrades.
- Author coverage rules as stable Blender custom properties exported in GLTF extras or a JSON manifest; **do not infer gameplay state from mesh names alone**.
- Resolve body-region and garment-layer visibility only when gear, body, or cosmetics change, not every frame. Resolve *per character instance*, never globally.
- Keep clothing pieces/material count moderate, hide unseen body surfaces and use sensible LOD/visibility ranges to protect Android performance.

## Current narrow defect focus
- Male peasant: close upper-back opening; clean shoulder seams and sleeve deformation; fix belt overlap and minor waist poke-through.
- Validate female on her own body-fit profile, not by stretching the male garment. Do not regress already approved facial/neck silhouettes or arms-at-sides rest pose.
- Preserve movement, sprint, third-person orbit/fade behavior, touchscreen controls, Starter Town, title/loading flow.

## Branch and release caveat (verified Oct 14)
- `feature/universal-characters-rebuild` and `character-v95-clothing-fixes` are **diverged**, not fast-forward compatible: GitHub compare reports v95 three commits ahead of the rebuild branch and 253 behind. Cherry-pick/reimplement individual fixes after inspection; never merge the entire old branch blindly.
- A diagnostic script `tools/inspect_clothing_v95.py` exists on the v95 branch and reports clothing mesh armature targets, deform groups and bounds. It is an **audit**, not automatic fitting.
- The available older Blender script `tools/blender_character_pipeline.py` targets a generated 17-bone prototype, **not** the current 65-bone Tripo production rig. Do not run it against production character assets.
- **No verified signed Aetherfall v94 APK** is established by this tutorial note. Keep releases gated on real build and installation results.

## Learning references and licensing
- Tutorial concepts reviewed: Blender Data Transfer, Shrinkwrap, Corrective Smooth, cloth settling, normal/AO bake; Godot BoneMap, 3D import/animation retargeting and Android LOD/visibility.
- Examples consulted in prior conversations: 'Attach Garments to Characters Fast in Blender' (YouTube id `hl8Ws3P5zR4`), Corrective Smooth Modifier tutorial (`w7Lsn7J8tGM`), Blender Studio/DOGWALK, Stylized Character Workflow, Dikko, Bran Sculpts, CG Cookie, CG Boost, Polygon Runway, and official Blender/Godot docs.
- An equipment/occlusion tutorial discussed previously carried **CC BY-NC 4.0** licensing. Learn concepts, but do not copy its code into a commercial Aetherfall build without appropriate rights. Implement Aetherfall's own equipment resolver.
