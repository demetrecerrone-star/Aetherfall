# Tripo Peasant Android Preview
This branch changes ONLY the Starter Town playable male/female visuals to user-supplied
fitted Tripo GLBs, retaining the collision, camera, awnings, streets, nature,
control scheme, 5.00 m/s sprint and signed Android update identity.

Binary GLB fragments are committed in models/tripo and joined deterministically by
tools/assemble_tripo.py (SHA-256 checked). No network access or external file
sharing is required by CI to reconstruct the player models.

Each character has 65 Mixamo bones, 15 selectable body meshes, 15 skinned
peasant garment meshes and three authored clips (idle/walk/run). Clothing-covered
body meshes are hidden while visible head and hands are retained. This is an
experimental phone-review build, not a finished skin-weight or clipping polish.
No special actions are simulated; idle and locomotion only.

The old Quaternius body source is preserved as a rollback option. The ranger and
knight are intentionally not equipped, and tutorial armor remains locked.
