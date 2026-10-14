# Aetherfall v94 — Approved anime character modularization (experiment only)

The owner visually re-approved the unmodified Tripo male and female on October 14, 2026. Preserve originals in the separate Library backup `Aetherfall/Backups/Aetherfall_Approved_Tripo_Characters_Original_Backup_2026-10-14.zip`. Never alter archival GLBs. Work on copies and do not replace the playable Starter Town.

## Source-of-truth inputs

- Male: `anime+male+character+3d+model (1).glb`, SHA-256 `0deb0bb1ed72c4a9dc729bd102568949c4c3fa73457e5fcdbba2dc614b79f01e`.
- Female: `anime-style+female+character+3d+model.glb`, SHA-256 `fae53290faefde45bed7d8e58d3b2c25a8202769ca49cd9450eac6722da66b64`.
- Each has one skinned mesh primitive, one 65-bone Mixamo skeleton, one shared appearance material, and three animations (male `standing_relax/walk/run`, female `idle/walk/run`). Ordered bone names match; there are no morph targets or independently swappable hair/eyes in source.
- Original source GLBs are **not currently tracked** in this GitHub experiment. Do not claim online CI has verified them or redistribute these GLBs through a public repo without reviewing permissions.

## Approved visual target

Keep the male's anime-style proportions and the female's fuller, curvier anime silhouette (bust, waist, hips). Use attractive, tasteful fantasy gear. If repairing the combined topology becomes destructive, create **new bald modular bases** matching these established looks rather than insisting on failed mesh surgery.

## Implementation gates

1. Verify both raw source GLB checksums, 65-bone skeletons, and animations with `tools/audit_approved_tripo_modularity.py`.
2. On copied GLBs, inspect whether the hair can be separated cleanly. Do not delete skull or facial mesh to force it. New base heads must have complete bald scalp, intact eyelids/face, and stable eye sockets.
3. Supply discrete hair meshes and independently colorable iris materials or texture masks; do not recolor the entire face. Model alternate hairstyles and eye shapes only after the base is sound.
4. Preserve a matching 65-bone rig and mobile-friendly skin weights. Design modular mesh names, shared rest pose, and per-body garment fit profiles.
5. Define coverage regions for body occlusion and wardrobe slots (head, chest, legs, hands, feet, waist); defer ranger and knight equipment as future unlocks.
6. Register discrete hair/eye/outfit options in Configura, test save/load, and test real Godot model swaps. Configura itself does **not** generate 3D characters, automatically skin garments, or conform armor.
7. Provide **real** front, side, rear previews of both characters at meaningful milestones. Verify animation deformation on idle/walk/sprint and in-town camera/touch control stability before signed Android export. Preserve the previous playable APK and signing identity.

**Status:** Approved archival models re-verified; new modular bases, real visual segmentation, in-game Configura hookup, and signed v94 APK **not yet completed**.
