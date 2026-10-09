# v0.1 Character / Camera QA Checklist

## Desktop editor tests
- [ ] Main scene loads without parser errors.
- [ ] Spawn points toward the plaza; avatar and sky render correctly.
- [ ] WASD and arrows move in camera-relative directions.
- [ ] Character turns in direction of travel.
- [ ] Shift accelerates movement; releasing decelerates.
- [ ] Space jumps and gravity returns to ground.
- [ ] Jump is not repeatable infinitely in midair.
- [ ] Mouse right-drag orbits around avatar; pitch clamps at floor and sky extremes.
- [ ] R recenters behind avatar.
- [ ] Collisions stop movement through houses, tree trunks and fountain.
- [ ] Camera is kept outside obstructing house walls via SpringArm3D.
- [ ] HAIR and OUTFIT buttons change visible colors without breaking movement.

## Android-device tests
- [ ] Scene starts and runs in landscape on device.
- [ ] Joystick drag works while a separate finger swipes camera.
- [ ] Simultaneous joystick + JUMP does not cancel input.
- [ ] RUN toggle increases speed; tap again to walk.
- [ ] Releasing joystick returns to neutral without drift.
- [ ] Releasing camera finger stops camera rotation.
- [ ] HUD stays accessible with 16:9 and wider phone aspect ratios.
- [ ] No camera clipping into geometry while near the fountain and buildings.
- [ ] Device can sustain acceptable FPS without overheating.
- [ ] Touchscreen buttons remain comfortably reachable in landscape.

## Exit criteria
The first movement milestone passes when Android build and touch tests are complete, and character controls feel natural. Multiplayer/online status is NOT an exit criterion for this particular movement-only package.
