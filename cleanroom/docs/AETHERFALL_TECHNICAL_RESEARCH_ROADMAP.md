# Aetherfall Technical Research Roadmap

This document collects the most useful current research for the Aetherfall character, clothing, rendering, world, AI/navigation, networking, persistence, and MMO backend pipelines. It is a living engineering reference.

## 1. Game-ready clothing in Blender

### Offline cloth shaping, not runtime cloth by default
Use Blender cloth simulation or Cloth Sculpt as an authoring tool to create a believable rest shape, then freeze/apply the result before game export.

Useful Blender features:
- Cloth collisions and self-collision for tunics, coats, capes, skirts, loose trousers.
- Cloth Sculpt brushes for localized folds and controlled art direction.
- Cloth Filter for global gravity/inflate/expand shaping.
- Keep collision distances tight enough to avoid the “floating cloth” look.
- Start from a mesh that does not already intersect the collision body.

Aetherfall rule:
- Runtime cloth is optional secondary polish later.
- The Android baseline uses authored/skinned geometry with baked rest-shape folds.

Primary docs:
- https://docs.blender.org/manual/en/4.5/sculpt_paint/sculpting/brushes/cloth.html
- https://docs.blender.org/manual/en/4.5/physics/cloth/settings/collisions.html

## 2. Deformation topology

Production topology must concentrate loops around deformation areas instead of distributing polygons uniformly.

Priority regions:
- shoulder / armpit
- elbow
- wrist
- pelvis / groin
- hip
- knee
- ankle
- neckline where garment meets neck
- boot shaft where it bends into the ankle

Guidelines:
- Keep predictable quad loops across bending regions while authoring.
- Leave enough geometry for compression on the inside of a bend and stretching on the outside.
- Keep loose garments separate from the body when that makes weighting and clipping easier.
- If inner/outer shells need to deform together, align topology when practical.
- Do not model every sculpted cloth wrinkle into the game mesh; preserve silhouette and major folds, then bake smaller detail.

References:
- Blender Studio Stylized Character Workflow topology guides.
- Blender Studio Blenderella clothing + body deformation workflow.
- Polycount production discussions on separate game clothing and matching topology near high-deformation areas.

## 3. Skin weighting and cleanup

### Data Transfer
Blender Data Transfer can transfer vertex groups, UVs and custom normals. Nearest Face Interpolated is especially useful for transferring body weights onto fitted garments.

Aetherfall workflow:
1. Fit garment in rest pose.
2. Generate matching vertex groups.
3. Transfer weights from body using nearest-face interpolation.
4. Normalize all weights.
5. Smooth localized transitions.
6. Clean negligible weights.
7. Limit influences to the export budget.
8. Hand-fix shoulders, armpits, hips, knees, ankles.
9. Pose-test immediately.

Primary docs:
- https://docs.blender.org/manual/en/4.5/modeling/modifiers/modify/data_transfer.html

### Preserve Volume
Armature Preserve Volume uses quaternion deformation and can reduce volume collapse around joints.

Use selectively:
- soft tunic shoulders
- thighs / knees
- sleeves

Do not assume it fixes bad topology or bad weights.

Primary docs:
- https://docs.blender.org/manual/en/4.5/modeling/modifiers/deform/armature.html

### Corrective Smooth
Corrective Smooth is intended for highly distorted skinned regions and is commonly placed after the Armature modifier.

Aetherfall rule:
- restrict it with a vertex group to the actual problem zone;
- do not globally smooth the entire garment;
- bind coordinates when constructive modifiers before it change topology.

Primary docs:
- https://docs.blender.org/manual/en/4.5/modeling/modifiers/deform/corrective_smooth.html

## 4. UVs, baking, and materials

### UV authoring
- Lock topology before final UV work.
- Mark as few seams as practical while controlling stretch.
- Place seams in visually hidden or natural garment seam locations.
- Maintain consistent texel density across modular gear.
- Design UV islands with future dye/material masks in mind.

Docs:
- https://docs.blender.org/manual/en/4.5/modeling/meshes/uv/unwrapping/introduction.html
- https://docs.blender.org/manual/en/4.5/modeling/meshes/uv/unwrapping/seams.html

