# Aetherfall: Godot RPG Kit Library

A **reference library** of six MIT-licensed third-party Godot projects, pinned at specific revisions as Git submodules. These kits are **not enabled, copied into `addons/`, or integrated into the playable Aetherfall project**. The top-level `.gdignore` makes Godot skip this entire folder, preventing `class_name` collisions and accidental import/EditorPlugin activation.

## Why use submodules?
* The kit sources remain in their original GitHub repositories, but Aetherfall records each exact tested/reviewed commit. We can reproduce the same version in a later session.
* GitHub displays the linked upstream code. To fetch the *actual* files locally, run `git submodule update --init --recursive` after cloning the Aetherfall repo, or `git clone --recurse-submodules <Aetherfall URL>`.
* Submodules are references, not copied binaries. GitHub's **Download ZIP** of Aetherfall will not include submodule file contents. Clone recursively or download each pinned upstream archive instead.
* Do not update the submodules without auditing any new license, dependency, and Godot/Android requirement.

## Shortlist

| Purpose | Kit | Source and pinned revision | License | Compatibility and cautions |
| --- | --- | --- | --- | --- |
| Inventory, equipment, chests, item stacks | **GLoot** | [peter-kish/gloot](https://github.com/peter-kish/gloot) `6b09b87ac07a8536779ef1ab0fafc7e99830f948` | MIT | Godot 4.2+. Inventory data and UI; connecting armor meshes to our existing 65-bone Avatar Studio remains separate engineering. |
| RPG quests and quest editor | **Questify** | [TheWalruzz/godot-questify](https://github.com/TheWalruzz/godot-questify) `a102ab1bd4f0ee4280d5370d9aab2b49f8843325` | MIT (see any attributed bundled artwork) | Godot 4.4+. Graph-based quest creation; do not enable until checked in a throwaway project. |
| Animation/gameplay state logic | **Godot State Charts** | [derkork/godot-statecharts](https://github.com/derkork/godot-statecharts) `76d226a3efac66a72aea825382b320c94808f409` | MIT | Godot 4. State-machine logic for idle/walk/run/equip/combat; does **not** include animation clips. |
| 3D orbit, tracking and cinematic cameras | **Phantom Camera** | [ramokz/phantom-camera](https://github.com/ramokz/phantom-camera) `21d3762492e2dc51b448f55438b89b3c19349f96` | MIT | Godot 4.4+ current Asset Store. Evaluate against Aetherfall's approved third-person camera collision before adopting. |
| UI theme samples | **Themey** | [wadlo/Themey](https://github.com/wadlo/Themey) `678c5574b3a9274437c0c1e0ac15395056b5fc5f` | MIT code, CC0 graphics; some example Material Icons Apache-2.0 | Godot 4.x. Theme examples are not automatically a fantasy interface; use as a starting point and check licenses for individual artwork. |
| 3D character-creator ideas and blend-shape reference | **gd-character-creation** | [Flynsarmy/gd-character-creation](https://github.com/Flynsarmy/gd-character-creation) `cef22521e690472e7642222b521a5db6af6ea2c8` | MIT | **Reference only**: older Godot 4.1 prototype, mainly a female model. Not a replacement for our approved male/female modular 65-bone avatars. |

## Safe use / incorporation

1. `git submodule update --init --recursive` in the Aetherfall repository.
2. Open a **separate test Godot project** (or work on a new feature branch), not the production Starter Town.
3. For regular addons, copy the kit's specific `addons/<plugin_name>` folder into the test project's `addons/` directory; enable only the plugin you are testing under **Project Settings → Plugins**. Questify also has an optional translation-parser addon.
4. Preserve upstream license and attribution files whenever redistributing or integrating the code/assets.
5. Test parsing, mobile renderer, performance, input gestures, equipment compatibility, and Android exports before merging any runtime integration.

This branch is for **asset preparation and future evaluation**, not an APK update. Existing Aetherfall player rigs, signed packages, and Starter Town behavior remain unchanged.

### Current in-house assets

The Universal Base Characters, Modular Character Outfits, RPG Items and medieval-weapon files already supplied for Aetherfall are **not replicated here**, because their uploaded archives are not part of these open-source GitHub repositories. The already-working Avatar Studio integration remains the reference implementation for character body, clothes and hair. This library adds *optional outside systems*, not replacements.
