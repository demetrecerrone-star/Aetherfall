# Aetherfall Production Asset Pipeline

This is the project-wide quality bar for assets created for Aetherfall. The goal is to create our own consistent game-ready characters, gear, interiors, buildings, props, vegetation, and world kits rather than depending on unrelated asset packs.

## Character and clothing track

1. Lock approved anime silhouette before rigging.
2. Model garment as real geometry with cloth volume; never use painted-on body shells as final art.
3. For loose cloth, use Blender cloth settling as a rest-shape tool when it improves drape. Apply the settled result before game export; do not depend on runtime cloth for the Android baseline.
4. Retopologize and keep deformation-friendly loops around shoulders, elbows, hips, knees, and ankles.
5. UV every production garment.
6. Transfer weights from the matching body with Data Transfer / nearest-face interpolation.
7. Preserve the shared 65-bone Aetherfall skeleton and authored animation library.
8. Enable Preserve Volume where it improves deformation.
9. Use Corrective Smooth only in a topology-safe modifier position and restrict it to problem areas when needed.
10. Hide covered body regions in Godot to eliminate poke-through and wasted overdraw.
11. Stress-test idle, walk, sprint/run, crouch, jump, sword attack, block, bow/staff pose, arms raised, deep knee bend, and torso twist.
12. Export GLB and validate in Godot before Android/device approval.

### Male peasant acceptance bar

- Tunic reads as cloth, not chest anatomy.
- Clean neckline and shoulder seam.
- Sleeves do not balloon unnaturally.
- Hem has natural ease and does not glue to the thighs.
- Belt sits as a separate leather layer with stable deformation.
- Trousers retain baggy thigh/knee folds and taper toward the boots.
- Boots read as worn medieval leather, not blocks or slippers.
- No visible body poke-through in idle/walk/run.
- Front, 3/4, side, and back silhouettes all pass.
- A newer pass never replaces the accepted baseline unless it is visually better and passes deformation QA.

## Materials and texturing

- Use real UVs on production assets.
- Bake or author mobile-friendly texture detail instead of relying on unsupported procedural shader complexity.
- Cloth: high roughness, subtle weave/fiber detail.
- Leather: controlled roughness variation, edge wear, stitching/seam detail where useful.
- Metal: readable stylized reflections without excessive shader cost.
- Wood/stone: reusable trim sheets and tileable materials wherever possible.
- Prefer 1024 textures for ordinary assets; reserve 2048 for large/hero assets when justified.

## Hard-surface / world-building track

- Build modular, reusable kits for blacksmiths, inns/taverns, guild spaces, homes, shops, gates, walls, bridges, and dungeons.
- Model interiors as real playable spaces, not facade-only shells.
- Use non-destructive booleans, curves, bevels, clean normals, and reusable components.
- Make interactable pieces animation-friendly from the start: doors, chests, forge bellows, signs, gates, quest boards, furniture, and mechanisms.
- Keep consistent metric scale and snap dimensions across modular pieces.

## Vegetation track

- Create Aetherfall-specific grass, shrubs, flowers, broadleaf trees, conifers, and ground clutter.
- Generate variation in Blender/Geometry Nodes, then bake/export efficient meshes for Godot.
- Use instancing/MultiMesh for repeated vegetation.
- Prepare LODs and simple wind-ready geometry without expensive per-object simulation.

## Godot and Android QA

- Shared humanoid BoneMap / retargeting standard.
- Automatic import validation for skeleton count, materials, animation clips, and required equipment slots.
- LOD / visibility-range strategy for buildings and vegetation.
- Occlusion culling for interiors, streets, and dense town blocks.
- Final approval happens in Godot and on Android, not from Blender renders alone.
- Keep every accepted visual checkpoint so an unsuccessful experiment can be rejected without losing the last good version.

## Production principle

Use multiple references and tutorials to solve each problem, but convert successful techniques into repeatable Aetherfall scripts, checklists, and tests. We are building a content factory, not a collection of one-off fixes.


## SouthernShotty study notes adopted into Aetherfall

