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
    # Barrels are solid but not surrounded by invisible walls. Three barrels
    # are scattered around the blacksmith and the general shop.
    var barrel_positions := [
        Vector2(-15.75, 7.35),
        Vector2(-15.75, 8.25),
        Vector2(15.20, 8.10)
    ]
    for barrel_pos in barrel_positions:
        if not bool(town.call("_world_point_blocked", barrel_pos)):
            _fail("Barrel is no-clipping at " + str(barrel_pos))
            return
        var away: float = -1.0 if barrel_pos.x < 0.0 else 1.0
        if not bool(town.call("_world_point_blocked", barrel_pos + Vector2(away * 0.65, 0.0))):
            _fail("Barrel rim permits clipping at " + str(barrel_pos))
            return
        if bool(town.call("_world_point_blocked", barrel_pos + Vector2(away * 0.86, 0.0))):
            _fail("Barrel collision has too much invisible clearance at " + str(barrel_pos))
            return

    # Street lamp bases need collision even while the poles remain slim.
    var lamp_positions := [
        Vector2(-4.70, -10.25),
        Vector2(4.70, -10.25),
        Vector2(-5.45, 4.45),
        Vector2(5.45, 4.45)
    ]
    for lamp_pos in lamp_positions:
        var away: float = -1.0 if lamp_pos.x < 0.0 else 1.0
        if not bool(town.call("_world_point_blocked", lamp_pos + Vector2(away * 0.40, 0.0))):
            _fail("Freestanding post still no-clips at " + str(lamp_pos))
            return
        if bool(town.call("_world_point_blocked", lamp_pos + Vector2(away * 0.55, 0.0))):
            _fail("Post has too much invisible clearance at " + str(lamp_pos))
            return
    # Four stalls ring the market; former fountain centre remains walkable.
    for stall_x in [-5.1, 5.1]:
        if not bool(town.call("_world_point_blocked", Vector2(stall_x - 1.08, 0.8 + 0.46))):
            _fail("Original market stall post no longer collides")
            return
    for stall_x in [-4.0, 4.0]:
        if not bool(town.call("_world_point_blocked", Vector2(stall_x, -4.0))):
            _fail("New market stall is missing collision")
            return
    if bool(town.call("_world_point_blocked", Vector2(0.0, -4.0))):
        _fail("Former fountain still blocks the market aisle")
        return

    # Small ornamental foliage should remain deliberately walk-through.
    if bool(town.call("_world_point_blocked", Vector2(15.0, 11.0))):
        _fail("Soft shrub unexpectedly gained solid collision")
        return
    if not bool(town.get("_loaded")):
        _fail("Character loading failed")
        return
    # Regression: a diagonal position can be outside the 2.3m round tower
    # yet inside its old 4.6m square camera AABB. The camera must remain free.
    var diagonal := Vector3(-6.0, 1.75, 22.75)
    var clear_destination := Vector3(-7.4, 1.75, 21.35)
    var camera_corner: Vector3 = town.call("_camera_safe_goal", diagonal, clear_destination)
    if camera_corner.distance_to(clear_destination) > 0.01:
        _fail("Round tower's empty diagonal corner still pulls camera into character")
        return

    # Approach the front of the gate while the camera points through the tower.
    # The camera should stop at stone and fully hide the player before its
    # shortened arm can show close-up fabric or skin.
    var avatar := town.get_node_or_null("TripoActor") as Node3D
    var orbit := town.get_node_or_null("OrbitCamera") as Camera3D
    if avatar == null or orbit == null:
        _fail("Camera / avatar nodes missing")
        return
    avatar.position = Vector3(-4.1, avatar.position.y, 21.85)
    town.set("_camera_yaw", 0.0)
    town.set("_camera_pitch", 0.18)
    town.set("_camera_distance", 4.0)
    town.call("_update_camera", 1.0)
    if orbit.global_position.z > 22.20:
        _fail("Camera went through front gate tower")
        return
    if float(town.get("_camera_fade_alpha")) > 0.05:
        _fail("Avatar was not faded when the camera was forced too close")
        return
    var fade_surfaces: Array = town.get("_camera_fade_surfaces")
    if fade_surfaces.is_empty():
        _fail("No imported character materials can fade on Android")
        return

    # Restore a clear angle: the opaque materials and regular follow distance
    # must return. The player can still be swapped between both character rigs.
    town.set("_camera_yaw", PI)
    town.call("_update_camera", 1.0)
    if float(town.get("_camera_fade_alpha")) < 0.995:
        _fail("Character did not return to full opacity")
        return
    if orbit.global_position.distance_to(avatar.global_position + Vector3(0, 1.03, 0)) < 3.0:
        _fail("Camera did not recover third-person distance")
        return

    print("AETHERFALL_COLLISION_CAMERA_02U_OK: doors, grounding, tight gate towers and portcullis, all wall buttress collisions, camera shells, solid barrels and lamp posts, soft bushes")
    town.queue_free()
    quit(0)

func _fail(detail: String) -> void:
    push_error("AETHERFALL_COLLISION_CAMERA_FAIL: " + detail)
    quit(1)
