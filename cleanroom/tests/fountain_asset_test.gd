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
    if int(water.get_meta("upper_and_lower_water_surfaces", 0)) != 2:
        _fail("Both tiers need moving basin water")
        return
    for name in ["UpperBowlWater", "LowerBasinWater"]:
        var surface := water.get_node_or_null(name) as MeshInstance3D
        if surface == null or surface.mesh == null or not (surface.material_override is ShaderMaterial):
            _fail("Missing real moving pool: " + name)
            return
        var material := surface.material_override as ShaderMaterial
        if material.shader == null or material.get_shader_parameter("wave_texture") == null:
            _fail("Wave surface is missing the animated Binbun-type noise")
            return
    if int(water.get_meta("cascade_count", 0)) != 8 or int(water.get_meta("ripple_impact_count", 0)) != 8:
        _fail("Fountain needs eight continuous upper-to-lower jets and splash sites")
        return
    for i in range(8):
        var jet := water.get_node_or_null("FountainCascade_%02d" % i) as MeshInstance3D
        var ripple := water.get_node_or_null("FountainImpactRipple_%02d" % i) as MeshInstance3D
        if jet == null or ripple == null:
            _fail("Missing actual flow or basin splash on outlet %d" % i)
            return
        if not bool(jet.get_meta("flow_from_upper_bowl", false)) or not bool(ripple.get_meta("splash_replacement_point", false)):
            _fail("An upper flow does not connect to its lower-water impact")
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
