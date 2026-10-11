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

    # Water now uses several narrow, physically lit strands rather than one
    # emissive flat panel. Drops are smaller and stretched by gravity.
    if town.find_child("FountainJet", true, false) != null:
        _fail("Old fountain water rods are still present")
        return
    var sheets := town.find_children("FountainCascade*", "MeshInstance3D", true, false)
    var droplets := town.find_children("FountainDroplet*", "MeshInstance3D", true, false)
    var fake_rings := town.find_children("FountainRipple*", "MeshInstance3D", true, false)
    if sheets.size() != 8 or droplets.size() != 24 or fake_rings.size() != 0:
        _fail("Expected eight strand groups, 24 small falling droplets and no flat ripple decals")
        return
    for flow in sheets:
        var visual := flow as MeshInstance3D
        var stream_mat := visual.material_override as StandardMaterial3D
        var flow_vertices: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        var flow_colors: PackedColorArray = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
        if flow_vertices.size() < 400 or flow_colors.size() != flow_vertices.size():
            _fail("Fountain returned to broad panels instead of separate shaded filaments")
            return
        if stream_mat == null or not stream_mat.vertex_color_use_as_albedo or stream_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
            _fail("Flowing water is not softly shaded and varied along each filament")
            return
    var small_drop := droplets[0] as MeshInstance3D
    var drop_mesh := small_drop.mesh as SphereMesh
    if drop_mesh == null or drop_mesh.radius > 0.016 or drop_mesh.height < 0.045:
        _fail("Fountain droplets are still oversized round beads")
        return

    # Real impact ripples displace a densely tessellated circular water surface.
    # They originate below eight falling streams, not from a scrolling decal.
    var pool := town.find_child("FountainWater", true, false) as MeshInstance3D
    if pool == null:
        _fail("Fountain basin surface missing")
        return
    var water_mat := pool.material_override as ShaderMaterial
    var pool_mesh := pool.mesh as ArrayMesh
    if water_mat == null or pool_mesh == null or water_mat.shader == null:
        _fail("Fountain basin is missing animated impact-wave geometry")
        return
    var mesh_vertices: PackedVector3Array = pool_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if mesh_vertices.size() < 2000:
        _fail("Water surface does not have enough geometry for actual ripple displacement")
        return
    var shader_code := water_mat.shader.code
    if not shader_code.contains("VERTEX.y +=") or not shader_code.contains("impact"):
        _fail("Water surface ripples are not driven by droplet impact positions")
        return
    var initial_time := float(water_mat.get_shader_parameter("flow_time"))
    town.call("_update_fountain", 0.30)
    var next_time := float(water_mat.get_shader_parameter("flow_time"))
    if next_time < initial_time + 0.29:
        _fail("Physical fountain waves are not moving")
        return

    # The upper disk top is y=2.37 with a radius of 0.38m. Streams must
    # spill over its outer lip and land inside the basin outside the column.
    var disk_start: Vector3 = town.call("_fountain_flow_point", 0.0, 0.0, 0)
    var stream_end: Vector3 = town.call("_fountain_flow_point", 0.0, 1.0, 0)
    var start_radius := Vector2(disk_start.x, disk_start.z + 4.0).length()
    var end_radius := Vector2(stream_end.x, stream_end.z + 4.0).length()
    if absf(start_radius - 0.395) > 0.01 or absf(disk_start.y - 2.375) > 0.015:
        _fail("Fountain flow no longer begins at the raised disk rim")
        return
    if end_radius < 0.78 or end_radius > 0.86 or absf(stream_end.y - 1.035) > 0.01:
        _fail("Fountain runoff does not land inside the basin away from the column")
        return
    var first_vertices: PackedVector3Array = (sheets[0] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if first_vertices[0].y < 2.36 or first_vertices[56].y > 1.05:
        _fail("Fountain stream filaments no longer span disk to basin")
        return

    print("AETHERFALL_ENVIRONMENT_02T_OK: Seam-free textured lawn, unified cobbles, triplanar fountain, tiled roofs, textured stall posts and three ground heights")
    town.queue_free()
    quit(0)


func _fail(message: String) -> void:
    push_error("AETHERFALL_ENVIRONMENT_FAIL: " + message)
    quit(1)
