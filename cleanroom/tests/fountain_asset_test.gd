extends SceneTree
## QA the genuine, user-supplied fountain mesh and its town collision.
const FOUNTAIN_PATH := "res://models/fountain/MedievalFountain.bin"
const NatureReplacement = preload("res://nature_replacements.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    if not FileAccess.file_exists(FOUNTAIN_PATH):
        _fail("Exact fountain GLB bytes were not included in runtime resources")
        return
    var file_data := FileAccess.get_file_as_bytes(FOUNTAIN_PATH)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var import_status := doc.append_from_buffer(file_data, "", state)
    if import_status != OK:
        _fail("User fountain runtime GLB cannot be parsed: " + str(import_status))
        return
    var model := doc.generate_scene(state) as Node3D
    if model == null:
        _fail("Imported 3D fountain has no renderable root")
        return
    root.add_child(model)
    var bounds: AABB = NatureReplacement._bounds(model)
    if bounds.size.x < 0.8 or bounds.size.x > 1.15:
        _fail("Unexpected fountain GLB width: " + str(bounds.size))
        return
    if bounds.size.y < 0.70 or bounds.size.y > 0.95:
        _fail("Unexpected two-tier fountain GLB height: " + str(bounds.size))
        return
    var triangle_count := 0
    var textured := false
    for visual in NatureReplacement._mesh_nodes(model):
        if visual.mesh == null:
            continue
        var faces: PackedVector3Array = visual.mesh.get_faces()
        triangle_count += faces.size() / 3
        for surface in range(visual.mesh.get_surface_count()):
            var mat := visual.get_active_material(surface) as BaseMaterial3D
            if mat != null and mat.albedo_texture != null:
                textured = true
    model.free()
    if triangle_count < 10000 or triangle_count > 13000:
        _fail("Unexpected fountain mesh budget: %d triangles" % triangle_count)
        return
    if not textured:
        _fail("Fountain lost its original stone-and-water PBR texture")
        return

    var town_scene := load("res://starter_town.tscn") as PackedScene
    if town_scene == null:
        _fail("Could not load the starter town")
        return
    var town := town_scene.instantiate()
    root.add_child(town)
    for i in range(10):
        await process_frame
    var fountain := town.find_child("TownFountain", true, false) as Node3D
    if fountain == null or fountain.get_node_or_null("ImportedMedievalFountain") == null:
        _fail("Genuine fountain wasn't instantiated into town plaza")
        return
    if not bool(fountain.get_meta("fountain_imported", false)):
        _fail("Fountain was replaced with temporary geometry")
        return
    var water := fountain.get_node_or_null("FountainWaterEffects") as Node3D
    if water == null:
        _fail("Fountain water surfaces were not installed")
        return
    if not bool(water.get_meta("water_mobile_compatible", false)):
        _fail("Water shaders were not configured for Android Compatibility")
        return
    if int(water.get_meta("filled_tier_count", 0)) != 2:
        _fail("Only the two actually hollow fountain bowls should contain water")
        return
    if int(water.get_meta("upper_and_lower_water_surfaces", 0)) != 2:
        _fail("Water controller should have exactly two basin surfaces")
        return
    if not bool(water.get_meta("solid_top_ornament_preserved", false)):
        _fail("Solid upper stone finial was not preserved")
        return
    if water.get_node_or_null("TopBowlWater") != null or water.get_node_or_null("FountainCalmRipple_Top_00") != null:
        _fail("Fake water placed on top of flat solid stone")
        return
    if String(water.get_meta("water_effect_lod", "")) != "calm_shader_only_no_streams":
        _fail("Old stream-heavy water visual pass has returned")
        return
    for pool_spec in [
        ["LowerBasinWater", 0.435, 1.20],
        ["UpperBowlWater", 1.602, 0.555]
    ]:
        var pool_name: String = pool_spec[0]
        var water_surface := water.get_node_or_null(pool_name) as MeshInstance3D
        if water_surface == null or water_surface.mesh == null:
            _fail("Missing calm water in the " + pool_name)
            return
        var material := water_surface.material_override as ShaderMaterial
        if material == null or material.shader == null or material.get_shader_parameter("wave_texture") == null:
            _fail("Water must retain soft shader ripples in " + pool_name)
            return
        if absf(float(water_surface.get_meta("water_level_m", -1)) - float(pool_spec[1])) > 0.01:
            _fail("Water height does not sit within the stone rim: " + pool_name)
            return
        if absf(float(water_surface.get_meta("water_radius_m", -1)) - float(pool_spec[2])) > 0.01:
            _fail("Water surface has an incorrect basin radius: " + pool_name)
            return
        if float(material.get_shader_parameter("displacement")) > 0.006:
            _fail("Water waves are too large for the calm-water pass: " + pool_name)
            return
    if int(water.get_meta("cascade_count", -1)) != 0:
        _fail("Removed fountain streams have returned")
        return
    if not water.find_children("FountainCascade_*", "MeshInstance3D", false, false).is_empty():
        _fail("Hanging stream meshes still visible in fountain")
        return
    if not water.find_children("FountainImpactRipple_*", "MeshInstance3D", false, false).is_empty():
        _fail("Old stream-impact ripples still appear")
        return
    if int(water.get_meta("gentle_ripple_count", -1)) != 5:
        _fail("Expected five sparse decorative ripples across both hollow basins")
        return
    var ripple_counts := {"Lower": 0, "Middle": 0}
    for ripple in water.find_children("FountainCalmRipple_*", "MeshInstance3D", false, false):
        var ripple_node := ripple as MeshInstance3D
        var tier: String = ripple_node.get_meta("tier", "")
        if not ripple_counts.has(tier):
            _fail("Calm ripple assigned an unknown water tier")
            return
        ripple_counts[tier] += 1
        if not bool(ripple_node.get_meta("ripple_style", "") == "subtle_nonimpact"):
            _fail("Ripples must be calm, not heavy splashes")
            return
    if ripple_counts["Lower"] != 3 or ripple_counts["Middle"] != 2:
        _fail("Gentle ripples were not distributed across both water basins")
        return
    if absf(float(fountain.get_meta("fountain_visual_scale", 0.0)) - 3.55) > 0.01:
        _fail("Fountain is the wrong scale for a walkable medieval square")
        return
    if absf(fountain.position.z - (-6.10 + 2.45) * 0.5) > 0.01:
        _fail("Fountain is not centered between the four stalls")
        return
    if not bool(town.call("_world_point_blocked", Vector2(0.0, -1.825))):
        _fail("Character can walk into the fountain stonework")
        return
    for access in [Vector2(0.0, -4.55), Vector2(0.0, 0.95),
        Vector2(-2.75, -1.825), Vector2(2.75, -1.825)]:
        if bool(town.call("_world_point_blocked", access)):
            _fail("Plaza circulation is obstructed beside fountain: " + str(access))
            return
    var cylinders: Array = town.get("_camera_cylinders")
    var camera_barrier := false
    for cylinder in cylinders:
        var center: Vector3 = cylinder["center"]
        if absf(center.x) < 0.01 and absf(center.z + 1.825) < 0.01:
            camera_barrier = true
            if absf(float(cylinder["radius"]) - 1.79) > 0.01:
                _fail("Fountain camera obstruction is oversized")
                return
    if not camera_barrier:
        _fail("Fountain has no round camera collision")
        return
    print("AETHERFALL_AUTHENTIC_FOUNTAIN_OK: user 3D GLB, %d triangles, textured, plaza access and camera collision" % triangle_count)
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_AUTHENTIC_FOUNTAIN_FAIL: " + message)
    quit(1)
