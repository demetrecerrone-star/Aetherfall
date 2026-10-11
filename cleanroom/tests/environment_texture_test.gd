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
    # Regression: town furniture uses textured boards and tips its back
    # AWAY from the seated character, not inward as the original bench did.
    var benches := town.find_children("TownBench*", "Node3D", true, false)
    if benches.size() != 4:
        _fail("Expected four upgraded town benches")
        return
    for bench in benches:
        var seats := bench.find_children("BenchSeatSlat*", "MeshInstance3D", false, false)
        var backs := bench.find_children("BenchBackSlat*", "MeshInstance3D", false, false)
        if seats.size() != 3 or backs.size() != 3:
            _fail("Bench has missing individual wooden slats")
            return
        var low: MeshInstance3D = backs[0]
        var high: MeshInstance3D = backs[2]
        if low.rotation_degrees.x < 8.0 or low.rotation_degrees.x > 12.0:
            _fail("Bench back is angled inward rather than out for lumbar comfort")
            return
        if high.position.z <= low.position.z:
            _fail("Bench back top does not lean away from its seat")
            return
        for board in [seats[0], backs[0]]:
            var wood_mat := (board as MeshInstance3D).material_override as StandardMaterial3D
            if wood_mat == null or wood_mat.albedo_texture == null:
                _fail("Bench wood-grain texture was not applied")
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
        var yaw := absf((market_stall as Node3D).rotation_degrees.y)
        if absf(yaw - 45.0) > 0.1 and absf(yaw - 135.0) > 0.1:
            _fail("Marketplace stall does not face inward diagonally")
            return

    # Dense instanced grass, not 14 disconnected tufts, on lawn only.
    var grass_count: int = town.get_meta("grass_instance_count", 0)
    var chunk_count: int = town.get_meta("grass_chunk_count", 0)
    if grass_count < 3000 or chunk_count < 20 or chunk_count > 64:
        _fail("Missing dense, chunked mobile grass: %d instances / %d batches" % [grass_count, chunk_count])
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

    print("AETHERFALL_ENVIRONMENT_02Y_OK: Four diagonal market stands, central browsing loop, zero stale stairs, and dense batched grass")
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