### Baking
Cycles can bake:
- normal
- ambient occlusion
- base-color/procedural detail
- other material information for export

For animated clothing, tangent-space normal maps are the normal baseline.
Use Selected to Active / cages for high-to-low detail transfer.

Docs:
- https://docs.blender.org/manual/en/4.5/render/cycles/baking.html

### Aetherfall material targets
- linen: high roughness, subtle fiber/weave, localized fold darkening
- wool: soft coarse variation, high roughness
- leather: mid/high roughness with edge wear and compression variation
- metal: controlled metallic response, stylized broad highlights
- wood/stone: reusable tileables and trim sheets where possible

For mobile:
- default ordinary character/gear textures to 1024 unless visual testing justifies 2048
- pack masks where practical
- avoid unnecessary transparency
- use mipmaps

## 5. Blender -> glTF -> Godot metadata

Blender glTF export can include Custom Properties in glTF `extras`.

This is a strong fit for Aetherfall equipment metadata:
- equipment_slot
- clothing_layer
- covered_body_regions
- hidden_lower_garment_regions
- fit_profile
- skeleton_profile
- material_family
- dye_channels
- attachment_socket
- qa_version

Docs:
- https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html

Aetherfall implementation:
- Blender custom properties are authoring metadata.
- Exporter also generates a sidecar JSON manifest as a stable fallback.
- Godot importer/post-import step converts metadata into EquipmentDefinition resources.
- Shipping gameplay does not depend on fragile mesh-name parsing.

## 6. Godot character import and retargeting

Godot's humanoid retargeting uses BoneMap and SkeletonProfileHumanoid. Retargeting must account for Bone Rest differences, not only matching bone names.

Aetherfall:
- keep the authored 65-bone skeleton stable;
- map the gameplay subset to Godot's humanoid profile where useful;
- preserve extra Aetherfall attachment/facial bones outside the standardized humanoid subset;
- enable named skins on import;
- validate bind matrices and Skin resources automatically.

Docs:
- https://docs.godotengine.org/en/4.6/classes/class_skeletonprofilehumanoid.html
- https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- https://docs.godotengine.org/en/stable/classes/class_resourceimporterscene.html

## 7. Modular clothing/body occlusion

Aetherfall should use event-driven clothing visibility.

On equipment change:
1. collect equipped gear
2. evaluate semantic clothing layers
3. resolve body regions hidden
4. resolve lower garment subparts hidden by higher garments
5. apply visibility/material/body masks
6. cache result

Do not do this work every frame.

Each player instance owns its own occlusion state; never use global scene groups for per-player clothing visibility.

The current 16-region body segmentation is a good baseline, but subregions can be added only when an actual outfit combination requires them.

## 8. Android character optimization

Godot explicitly warns that skeletal animation/skinning and morphs can be expensive. Distant/occluded characters should reduce animation work or stop it entirely when the player cannot notice.

Aetherfall plan:
- full animation rate for local player / near important NPCs
- lower animation update rate for mid-distance NPCs/players
- freeze animation for distant or fully occluded actors
- lower-poly character LODs at distance
- simplify remote-player equipment at long range if needed
- body regions fully hidden by clothing should not render
- minimize material slots and transparent surfaces

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html
- https://docs.godotengine.org/en/latest/tutorials/performance/gpu_optimization.html

### Renderer
Godot Mobile renderer is the default high-end mobile choice. Forward+ is not the right Android baseline.

Docs:
- https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html

### Texture compression
Godot mobile guidance:
- ETC2 is the broad/default mobile VRAM compression path.
- ASTC is used for higher-quality mobile compression when supported/configured.
- enable 3D detection/mipmaps.
- normal maps should use the optimized normal-map import path.
- Godot expects OpenGL-style normal maps (Y+).

Docs:
- https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_images.html

## 9. LOD / HLOD / occlusion

Godot supports:
- automatic mesh LOD generation on scene import
- manual visibility ranges/HLOD
- occlusion culling

Use all three together where appropriate.

### Character LOD
- local hero: LOD0
- nearby actors: LOD0/1
- medium distance: simplified mesh/gear, reduced animation frequency
- far actors: LOD2/impostor/simplified silhouette depending gameplay