These rules come from reviewing the available public lesson transcripts and course outlines for SouthernShotty's stylized character, rigging, modeling, texturing, and walk-cycle classes.

### Deformation topology

- Put geometry where deformation actually happens instead of adding uniform density everywhere.
- Maintain clean edge loops around elbows, wrists, shoulders, hips, knees, ankles, eyes, and mouth.
- Add extra supporting loops on the compressed side of major bends (especially the back of knees/elbows) when needed.
- Prefer quad-based authoring topology and triangulate only at the game/export stage when practical.
- Use poles deliberately to redirect edge flow away from high-deformation areas.

### Weighting strategy for stylized characters and gear

- Do not assume Blender automatic weights are correct for stylized or intersecting meshes.
- Rigid or nearly rigid accessories (buckles, pouches, hard plates, simple straps) should use explicit/limited bone assignments rather than soft full-body weighting.
- Soft garments should inherit the character's body weights as a starting point, then be hand-corrected around shoulders, hips, elbows, knees, and ankles.
- Validate weighting by posing immediately; never judge weights only in rest pose.
- Keep the underlying character skeleton unchanged so all gear remains compatible with the shared Aetherfall animation library.

### Corrective deformation

- Use corrective shape keys only when topology and weights cannot solve an extreme-pose deformation cleanly.
- Correctives should target repeatable problem poses, not compensate for generally bad topology.
- Bendy Bones are useful for secondary flexible elements in Blender authoring (tails, tentacles, some hair/cape controls), but are not part of the core 65-bone gameplay skeleton unless explicitly baked/exported.

### Modeling discipline

- Build from aligned front/side references when accuracy matters.
- Use Mirror during symmetrical modeling and keep references grouped/toggleable.
- Add subdivision/supporting loops only where silhouette or deformation needs them.
- Avoid solving smoothness by brute-force polygon count; use clean shading and efficient topology.
- Preserve the accepted silhouette first; technical changes do not justify making the character visually worse.

### UV and stylized texturing

- Production assets require saved UVs and saved external texture files; never rely on unsaved Blender paint state.
- Use paint masking/material separation to keep cloth, leather, skin, and accessories controllable.
- For mobile assets, use procedural nodes mainly as authoring/baking tools; export portable PBR textures for Godot.
- Stylized texturing depends heavily on deliberate painting, not only realistic procedural materials.
- PBR remains the shared transport standard for roughness/metalness/normal information.

### Animation QA poses

For locomotion QA, inspect the four core walk-cycle positions:
1. Contact
2. Down
3. Passing
4. Up

Garments must be checked at each pose because these expose different knee, hip, ankle, hem, and shoulder compression states. Also test the stylized/anime run separately, since exaggerated poses can reveal failures a normal walk does not.

### Aetherfall implementation consequence

The male peasant baseline is not approved from a single rest render. A pass must preserve or improve the accepted front/3/4/side/back silhouette, then survive the locomotion pose set. Only after that do UV/material improvements become the new baseline.


### Skillshare lesson notes — Blender interface and workspace discipline

From SouthernShotty's "Your First 3D Character" interface lesson:

- Keep Blender in metric units and use typed axis-constrained transforms for repeatable game-scale edits.
- Use the Outliner and Collections as production organization, not just viewport clutter control; separate character body, rig, garments, accessories, references, cameras, and lights.
- Use named Blender workspaces deliberately: Modeling, Sculpting, UV Editing, Texture Paint, Shading, Animation, Rendering, Compositing, and Scripting.
- Use Solid/Wireframe/Material Preview/Rendered views as separate QA modes rather than judging everything from one viewport mode.
- Use modifiers non-destructively during authoring and apply only when required by the export pipeline.
- Keep reference images and helper objects isolated in their own collection and toggleable.
- Treat UV editing and Texture Paint as first-class production stages, not final cleanup.
- The Scripting workspace is part of the Aetherfall production path: repetitive Blender operations should be scripted and validated rather than repeated manually.
- Camera/render views are for presentation checks; final asset approval remains based on the game camera in Godot/Android.
