extends SceneTree
## Verify texture material settings and visible road heights, while preserving character model behavior.
func _initialize() -> void:
    call_deferred("_run_check")


func _run_check() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Scene was not found")
        return
    var town := scene.instantiate()
    root.add_child(town)
    for i in range(8):
        await process_frame
    var grass := town.find_child("TownGround", true, false) as MeshInstance3D
    var road := town.find_child("UnifiedCobblestoneRoad", true, false) as MeshInstance3D
    var roof := town.find_child("RoofCourse", true, false) as MeshInstance3D
    var stall_post := town.find_child("StallPost", true, false) as MeshInstance3D
    if grass == null or road == null or roof == null or stall_post == null:
        _fail("Expected environment meshes are missing")
        return
    var grass_material := grass.material_override as StandardMaterial3D
    var post_material := stall_post.material_override as StandardMaterial3D
    if grass_material == null or grass_material.albedo_texture == null:
        _fail("Meadow ground needs a textured soil material")
        return
    if String(town.get_meta("town_ground_material", "")) != "textured_warm_brown_soil":
        _fail("Meadow is still built on artificial grass/olive ground")
        return
    if String(town.call("_town_texture_group", "TownGround")) != "dirt":
        _fail("Exposed meadow floor is not using the earthy dirt texture")
        return
    var soil_tint: Color = grass_material.albedo_color
    if not (soil_tint.r > soil_tint.g * 1.12 and soil_tint.g > soil_tint.b * 1.12 and soil_tint.r < 0.65):
        _fail("Exposed soil is too pale or green; expected deep warm brown")
        return
    if post_material == null or post_material.albedo_texture == null:
        _fail("Stall posts have no wood texture")
        return
    if town.find_child("EntryRoad", true, false) != null or town.find_child("CrossRoad", true, false) != null or town.find_child("MarketSquare", true, false) != null:
        _fail("Three old overlapping paving slabs were not retired")
        return
    if town.find_child("RoadStone", true, false) != null or town.find_child("SquareStone", true, false) != null:
        _fail("Legacy per-block road stones returned")
        return
    if town.find_child("GrassPatch", true, false) != null:
        _fail("Raised circular grass patches returned and will leave visible edges")
        return
    var entry := float(town.call("_ground_surface_y", Vector3(0, 0, 18)))
    var cross := float(town.call("_ground_surface_y", Vector3(12, 0, 1)))
    var square := float(town.call("_ground_surface_y", Vector3(0, 0, -4)))
    if absf(entry - 0.066) > 0.001 or absf(cross - 0.066) > 0.001 or absf(square - 0.066) > 0.001:
        _fail("Continuous roads/plaza have mismatched player footing: %f %f %f" % [entry, cross, square])
        return
    if String(town.get_meta("road_style", "")) != "weathered_medieval_cobblestone":
        _fail("Town road is not the approved weathered medieval cobblestone")
        return
    var cobbled := road.mesh.surface_get_material(0) as StandardMaterial3D
    if cobbled == null or cobbled.albedo_texture == null:
        _fail("Unified medieval road lacks the imported Poly Haven cobble texture")
        return
    if cobbled.cull_mode != BaseMaterial3D.CULL_DISABLED:
        _fail("Cobble paving may disappear from the overhead player camera due to face culling")
        return
    var stone_vertices: PackedVector3Array = road.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if stone_vertices.size() < 6 or absf(stone_vertices[0].y - 0.066) > 0.002:
        _fail("Town paving has no visible raised cobblestone surface")
        return
    var verge_mesh := town.find_child("UnifiedDirtRoadVerge", true, false) as MeshInstance3D
    if verge_mesh == null or verge_mesh.mesh == null:
        _fail("Road verge mesh disappeared")
        return
    var verge_material := verge_mesh.mesh.surface_get_material(0) as StandardMaterial3D
    if verge_material == null or verge_material.cull_mode != BaseMaterial3D.CULL_DISABLED:
        _fail("Dirt transition is at risk of back-face culling")
        return
    if verge_material.albedo_texture == null:
        _fail("Road verges are not textured earth")
        return
    var verge_tint: Color = verge_material.albedo_color
    if not (verge_tint.r > verge_tint.g and verge_tint.g > verge_tint.b):
        _fail("Roadside soil must be warm brown, not grey or green")
        return
    if town.find_child("UnifiedDirtRoadVerge", true, false) == null:
        _fail("Cobblestones end abruptly without a dirt/grass transition")
        return
    if int(town.get_meta("road_paving_quad_count", 0)) > 1300:
        _fail("Too many paving meshes for mobile; consolidate road tiles")
        return
    if int(town.get_meta("road_network_segments", 0)) < 30:
        _fail("Not all town doorways have cobbled path branches")
        return
    var lanes: Array = town.get("_road_regions")
    if lanes.size() < 3:
        _fail("Primary and secondary village roads are missing")
        return
    if absf((lanes[0] as Rect2).size.x - 5.90) > 0.01 or absf((lanes[1] as Rect2).size.y - 4.25) > 0.01:
        _fail("Main gate road must stay wide; secondary road should narrow only moderately")
        return
    var route_points: Array = town.get("_road_door_anchors")
    if route_points.size() != 10:
        _fail("The road network did not connect all ten house and shop doorways")
        return
    for door_point in route_points:
        var door: Vector2 = door_point
        var foot_height := float(town.call("_ground_surface_y", Vector3(door.x, 0.0, door.y)))
        if absf(foot_height - 0.066) > 0.001:
            _fail("Path does not reach a building entrance: " + str(door))
            return
    if absf(float(town.call("_ground_surface_y", Vector3(-24.0, 0.0, 8.0)))) > 0.001:
        _fail("Cobble road replaced the lawn outside defined streets")
        return
    # These are rustic trestle benches, never the old three-slat modern seats.
    var benches := town.find_children("TownBench*", "Node3D", true, false)
    if benches.size() != 2:
        _fail("Expected two rustic benches only; entrance-side lawn benches should be removed")
        return
    for bench in benches:
        if (bench as Node3D).position.z > -8.0:
            _fail("Gate-side stray bench remains in the town")
            return
        if absf((bench as Node3D).scale.y - 0.64) > 0.015:
            _fail("Bench is still oversized / waist-high")
            return
        var seat_top: float = bench.get_meta("seat_top_m", -1.0)
        if seat_top < 0.47 or seat_top > 0.60:
            _fail("Bench seat must be realistic knee height; got %f metres" % seat_top)
            return
        if String(bench.get_meta("bench_style", "")) != "medieval_trestle":
            _fail("Town furniture reverted to the modern bench")
            return
        var seat := bench.get_node_or_null("SolidOakSeat") as MeshInstance3D
        var back := bench.get_node_or_null("BackBeam") as MeshInstance3D
        var foot := bench.get_node_or_null("CarvedTrestleFoot") as MeshInstance3D
        if seat == null or back == null or foot == null:
            _fail("Medieval oak bench lost its trestle construction")
            return
        if back.rotation_degrees.x < 5.0:
            _fail("Medieval bench lost the angled backrest")
            return
        var material := seat.material_override as StandardMaterial3D
        if material == null or material.albedo_texture == null:
            _fail("The medieval bench has no real wood-grain texture")
            return
    var lamps := town.find_children("MedievalStreetLamp*", "Node3D", true, false)
    if lamps.size() != 4:
        _fail("Expected four medieval street lanterns")
        return
    for lamp in lamps:
        if String(lamp.get_meta("lamp_style", "")) != "medieval_oak_and_lantern":
            _fail("A modern thin street light returned")
            return
        if not bool(lamp.get_meta("lantern_asset_loaded", false)):
            _fail("Quaternius hanging lantern failed to import into its mast")
            return
        if lamp.get_node_or_null("OakLampMast") == null:
            _fail("Medieval lamp missing heavy oak column")
            return
    var native_nature: bool = town.get_meta("nature_pack_loaded", false)
    # No bright red flowering bushes and no old 3D sphere-on-stick blooms.
    if not town.find_children("FlowerHead*", "MeshInstance3D", true, false).is_empty():
        _fail("Prototype spherical flower heads remain in the starter town")
        return
    if not town.find_children("FlowerStem*", "MeshInstance3D", true, false).is_empty():
        _fail("Prototype box flower stems remain in the starter town")
        return
    if not town.find_children("TownFlowerBush_*", "Node3D", true, false).is_empty():
        _fail("Old reddish bushes are still planted")
        return
    if not town.find_children("QuaterniusNature_Bush_Common_Flowers", "Node3D", true, false).is_empty():
        _fail("Flower-coloured bush asset was not replaced by plain green foliage")
        return
    var plain_bushes := town.find_children("TownGreenBush_*", "Node3D", true, false)
    if plain_bushes.size() < 2:
        _fail("Additional green-rounded bush variety is missing")
        return
    for bush in plain_bushes:
        if not bool((bush as Node3D).get_meta("green_bush_only", false)):
            _fail("Rounded bushes must use the green-only palette")
            return
        if native_nature and (bush as Node3D).find_children("QuaterniusNature_Bush_Common", "Node3D", true, false).is_empty():
            _fail("Green bush failed to import its genuine foliage model")
            return
    var all_shrubs := town.find_children("TownHedge_*", "Node3D", true, false)
    all_shrubs.append_array(plain_bushes)
    if all_shrubs.size() < 10:
        _fail("Additional green hedges and bushes were not installed")
        return
    for plant in all_shrubs:
        var root_plant := plant as Node3D
        if not bool(root_plant.get_meta("planted_in_lawn", false)):
            _fail("Ornamental bush was not planted in a grass bed")
            return
        var is_round := root_plant.name.begins_with("TownGreenBush")
        if not bool(town.call("_shrub_fits_lawn", root_plant.position, 0.9, is_round)):
            _fail("A bush overlaps the road or dirt verge: " + root_plant.name)
            return
    var wildflowers := town.find_children("WildflowerPatch_*", "Node3D", true, false)
    if wildflowers.size() < 12:
        _fail("Not enough imported wildflower clusters were planted in the lawn")
        return
    for bloom in wildflowers:
        var flower_root := bloom as Node3D
        if not bool(flower_root.get_meta("planted_in_lawn", false)):
            _fail("Wildflowers are not grounded in grass")
            return
        if not bool(town.call("_flower_patch_fits_lawn", flower_root.position, 0.45)):
            _fail("Wildflower cluster overlaps cobblestones or a doorway")
            return
        var source: String = flower_root.get_meta("flower_group_asset", "")
        if source != "Flower_3_Group" and source != "Flower_4_Group":
            _fail("Prototype or unknown flower model has returned")
            return
        if native_nature and flower_root.find_children("QuaterniusNature_Flower_*", "Node3D", true, false).is_empty():
            _fail("Real Quaternius wildflower geometry failed to import")
            return

    var hedges := town.find_children("TownHedge_*", "Node3D", true, false)
    if hedges.size() < 5:
        _fail("Too few muted rectangular hedges were placed")
        return
    for hedge in hedges:
        var dimensions: Vector3 = (hedge as Node3D).get_meta("hedge_dimensions", Vector3.ZERO)
        if dimensions.y < 0.90 or dimensions.y > 1.20 or dimensions.x < 1.60:
            _fail("Trimmed hedge must be broad and about hip-high")
            return
        if (hedge as Node3D).get_node_or_null("HedgeLeafBody") == null:
            _fail("Trimmed hedge lost its rectangular foliage mesh")
            return
        if native_nature:
            if not bool((hedge as Node3D).get_meta("nature_hedge_imported", false)):
                _fail("Hip-height hedges must contain textured Nature MegaKit segments")
                return
            if (hedge as Node3D).find_children("QuaterniusNature_Bush_Common", "Node3D", true, false).size() != 2:
                _fail("Textured hedge requires two natural overlapping bush segments")
                return
    var pines := town.find_children("PineTree_*", "Node3D", true, false)
    if pines.size() < 3:
        _fail("Not enough taller pine trees were added to the valley")
        return
    var tallest := 0.0
    for pine in pines:
        tallest = maxf(tallest, float((pine as Node3D).get_meta("tree_height_m", 0.0)))
        if native_nature:
            if String((pine as Node3D).get_meta("foliage_style", "")) != "textured_nature_pine":
                _fail("Pine still uses procedural cones instead of Quaternius foliage")
                return
            if (pine as Node3D).find_children("QuaterniusNature_Pine_*", "Node3D", true, false).is_empty():
                _fail("Pine has no imported textured mesh")
                return
        elif (pine as Node3D).find_children("PineEvergreenLayer_*", "MeshInstance3D", true, false).size() != 5:
            _fail("Procedural pine fallback lost its canopy")
            return
    if tallest < 6.6:
        _fail("None of the pines is taller than the deciduous trees")
        return
    var deciduous := town.find_children("BroadleafTree_*", "Node3D", true, false)
    if deciduous.size() < 5:
        _fail("Deciduous maple/birch variety was lost")
        return
    for tree in deciduous:
        if not bool((tree as Node3D).get_meta("tree_leaf_cutout_fixed", false)):
            _fail("Imported tree leaves still have see-through blended materials")
            return

    # Pass 3: the old flat rectangular stone box is gone.
    if town.find_child("TownWall", true, false) != null:
        _fail("The old rectangular stone perimeter is still rendered")
        return
    var cliffs := town.find_children("ValleyCliffs_*", "MeshInstance3D", true, false)
    if cliffs.size() != 3:
        _fail("Mountain valley needs north/west/east rocky cliff silhouettes")
        return
    var stockade := town.get_node_or_null("ValleyTimberPalisade") as MultiMeshInstance3D
    var pointed := town.get_node_or_null("ValleyTimberPointedTips") as MultiMeshInstance3D
    if stockade == null or pointed == null:
        _fail("Timber palisade mesh and opaque pointed logs are required")
        return
    if stockade.multimesh == null or pointed.multimesh == null:
        _fail("Timber wall has no batched mesh")
        return
    if stockade.multimesh.instance_count < 300 or stockade.multimesh.instance_count != pointed.multimesh.instance_count:
        _fail("The perimeter timber wall contains gaps")
        return
    if stockade.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
        _fail("Palisade shadows are too expensive for Android")
        return
    if town.get_meta("perimeter_style", "") != "mountain_valley_timber_palisade":
        _fail("The approved mountain valley has not replaced the boxed walls")
        return
    if not bool(town.get_meta("main_gate_permanently_closed", false)):
        _fail("Town gate must remain permanently closed")
        return
    var gate_leaves := town.find_children("ClosedWoodGateLeaf*", "MeshInstance3D", true, false)
    if gate_leaves.size() != 2:
        _fail("Gate has transparent gaps or lacks its two solid wooden leaves")
        return
    if town.find_child("GateBar", true, false) != null:
        _fail("See-through portcullis remains")
        return
    var transfer := town.get_node_or_null("AetherfallZoneTransfer")
    if transfer == null or transfer.get_node_or_null("ZonePreviewNotice") == null:
        _fail("Closed gate has no Iruna-style area loading / next-zone system")
        return
    if transfer.get_node_or_null("AreaLoadingOverlay") == null:
        _fail("Dedicated regional loading-screen overlay is missing")
        return
    if not String(town.get_meta("gate_destination_scene", "")).begins_with("res://areas/"):
        _fail("Future area path not configured at town gate")
        return

    # Former fountain square now hosts additional market stands, with a clear aisle.
    if not town.find_children("Fountain*", "Node", true, false).is_empty():
        _fail("Removed fountain geometry returned")
        return
    var stalls := town.find_children("MarketStall_*", "Node3D", true, false)
    if stalls.size() != 4:
        _fail("Expected four market stands")
        return
    if bool(town.call("_world_point_blocked", Vector2(0.0, -4.0))):
        _fail("Former fountain position still blocks the market aisle")
        return
    for stall_pos in [Vector2(-5.4, -6.1), Vector2(5.4, -6.1), Vector2(-5.4, 2.45), Vector2(5.4, 2.45)]:
        if not bool(town.call("_world_point_blocked", stall_pos)):
            _fail("Diagonal stall has no counter collision: " + str(stall_pos))
            return
    for spot in [Vector2(0, -1.8), Vector2(0, -6.1), Vector2(0, 2.45), Vector2(-2.0, -2.0), Vector2(2.0, -2.0)]:
        if bool(town.call("_world_point_blocked", spot)):
            _fail("Marketplace loop is blocked at " + str(spot))
            return
    for market_stall in stalls:
        var stand := market_stall as Node3D
        if String(stand.get_meta("vendor_stall_style", "")) != "backed_awning":
            _fail("One of the stands reverted to the open-sided market model")
            return
        if stand.get_node_or_null("Quaternius_MarketStand_1") == null:
            _fail("All four stalls must use the backed MarketStand_1 model")
            return
        if stand.get_node_or_null("Quaternius_MarketStand_2") != null:
            _fail("The unwanted alternative market stand is still present")
            return
        var expected_yaw := 45.0 if stand.position.x < 0.0 else -45.0
        if stand.position.z > 0.0:
            expected_yaw = 135.0 if stand.position.x < 0.0 else -135.0
        if absf(stand.rotation_degrees.y - expected_yaw) > 0.1:
            _fail("Market stand does not face center of square: " + str(stand.position))
            return
    # Gate-side House_4 is a low one-story source model and must never
    # be stretched to the height of a cathedral-like door again.
    var scaled_single_story := 0
    for house in town.find_children("House*", "Node3D", true, false):
        if String(house.get_meta("scenery_asset", "")) != "House_4":
            continue
        scaled_single_story += 1
        var model_size: Vector3 = house.get_meta("scenery_model_size", Vector3.ZERO)
        var stretch_ratio: float = house.get_meta("scenery_height_stretch_ratio", 1.0)
        if model_size.y > 3.9 or stretch_ratio > 0.70:
            _fail("Single-story building and door have been stretched too tall")
            return
    if scaled_single_story < 2:
        _fail("Expected some short House_4 cottages near the gate")
        return

    # Dense instanced grass, not 14 disconnected tufts, on lawn only.
    var grass_count: int = town.get_meta("grass_instance_count", 0)
    var chunk_count: int = town.get_meta("grass_chunk_count", 0)
    if grass_count < 9000 or chunk_count < 20 or chunk_count > 64:
        _fail("Missing thick lawn coverage: %d instances / %d batches" % [grass_count, chunk_count])
        return
    var expected_grass_style := "quaternius_mixed_fantasy_meadow" if native_nature else "soft_curved_meadow_grass"
    if String(town.get_meta("grass_style", "")) != expected_grass_style:
        _fail("Wrong grass style for selected vegetation assets: " + expected_grass_style)
        return
    if bool(town.get_meta("grass_nature_model_loaded", false)) != native_nature:
        _fail("Grass asset presence does not match the installed nature pack")
        return
    var grass_batches := town.find_children("GrassField_*", "MultiMeshInstance3D", true, false)
    if grass_batches.is_empty():
        _fail("No instanced grass batches were generated")
        return
    var grass_multimesh := (grass_batches[0] as MultiMeshInstance3D).multimesh
    if grass_multimesh == null or grass_multimesh.mesh == null:
        _fail("Instanced grass lost its blade mesh")
        return
    var tuft := grass_multimesh.mesh as ArrayMesh
    if tuft == null or tuft.get_faces().size() < 30:
        _fail("New grass tuft is still the old four straight triangles")
        return
    if tuft.get_faces().size() > (600 if native_nature else 75):
        _fail("Grass tuft exceeds its mobile-poly budget")
        return
    if native_nature:
        var species: Array = town.get_meta("grass_species_counts", [])
        if species.size() != 4:
            _fail("Common grass, wispy grass, clover and ferns were not all registered")
            return
        if int(species[0]) < 7500 or int(species[1]) < 700 or int(species[2]) < 200 or int(species[3]) < 1:
            _fail("Organic grass species did not reach natural-looking mix: " + str(species))
            return
        if town.find_children("MeadowAccent_*", "MultiMeshInstance3D", true, false).size() < 10:
            _fail("Grass accents are not instanced as mobile-friendly MultiMesh batches")
            return
        if int(town.get_meta("grass_draw_batches", 0)) > 190:
            _fail("Meadow uses too many separate draw batches for Android")
            return
    if float(town.get_meta("grass_spacing_m", 1.0)) > 0.205:
        _fail("Latest grass pass reverted to sparse planting")
        return
    if String(town.get_meta("grass_coverage_pass", "")) != "dense_foundation_edges":
        _fail("Dense ground/foundation grass pass not activated")
        return
    if grass_count < 12500:
        _fail("Grass density upgrade produced too few lawn tufts: " + str(grass_count))
        return
    # Player clearance is broad, but grass should get almost to the house
    # foundation. Confirm some lawn positions exist inside the player's
    # padded obstruction halo without allowing grass through solid masonry.
    var found_close_grass := false
    var house_blocks: Array = town.get("_house_blockers")
    for house in house_blocks:
        var center: Vector2 = house["center"]
        var padded: Vector2 = house["half"]
        for side in [-1.0, 1.0]:
            for distance in [0.15, 0.22]:
                var probe := Vector2(center.x + float(side) * (padded.x - float(distance)), center.y)
                if float(town.call("_ground_surface_y", Vector3(probe.x, 0.0, probe.y))) < 0.011:
                    if bool(town.call("_world_point_blocked", probe)) and not bool(town.call("_grass_point_blocked", probe)):
                        found_close_grass = true
                        break
            if found_close_grass:
                break
        if found_close_grass:
            break
    if not found_close_grass:
        _fail("Grass still obeys the player's oversized building collision radius")
        return
    var chunk := town.find_child("GrassField_*", true, false) as MultiMeshInstance3D
    if chunk == null or chunk.multimesh == null:
        _fail("Dense grass was not batched into MultiMesh rendering")
        return
    if chunk.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
        _fail("Mobile grass still casts expensive shadows")
        return
    if not town.find_children("DoorStep*", "Node", true, false).is_empty():
        _fail("Obsolete procedural stairs remain in town")
        return

    print("AETHERFALL_ENVIRONMENT_PASS3_OK: Stone road network, 10 doorways, and " + ("real MegaKit trees/hedges/grass" if native_nature else "safe temporary foliage fallbacks"))
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