### Town/interiors
Occlusion culling is especially valuable for:
- inns
- blacksmiths
- guild halls
- dense streets
- dungeons
- buildings with real interiors

The Mobile renderer can benefit strongly because it does not use the same depth prepass behavior as Forward+.

Docs:
- https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html
- https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html

## 10. Vegetation

Use MultiMesh for large repeated sets such as:
- grass
- shrubs
- flowers
- rocks
- repeated trees

MultiMesh reduces draw-call overhead dramatically, but an entire MultiMesh is culled as a group rather than per-instance.

Aetherfall rule:
- spatially chunk vegetation into multiple MultiMeshes so culling remains useful.
- use simpler meshes/visibility ranges for distance.
- reserve individual scene nodes for interactable vegetation or unique hero objects.

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html
- https://docs.godotengine.org/en/4.6/classes/class_multimeshinstance3d.html

## 11. Large-world streaming

Godot recommends dividing large worlds into tiles/chunks loaded on demand. This controls memory and processing cost.

Aetherfall direction:
- world divided into streaming cells
- separate static visual chunk, navigation chunk, spawn data, gathering/resource data
- asynchronous/background loading where safe
- unload distant world cells
- keep persistent world state in data, not solely in live scene nodes

Large world coordinates are useful for extremely large physical scales, but are not automatically required for an MMORPG-sized authored fantasy continent. Chunking/origin management may be sufficient and is friendlier to mobile until measurement proves otherwise.

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html
- https://docs.godotengine.org/en/4.x/tutorials/physics/large_world_coordinates.html

## 12. NPC navigation and crowds

NavigationServer can manage multiple isolated NavigationMaps.
NavigationAgent avoidance has significant cost with many registered agents.

Aetherfall plan:
- use authored/baked NavigationRegions per streamed world chunk
- avoid runtime navmesh baking unless necessary; if required, use background threads
- enable avoidance only on nearby actors that actually need local crowd steering
- cap neighbor counts/radii
- distant NPCs use cheaper schedule/simulation logic instead of full NavigationAgent updates
- consider separate maps/layers for different actor locomotion classes

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_optimizing_performance.html
- https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_using_navigationmaps.html
- https://docs.godotengine.org/en/4.x/classes/class_navigationagent3d.html

## 13. Networking architecture

Godot high-level multiplayer supports:
- ENet
- WebRTC
- WebSocket
- RPC authority modes
- reliable / unreliable / unreliable-ordered transfer
- multiple transfer channels
- per-node multiplayer authority

Aetherfall must be server-authoritative for important game state.

Client sends intent/input.
Server validates and owns:
- movement legality
- combat results
- damage/healing
- loot drops
- currency
- inventory mutations
- quests/progression
- trading
- gathering rewards
- crafting results

Use unreliable or unreliable-ordered transport for high-rate transient state where appropriate.
Use reliable transport for inventory, quests, economy, purchases, chat/system actions that cannot be dropped.
Separate traffic classes into channels so reliable chat/inventory traffic cannot unnecessarily block gameplay streams.

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_node.html

## 14. Replication and interest management

Godot MultiplayerSpawner can replicate authority-created nodes.
MultiplayerSynchronizer can synchronize properties and has visibility filtering APIs.

For an MMO-like game, visibility filtering is the foundation for interest management:
- only replicate nearby players/NPCs
- only replicate objects in the player's current zone/instance
- do not broadcast the entire world to every peer

Godot's high-level scene replication can be useful for prototypes/small zones, but Aetherfall should keep a clean abstraction so large-zone replication can be optimized or replaced later.

Docs:
- https://docs.godotengine.org/en/4.x/classes/class_multiplayerspawner.html
- https://docs.godotengine.org/en/latest/classes/class_multiplayersynchronizer.html

## 15. Dedicated servers

Godot 4 can export dedicated/headless server builds. Dedicated export can strip visual resources, reducing deployment size.

Aetherfall plan:
- client APK and server build are separate export targets
- gameplay authority runs headless
- server does not load unnecessary visuals/materials/textures
- automated CI should build and smoke-test both client and server targets

Docs:
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html

## 16. Persistence and account backend

Local Godot Resources/ResourceSaver are appropriate for offline/local configuration, not an MMO source of truth.

