# Aetherfall Equipment & Clothing Occlusion Architecture

This document records architecture ideas studied from a Godot 4 + Blender clothing/inventory tutorial, but the implementation described here is Aetherfall-specific and should be written independently.

Important licensing note:
The referenced forum tutorial is published under CC BY-NC 4.0. Aetherfall should not copy its implementation code into a commercial build without separate permission. We can learn from the concepts and implement our own system.

## Why this matters

Aetherfall needs modular outfits and armor that can be equipped independently without:
- body poke-through,
- lower layers showing through upper layers,
- duplicated full character meshes,
- hard-coded one-off visibility logic for every outfit.

The system should support male and female bodies, shared equipment slots, multiple clothing layers, armor, and future cosmetic gear.

## Aetherfall approach

### 1. Body segmentation

Keep the production body segmented into logical hide regions:
- Head
- Neck
- Torso
- Pelvis
- UpperArm L/R
- Forearm L/R
- Hand L/R
- Thigh L/R
- Calf L/R
- Foot L/R

Each wearable item declares which body regions it covers.

Example conceptually:
- Tunic: torso + upper pelvis, optionally upper arms depending on sleeve length
- Trousers: pelvis + thighs + calves as needed
- Boots: feet + lower calves
- Full plate chest: torso + upper arms + possibly neck
- Gloves: hands + wrist/forearm zones

### 2. Clothing layers

Use explicit semantic layers rather than inferring all behavior from mesh names.

Proposed layer order:
1. Body
2. Underwear / base layer
3. Shirt / tunic
4. Trousers / skirt
5. Light armor / vest
6. Heavy armor / coat
7. Belt / waist accessories
8. Boots / gloves
9. Cape / back
10. Cosmetic overlay

Each gear resource can hide lower layers or only selected regions of lower layers.

### 3. Data-driven EquipmentDefinition

Every equippable item should have data for:
- unique id
- display name
- slot
- compatible body types / fit profile
- scene or mesh resource
- covered body regions
- layer
- lower clothing regions it occludes
- optional stat block
- optional enchantments
- icon
- material variants / dyes
- attachment point for rigid gear
- deformation profile for skinned gear

Do not encode gameplay meaning only in Blender object names.

### 4. Artist-authored coverage metadata

Blender remains the authoring source of truth for which pieces visually cover others, but export that intent as stable metadata rather than a fragile comma-separated naming convention.

Preferred options:
- custom properties on Blender objects exported into GLTF extras where supported, or
- a generated sidecar JSON manifest created by the Blender export script.

The manifest can describe:
- body regions hidden by each item,
- garment subparts,
- layer relationships,
- material slots,
- skeleton compatibility,
- expected equipment slot.

### 5. Occlusion resolver

At equip/unequip time:
1. Gather all equipped items.
2. Sort/evaluate by clothing layer.
3. Resolve which body regions are covered.
4. Resolve which lower garment subparts are covered by higher layers.
5. Apply visibility once.

Do not do this every frame. Recalculate only when equipment changes, character body changes, or a cosmetic variant changes.

### 6. Per-character state

Never use globally shared scene groups for visibility state across multiplayer characters.

Each character instance should own its own:
- equipment state,
- coverage state,
- body-region visibility state,
- garment visibility state.

This avoids one player's equipment affecting another player's meshes.

### 7. Blender source organization

Use one master Blender character file per body standard:
- Armature collection
- Body collection
- Garment source collection
- Export-ready garment collection
- Reference collection
- QA pose collection

Keep the armature stable across revisions.

For garment fitting:
- create garments as separate meshes,
- transfer weights from the body where appropriate,
- preserve normals/weights when splitting a garment into visibility subparts,
- stress-test before export,
- export visible production collections only.

### 8. Shared animation compatibility

Use Godot BoneMap + SkeletonProfileHumanoid for imported characters when retargeting is needed.

The Aetherfall shared 65-bone skeleton remains the production standard. Clothing does not introduce alternate gameplay skeletons.

### 9. Visibility subparts

Only split clothing where partial occlusion actually requires it.

Examples:
- tunic torso vs lower tunic flap,
- shirt sleeves vs shirt torso,
- coat sleeves vs coat body,
- boot shaft vs foot section if required.

Avoid excessive fragmentation because every additional subpart increases authoring and QA complexity.

### 10. Mobile performance

For Android:
- equipment visibility changes are event-driven, not per-frame;
- body sections fully covered by gear should be hidden;
- invisible garment subparts should not render;
- keep material count low;
- atlas compatible gear where practical;
- use LOD/visibility ranges for distant players;
- consider simplified remote-player gear at long distances.

## Male peasant first implementation target

The male peasant is the proof case.

Expected pieces:
- Tunic torso
- Tunic sleeves
- Optional tunic lower flap if needed for trousers/belt occlusion
- Trousers
- Belt
- Boots

Expected body hiding:
- Tunic -> torso and selected upper-arm regions
- Trousers -> pelvis/thighs and relevant lower-leg regions
- Boots -> feet/lower calves
- Belt does not need body hiding by itself

The authored v46-style visual quality remains the baseline; this system solves modular visibility and clipping, not silhouette design.

## QA

Every equipment combination must be tested in:
- idle
- walk contact
- walk down
- walk passing
- walk up
- sprint/run
- crouch
- jump
- torso twist
- arms raised
- weapon attack/block

A gear combination fails if it produces:
- body poke-through,
- hidden areas that should remain visible,
- lower-layer clipping through upper layers,
- visible split seams,
- broken normals,
- mismatched skeleton deformation.

## Implementation rule

Use the external tutorial as a conceptual reference only. Do not copy CC BY-NC implementation code into the shipping commercial project. Build and test an original Aetherfall implementation around our existing equipment/resource architecture.
