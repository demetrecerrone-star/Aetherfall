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
        _fail("Grass texture is missing")
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
    if town.find_child("UnifiedDirtRoadVerge", true, false) == null:
        _fail("Cobblestones end abruptly without a dirt/grass transition")
        return
    if int(town.get_meta("road_paving_quad_count", 0)) > 1300:
        _fail("Too many paving meshes for mobile; consolidate road tiles")
        return
    if int(town.get_meta("road_network_segments", 0)) < 30:
        _fail("Not all town doorways have cobbled path branches")
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
    var flowering := town.find_child("Quaternius_Bush_Flowers", true, false)
    if flowering == null:
        _fail("Flowering foliage was not imported")
        return
    var shrub_root := flowering.get_parent() as Node3D
    if shrub_root == null or not bool(shrub_root.get_meta("grounded", false)):
        _fail("Imported shrub has no ground attachment marker")
        return
    if float(shrub_root.get_meta("scenery_ground_sink", 0.0)) < 0.25:
        _fail("Imported shrub is still too high above the grass")
        return
    var bush_meshes := flowering.find_children("*", "MeshInstance3D", true, false)
    if bush_meshes.is_empty():
        _fail("Flowering bush has no mesh")
        return
    var bush_mesh := bush_meshes[0] as MeshInstance3D
    if bush_mesh == null:
        _fail("Flowering bush has no mesh")
        return
    var bush_material := bush_mesh.get_active_material(0) as StandardMaterial3D
    if bush_material == null or bush_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
        _fail("See-through bush blend mode was not fixed")
        return
    if bush_material.cull_mode != BaseMaterial3D.CULL_DISABLED:
        _fail("Foliage leaf cards are still one-sided")
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
    if String(town.get_meta("grass_style", "")) != "dense_short_yard_grass":
        _fail("Grass must be lawn-length, not tall scattered spikes")
        return
    if float(town.get_meta("grass_spacing_m", 1.0)) > 0.26:
        _fail("Grass spacing is too sparse for a believable lawn")
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

    print("AETHERFALL_ENVIRONMENT_PASS3_OK: One medieval cobble road network, all 10 doorways connected, dirt verges, thick yard lawn and inward-backed stalls")
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