For persistent online state, use a server-side database/backend.

### Nakama
Current Nakama Godot 4 SDK supports:
- authentication
- accounts
- storage collections
- wallets
- friends/groups/chat
- leaderboards/tournaments
- real-time multiplayer
- authoritative matches
- server-side logic

Its Storage Engine supports JSON objects with ownership/permissions and can keep progression/economy writes authoritative.

This is currently the strongest all-in-one backend candidate for Aetherfall's early MMO prototype because it already has a maintained Godot 4 client path and server-side storage/economy primitives.

Docs:
- https://heroiclabs.com/docs/nakama/client-libraries/godot/index.html
- https://heroiclabs.com/docs/nakama/concepts/storage/
- https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/

### Colyseus
Colyseus is another current option:
- authoritative Node.js server
- room/matchmaking model
- delta state synchronization
- prediction/rollback/interpolation/lag compensation tools
- Godot client SDK

Its current Godot native extension is marked beta, so it is worth prototyping but carries more integration risk today.

Docs:
- https://docs.colyseus.io/
- https://docs.colyseus.io/getting-started/godot

### Agones
Agones is not a game backend by itself; it orchestrates fleets of dedicated game-server processes on Kubernetes.

It becomes relevant when Aetherfall needs:
- many zone/dungeon server processes
- fleet allocation
- autoscaling
- health checking
- multi-region server hosting

Do not adopt it at the first prototype stage; it adds Kubernetes operational complexity.

Docs:
- https://www.agones.dev/site/docs/
- https://www.agones.dev/site/docs/overview/

## 17. Quest and economy persistence

Important progression data must be transactionally/authoritatively changed on the server:
- inventory
- equipment
- currency
- quest state
- XP/level
- crafting inputs/outputs
- trade state
- auction listings
- dungeon lockouts
- loot ownership

Never trust the Android client to award itself items/currency.

Design persistence around immutable IDs and versioned schemas so content can change without corrupting old characters.

## 18. Instanced dungeons

Recommended architecture:
- persistent account/world service tracks party, inventory, quest and lockout state
- match/instance allocator creates dungeon instance
- players receive instance endpoint/id
- authoritative instance server runs combat/AI/loot
- on extraction/completion, results are validated and committed to persistent storage
- failed/disconnected instances must not duplicate rewards

This architecture also maps cleanly to future raids.

## 19. Shader/pipeline stutter

Godot Mobile/Forward+ can compile shader pipelines at runtime.
Precompile/warm the material/shader combinations used by character gear and common town assets to avoid first-use stutter.

Docs:
- https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html

## 20. Priority order for Aetherfall

### Now
1. Male peasant silhouette and garment topology
2. Weight transfer + manual deformation cleanup
3. Walk/run/extreme pose QA
4. UV unwrap
5. linen/wool/leather bake/material pass
6. export custom clothing metadata
7. Godot body/garment occlusion resolver
8. Android performance test

### Next
9. Female equivalent
10. Ranger/Knight/Mage modular gear for both bodies
11. Character LOD and distant-animation throttling
12. Vegetation MultiMesh/chunking
13. enterable interior occlusion/HLOD
14. NPC navigation tiers

### Before real MMO testing
15. dedicated Godot server build
16. server-authoritative movement/combat prototype
17. Nakama proof of concept for accounts + character persistence + inventory
18. interest management / zone replication
19. dungeon instance prototype
20. persistence/economy validation and anti-duplication tests

### Scale later
21. world streaming cells
22. social hubs and higher player density
23. server fleet orchestration / multi-region deployment
24. large-scale monitoring, load tests and autoscaling

## Core conclusion

The research reinforces the current direction: Aetherfall does not need one giant “MMO framework.” It needs clean separations between asset authoring, game client rendering, authoritative simulation, persistence, and server orchestration.

For the immediate character problem, the highest-value technical combination is:
authored garment geometry -> cloth-shaped rest silhouette -> deformation-aware retopology -> Data Transfer weights -> manual joint cleanup -> Preserve Volume where useful -> localized Corrective Smooth only where needed -> four walk poses + run stress test -> UV/bake -> glTF metadata -> Godot occlusion -> Android QA.
