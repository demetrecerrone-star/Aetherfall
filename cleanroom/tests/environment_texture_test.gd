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
    var fountain := town.find_child("FountainPlinth", true, false) as MeshInstance3D
    var grass := town.find_child("TownGround", true, false) as MeshInstance3D
    var road := town.find_child("EntryRoad", true, false) as MeshInstance3D
    var roof := town.find_child("RoofCourse", true, false) as MeshInstance3D
    var stall_post := town.find_child("StallPost", true, false) as MeshInstance3D
    if fountain == null or grass == null or road == null or roof == null or stall_post == null:
        _fail("Expected environment meshes are missing")
        return
    var fountain_material := fountain.material_override as StandardMaterial3D
    var grass_material := grass.material_override as StandardMaterial3D
    var post_material := stall_post.material_override as StandardMaterial3D
    if fountain_material == null or not fountain_material.uv1_triplanar:
        _fail("Fountain stone is not triplanar mapped")
        return
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

    # Flowing water sheets, little beads, and wave-textured basin should replace
    # the old rigid angled FountainJet cylinders.
    if town.find_child("FountainJet", true, false) != null:
        _fail("Old rigid fountain water rods are still present")
        return
    var sheets := town.find_children("FountainCascade*", "MeshInstance3D", true, false)
    var droplets := town.find_children("FountainDroplet*", "MeshInstance3D", true, false)
    var rings := town.find_children("FountainRipple*", "MeshInstance3D", true, false)
    if sheets.size() != 8 or droplets.size() != 16 or rings.size() != 8:
        _fail("Water cascade, droplets, or landing-point ripple rings missing")
        return
    var pool := town.find_child("FountainWater", true, false) as MeshInstance3D
    if pool == null:
        _fail("Fountain basin surface missing")
        return
    var water_mat := pool.material_override as StandardMaterial3D
    if water_mat == null or water_mat.albedo_texture == null:
        _fail("Basin needs its procedural wave texture")
        return
    var prior_uv := water_mat.uv1_offset
    var ripple := rings[0] as MeshInstance3D
    var prior_scale := ripple.scale.x
    town.call("_update_fountain", 0.30)
    if water_mat.uv1_offset.distance_to(prior_uv) < 0.0001:
        _fail("Wave texture is not moving")
        return
    if absf(ripple.scale.x - prior_scale) < 0.0001:
        _fail("Ripple ring does not expand across the water")
        return
    for ring in rings:
        var ring_visual := ring as MeshInstance3D
        if Vector2(ring_visual.position.x, ring_visual.position.z + 4.0).length() > 0.90:
            _fail("Ripple center is not close to the falling water")
            return

    # The upper disk top is y=2.37 with a radius of 0.38m. Streams must
    # actually spill from its outer lip and land OUTSIDE the central column.
    var disk_start: Vector3 = town.call("_fountain_flow_point", 0.0, 0.0, 0)
    var stream_end: Vector3 = town.call("_fountain_flow_point", 0.0, 1.0, 0)
    var start_radius := Vector2(disk_start.x, disk_start.z + 4.0).length()
    var end_radius := Vector2(stream_end.x, stream_end.z + 4.0).length()
    if absf(start_radius - 0.395) > 0.01 or absf(disk_start.y - 2.375) > 0.015:
        _fail("Fountain flow no longer begins at the raised disk's outer rim")
        return
    if end_radius < 0.78 or end_radius > 0.86 or absf(stream_end.y - 1.035) > 0.01:
        _fail("Fountain runoff does not fall into the basin away from the column")
        return
    var cascade_vertices: PackedVector3Array = (sheets[0] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if cascade_vertices.size() < 50:
        _fail("Fountain sheets have lost their smooth falling curves")
        return
    if cascade_vertices[0].y < 2.36 or cascade_vertices[cascade_vertices.size() - 1].y > 1.05:
        _fail("Fountain sheets no longer span disk lip to basin")
        return
    var ripple_mesh: ArrayMesh = (rings[0] as MeshInstance3D).mesh as ArrayMesh
    var ripple_arrays: Array = ripple_mesh.surface_get_arrays(0)
    var ripple_vertices: PackedVector3Array = ripple_arrays[Mesh.ARRAY_VERTEX]
    var ripple_colors: PackedColorArray = ripple_arrays[Mesh.ARRAY_COLOR]
    if ripple_vertices.size() < 400 or ripple_colors.size() != ripple_vertices.size():
        _fail("Impact ripple still has coarse triangular geometry or no feathered vertex alpha")
        return
    var fade_mat := (rings[0] as MeshInstance3D).material_override as StandardMaterial3D
    if fade_mat == null or not fade_mat.vertex_color_use_as_albedo:
        _fail("Impact ripple has lost smooth transparent feathering")
        return
    for i in range(rings.size()):
        var ring_position: Vector3 = (rings[i] as MeshInstance3D).position
        var expected: Vector3 = town.call("_fountain_flow_point", TAU * float(i) / 8.0, 1.0, i)
        if ring_position.distance_to(expected) > 0.015:
            _fail("Ripple does not match cascade water impact number " + str(i))
            return

    print("AETHERFALL_ENVIRONMENT_02T_OK: Seam-free textured lawn, unified cobbles, triplanar fountain, tiled roofs, textured stall posts and three ground heights")
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
