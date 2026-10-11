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
    var road := town.find_child("EntryRoad", true, false) as MeshInstance3D
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
    if town.find_child("RoadStone", true, false) != null or town.find_child("SquareStone", true, false) != null:
        _fail("Old oversized road slabs are still visible")
        return
    if town.find_child("GrassPatch", true, false) != null:
        _fail("Raised circular grass patches returned and will leave visible edges")
        return
    var entry := float(town.call("_ground_surface_y", Vector3(0, 0, 18)))
    var cross := float(town.call("_ground_surface_y", Vector3(12, 0, 1)))
    var square := float(town.call("_ground_surface_y", Vector3(0, 0, -4)))
    if absf(entry - 0.055) > 0.001 or absf(cross - 0.067) > 0.001 or absf(square - 0.079) > 0.001:
        _fail("Foot grounding no longer matches paved surfaces: %f %f %f" % [entry, cross, square])
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

    # Regression: broad striped wall faces must have stone at normal scale,
    # not BoxMesh facade UVs stretched from their thin axis.
    # Godot renames duplicate generic nodes when they share a parent. Every
    # wall is created by _add_wall_segment with the same TownWall material.
    var wall := town.find_child("TownWall", true, false) as MeshInstance3D
    if wall == null:
        _fail("Missing perimeter stone wall")
        return
    var wall_mat := wall.material_override as StandardMaterial3D
    if wall_mat == null or wall_mat.albedo_texture == null or not wall_mat.uv1_triplanar:
        _fail("Town wall faces need properly projected stone, not stretched stripes")
        return
    if absf(wall_mat.uv1_scale.x - wall_mat.uv1_scale.y) > 0.01 or absf(wall_mat.uv1_scale.y - wall_mat.uv1_scale.z) > 0.01:
        _fail("Wall texture scaling is not uniform on all facade faces")
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

    print("AETHERFALL_ENVIRONMENT_PASS1_OK: Four inward-backed stalls, two properly sized benches, natural gate-side doors, thick mobile lawn")
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
