# Aetherfall active Android baseline

The active development baseline for Aetherfall Starter Town is the APK
`Aetherfall-StarterTown-Pass3.apk` supplied by the project owner on
2026-10-11.

## Confirmed build identity

- APK version name: `pass3-scenery.128`
- Android version code: `100000128`
- Android package ID: `com.demetrecerrone.aetherfall.cleanroomapp01`
- Original GitHub branch: `feature/quaternius-nature-megakit-import`
- Original source commit: `249650aa61a219f6b437f6b80001313dbe6d5e1c`
- GitHub Actions Starter Town workflow run #128:
  https://github.com/demetrecerrone-star/Aetherfall/actions/runs/38178634034
- Uploaded APK SHA-256:
  `ffb31a8ee17bc955799ab2fb112f2f1da3f4f72ac127b85c47525f0a03e0cc49`
- Signing certificate SHA-256:
  `b6e45b885a66b8ac91e7759fc8a7034669590cb7bebddc9c22ec85063eba8f92`

## Rules for continuing development

- Continue from THIS branch and its cleanroom Godot project, not the older
  `feature/starter-town-pass3-valley` or `feature/starter-town-title-pass3`
  branches without a deliberate comparison.
- Retain the existing fountain and animated water, optimized stylized nature,
  graphics-quality features, hanging signs, camera/player behavior, and existing
  game-ready scenery.
- Preserve the four integrated market vendor desks and their 12 merchandise
  props. Fix appearance issues directly on the active branch. Do not blindly
  cherry-pick prior stand modifications from other branches, as those variants
  may omit the market decor or newer nature/graphics features.
- When building an installable update, keep the same Android package name and
  signing certificate. Increment versionCode above the current installed build.
- Run marketplace, fountain, nature, scenery, graphics, collision and startup
  tests before publishing an APK. Inspect on-device screenshots for visual QA.

The APK is a compiled test artifact, not an editable Godot source project.
Source edits must be made in the corresponding GitHub branch and re-exported.

## Follow-up: merchandizing height on this baseline

The imported MarketStand_1 canopy begins at approximately Y=1.284m in
stall-local space. The four existing integral counters top out at Y=1.020m,
but the old 0.350m-tall stock crates reached Y=1.375m and penetrated the
roof edge. The market stock has now been fitted to a maximum height of
0.215m and anchored at exactly Y=1.020m, retaining the existing four
stall frames, single integrated selling counters and twelve genuine Quaternius
merchandise props. The market decorations test checks the actual fitted GLB
height and the desk contact / canopy-clearance invariants. No prototype-branch
stall code is merged; source modifications remain on this baseline branch.

## Pass 4.2e: counter visual integration (phone screenshot QA)

The active APK showed the native Quaternius market stand's built-in low storage
shelf behind an oversized, forward-protruding service counter. Keep all four
original imported awnings and posts, but use a slimmer 1.94m x 0.90m selling
surface at 1.02m waist height, inset 0.28m farther into the canopy, plus a
0.14m front apron (instead of 0.30m). Braces span the native timber post
depth so the counter looks structurally part of the stall. All twelve
shallow goods move back with the desk; no merchandise meshes are omitted.
The market QA enforces full merchandise support, slim fascia, and in-frame
counterfront without touching fountain, vegetation, or player controls.
