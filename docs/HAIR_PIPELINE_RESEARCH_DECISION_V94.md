# Aetherfall v94 — Hair pipeline research decision (14 Oct 2026)

**Decision:** Offline scripted low-poly anime hair clumps/curve-to-mesh, organized into stable modular layers. Use the existing extracted Tripo hair as a design reference and fallback; do NOT continue regenerating full hair+head meshes for each style. Use Configura for appearance state, Godot 4.6.3 for BoneAttachment3D and (later) SpringBoneSimulator3D. No modification to approved male/female 65-bone rigs. The shipped APK remains untouched until complete in-engine QA.

## Evidence / comparison
- Tripo Studio's Segmentation v2 supports Simple, Balanced, Detailed, but segmentation of an organic head into hair can still require subjective shape review. https://www.tripo3d.ai/features/ai-model-segmentation
- VRoid Studio offers editable anime strand groups, base/front/back/side/extension hair, plus individual hair-bounce bones. It exports VRM models, not plug-and-play hair GLBs for our existing Tripo body rig. VRoid Studio's published supported platforms are Windows, macOS, and iPad — not the owner's Android-only setup. https://vroid.com/en/studio https://vroid.pixiv.help/hc/en-us/articles/900005965586-How-to-Apply-Hairstyle-Items
- Blender curve-to-mesh converts procedural spline shapes into exportable mesh geometry; exported glTF does not preserve native Blender curves. https://docs.blender.org/manual/en/4.5/modeling/geometry_nodes/curve/operations/curve_to_mesh.html https://docs.blender.org/manual/en/4.0/addons/import_export/scene_gltf2.html
- Alternative Blender tools investigated: GBH Tool supports stylized hair meshes, hair cards, bone rigging (GPL; GitHub version described by author as educational/testing); HairArranger is labelled unfinished; Anime-Hair-Generator and Blender-AnimeHairSupporter are candidates requiring separate compatibility review. https://github.com/GixoXYZ/BlenderGBHTool https://github.com/s-nako/HairArranger https://github.com/Mateusz-Dera/Anime-Hair-Generator https://github.com/relarar/Blender-AnimeHairSupporter
- Godot 4.6 supports head BoneAttachment3D and SpringBoneSimulator3D to animate extra hair bone chains, but scaled skeletons may make springs unstable. https://docs.godotengine.org/en/4.6/classes/class_boneattachment3d.html https://docs.godotengine.org/en/4.6/classes/class_springbonesimulator3d.html
- Opaque meshes render more reliably/efficiently than alpha-blended hair; for finer hair Godot documents alpha scissor/hash. https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html

## Measured experimental baseline (local user GLBs, NOT verified game appearance)
- Tripo source hair: 42 mesh parts grouped into five categories.
- Draft male and female hair fit at different scales; neither anatomically verified.
- Draft assembled style: 9,333 triangles per head across approximately 48 meshes after added scalp/fringe geometry.
- This is too fragmented for large MMO crowds. Consolidate geometry inside each swappable layer with 1–2 surfaces/materials where possible; profile real draw calls and memory on Galaxy S23 FE rather than declaring a universal poly budget.
- Head rig bones, names, weights stay unchanged. Experimental layer controller and Configura-state tests on experiment/configura-character-studio-v94 passed: https://github.com/demetrecerrone-star/Aetherfall/actions/runs/38596790096.
- Testing did NOT include real new GLBs on Android and did NOT build a signed APK.

## Recommended production architecture
- Author script-controlled tapered ribbon/clump geometry from a small set of spline guides. Parameters: part name, roots, direction, silhouette length, width, curvature, twist, tip thickness, seed.
- Separate hair into scalp cap, back/nape, sides L/R, bangs, and optional ponytail/extension. Use stable coordinates and one normalized head reference, then auto-fit against male/female head measurements; visually correct each via face-front/side/back screenshots.
- Bake/finalize GLB mesh **offline** (Python/trimesh or headless Blender). Do NOT create heavy runtime procedural meshes per NPC.
- In Godot, attach short/rigid styles to existing head via BoneAttachment3D. For long/loose extensions later, add a separate unscaled accessory Skeleton3D with spring bone chains; never add arbitrary joints to the shared 65-bone base rig.
- Map Configura hair preset, bangs, sides, highlight, root and tip color onto nodes/material instances, save per player. Ensure presets preserve identical layer naming.
- For hat/helmet, set hair visibility/alternate compact hair meshes based on equipment metadata. Keep no scalp gaps.
- Render and check front, side, three-quarter and back on both actors, under idle/walk/sprint, and with head tilt; profile Android camera, shadows and low-end graphics preset.
- Only after screenshot approval + Godot import animation fit + mobile FPS test, ship it with permanent signing key.

## Near-term milestones
1. **One polished test style**: short layered anime hair on male and female; full 360 screenshots, correct forehead/scalp.
2. **Modularity**: independent bangs/side toggle, 5 colors, two highlights; options persist. 
3. **Long option**: optional back-layer sway with accessory bones, test helmet hiding, mobile frame budget.
4. **Then** return to eyes/eyelids and clothes, using same non-destructive modular accessory approach.

## Constraints
Current user works on Android only. Prefer code-driven generation and GitHub Actions; never require user to operate Blender or VRoid. Verify commercial redistribution terms before adopting any third-party mesh/preset/add-on content. Do not imply a successful GLB import, animation retargeting or signed APK build from data-only tests.
