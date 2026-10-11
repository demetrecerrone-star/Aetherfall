# Aetherfall CC0 scenery integration

The `feature/quaternius-scenery-upgrade` branch integrates actual 3D models into
the original Godot Starter Town scene, leaving the anime adventurer, camera,
touch controls, and obstacle lists intact. The fountain stays removed and
the square has four market stalls.

## One-file model upload

Download `Aetherfall-Scenery-Assets-For-GitHub.zip` from this conversation.
At the repository root, select the `feature/quaternius-scenery-upgrade` branch
and use **Add file → Upload files** to upload the ZIP **without extracting**.

The `starter-town-android.yml` workflow automatically unpacks the 20 included
GLBs to `cleanroom/models/scenery`, validates their GLB headers, runs
Godot's scene import and scenery QA test, and builds the signed Android APK.
The build intentionally fails if the ZIP is missing, to avoid distributing
an unchanged placeholder town as a scenery upgrade.

Models include 4 houses, inn, blacksmith, 2 outdoor market stands,
stalls, crates, barrel, anvil, lantern, birch and maple trees,
3 bushes, and grass. Some are reserved for upcoming detailing.
The starter-town controller replaces visible primitive meshes using
`cleanroom/scenery_replacements.gd`, but retains their scripted collision
footprints. When loading a particular model fails, the previous mesh remains
visible; the CI asset test checks every required GLB first.

Converted files came from the user-uploaded Quaternius packs.
Original asset sources and their CC0 license information are
included in the downloadable ZIP. The binary source bundle is compact
enough for a single GitHub browser upload (<25 MB).
