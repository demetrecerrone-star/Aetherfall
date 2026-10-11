extends SceneTree
## QA the genuine, user-supplied fountain mesh and its town collision.
const FOUNTAIN = preload("res://models/fountain/MedievalFountain.glb")
const NatureReplacement = preload("res://nature_replacements.gd")

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var mesh_scene := FOUNTAIN as PackedScene
    if mesh_scene == null:
        _fail("User fountain GLB did not import")
        return
    var model := mesh_scene.instantiate() as Node3D
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
    if absf(float(fountain.get_meta("fountain_visual_scale", 0.0)) - 3.2) > 0.01:
        _fail("Fountain is the wrong scale for a walkable medieval square")
        return
    if not bool(town.call("_world_point_blocked", Vector2(0.0, -4.0))):
        _fail("Character can walk into the fountain stonework")
        return
    for access in [Vector2(0.0, -1.8), Vector2(0.0, -6.1), Vector2(-2.5, -4.0), Vector2(2.5, -4.0)]:
        if bool(town.call("_world_point_blocked", access)):
            _fail("Plaza circulation is obstructed beside fountain: " + str(access))
            return
    var cylinders: Array = town.get("_camera_cylinders")
    var camera_barrier := false
    for cylinder in cylinders:
        var center: Vector3 = cylinder["center"]
        if absf(center.x) < 0.01 and absf(center.z + 4.0) < 0.01:
            camera_barrier = true
            if absf(float(cylinder["radius"]) - 1.60) > 0.01:
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
