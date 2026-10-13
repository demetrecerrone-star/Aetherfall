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
