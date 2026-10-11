extends SceneTree
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Scene missing")
        return
    var town := scene.instantiate()
    root.add_child(town)
    for i in range(8):
        await process_frame
    var house := town.get_node_or_null("BLACKSMITH") as Node3D
    if house == null:
        _fail("House missing")
        return
    var door := house.get_node_or_null("Door") as MeshInstance3D
    var knob := house.get_node_or_null("DoorHandle") as MeshInstance3D
    var upper := house.get_node_or_null("DoorStepUpper") as MeshInstance3D
    var lower := house.get_node_or_null("DoorStepLower") as MeshInstance3D
    if door == null or knob == null or upper == null or lower == null:
        _fail("Door geometry missing")
        return
    if knob.position.z < door.position.z + 0.08 or knob.position.z > door.position.z + 0.17:
        _fail("Door handle is detached from the door face")
        return
    if upper.position.z >= lower.position.z or upper.position.y <= lower.position.y:
        _fail("Door steps not ordered correctly")
        return
    var origin := house.position
    if not bool(town.call("_world_point_blocked", Vector2(origin.x + 1.0, origin.z + 3.05))):
        _fail("House wall no longer blocks actor")
        return
    if bool(town.call("_world_point_blocked", Vector2(origin.x, origin.z + upper.position.z))):
        _fail("Upper step is obstructed by invisible collision")
        return
    if bool(town.call("_world_point_blocked", Vector2(origin.x, origin.z + 3.5))):
        _fail("Unobstructed doorway approach remains blocked")
        return
    var safe: Vector3 = town.call("_camera_safe_goal", Vector3(origin.x, 1.6, origin.z + 5.0), Vector3(origin.x, 1.6, origin.z))
    if safe.z < origin.z + 2.6:
        _fail("Camera moved inside building")
        return
    var wall: Vector3 = town.call("_camera_safe_goal", Vector3(23.0, 1.6, 0.0), Vector3(32.0, 1.6, 0.0))
    if wall.x > 27.0:
        _fail("Camera moved through perimeter wall")
        return
    var footing: float = town.call("_ground_surface_y", Vector3(origin.x, 0.0, origin.z + upper.position.z))
    if absf(footing - 0.52) > 0.001:
        _fail("Upper tread grounding failed")
        return
    if not bool(town.call("_world_point_blocked", Vector2(-4.1, 24.0))):
        _fail("Gate tower is no longer blocked")
        return
    # Tower: 2.3m physical radius + 0.34m player + 0.035m skin.
    # Points 2.65m and 2.75m from tower center straddle this boundary.
    if not bool(town.call("_world_point_blocked", Vector2(-4.1, 21.95))):
        _fail("Approach clips through the gate tower")
        return
    if bool(town.call("_world_point_blocked", Vector2(-4.1, 21.85))):
        _fail("Gate tower still has too large an invisible collision halo")
        return
    if not bool(town.call("_world_point_blocked", Vector2(0.0, 24.65))):
        _fail("Closed portcullis is passable")
        return
    # Each visible town-wall support has fitted collision, without
    # blocking empty air beyond its own projection.
    for wall_x in [-26.72, 26.72]:
        var approaching_x := -26.30 if wall_x < 0.0 else 26.30
        var free_x := -25.80 if wall_x < 0.0 else 25.80
        if not bool(town.call("_world_point_blocked", Vector2(approaching_x, -21.0))):
            _fail("Side wall buttress is missing its collision")
            return
        if bool(town.call("_world_point_blocked", Vector2(free_x, -21.0))):
            _fail("Side wall buttress blocks empty space")
            return
    if not bool(town.call("_world_point_blocked", Vector2(-22.0, -24.20))):
        _fail("North wall buttress is missing its collision")
        return
    if bool(town.call("_world_point_blocked", Vector2(-22.0, -23.80))):
        _fail("North wall buttress blocks empty air")
        return
    if not bool(town.get("_loaded")):
        _fail("Character loading failed")
        return
    print("AETHERFALL_COLLISION_CAMERA_02U_OK: doors, grounding, tight gate towers and portcullis, all wall buttress collisions, camera shells")
    town.queue_free()
    quit(0)

func _fail(detail: String) -> void:
    push_error("AETHERFALL_COLLISION_CAMERA_FAIL: " + detail)
    quit(1)
