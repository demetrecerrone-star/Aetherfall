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
    if house.get_node_or_null("DoorStepUpper") != null or house.get_node_or_null("DoorStepLower") != null:
        _fail("Outdated door stairs are still in the scene")
        return
    var origin := house.position
    var model_size: Vector3 = house.get_meta("scenery_model_size", Vector3.ZERO)
    var collision_half: Vector2 = house.get_meta("collision_half", Vector2.ZERO)
    if model_size.y < 6.0 or model_size.x < 5.0 or collision_half.x < 2.0:
        _fail("New landmark scale/collision footprint is not calibrated")
        return
    if not bool(town.call("_world_point_blocked", Vector2(origin.x, origin.z))):
        _fail("Imported building is missing solid wall collision")
        return
    var contact := origin.z + collision_half.y + 0.34
    if not bool(town.call("_world_point_blocked", Vector2(origin.x, contact - 0.02))):
        _fail("Actor clips through imported building facade")
        return
    if bool(town.call("_world_point_blocked", Vector2(origin.x, contact + 0.45))):
        _fail("Building has a large invisible collision halo")
        return
    var safe: Vector3 = town.call("_camera_safe_goal", Vector3(origin.x, 1.6, origin.z + 5.0), Vector3(origin.x, 1.6, origin.z))
    if safe.z < origin.z + 2.4:
        _fail("Camera moved inside building")
        return
    var wall: Vector3 = town.call("_camera_safe_goal", Vector3(23.0, 1.6, 0.0), Vector3(32.0, 1.6, 0.0))
    if wall.x > 27.0:
        _fail("Camera moved through perimeter wall")
        return
    var footing: float = town.call("_ground_surface_y", Vector3(origin.x, 0.0, origin.z + 4.3))
    if footing > 0.1:
        _fail("Removed stairs still affect boot grounding")
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
        Vector2(-8.1, 2.1),
        Vector2(8.1, 2.1)
    ]
    for lamp_pos in lamp_positions:
        var away: float = -1.0 if lamp_pos.x < 0.0 else 1.0
        if not bool(town.call("_world_point_blocked", lamp_pos + Vector2(away * 0.40, 0.0))):
            _fail("Freestanding post still no-clips at " + str(lamp_pos))
            return
        if bool(town.call("_world_point_blocked", lamp_pos + Vector2(away * 0.55, 0.0))):
            _fail("Post has too much invisible clearance at " + str(lamp_pos))
            return
    # The four counters are rotated 45/135 degrees, with unobstructed
    # diagonal space around their corners and an open middle loop.
    var stalls := town.find_children("MarketStall_*", "Node3D", true, false)
    if stalls.size() != 4:
        _fail("Four market stalls were not placed")
        return
    for stall in stalls:
        var sp: Vector3 = (stall as Node3D).position
        if not bool(town.call("_world_point_blocked", Vector2(sp.x, sp.z))):
            _fail("Market counter no-clips")
            return
    for aisle in [Vector2(0, -4), Vector2(0, -1.8), Vector2(0, 2.45), Vector2(-2.0, -2.0), Vector2(2.0, -2.0)]:
        if bool(town.call("_world_point_blocked", aisle)):
            _fail("Market browsing circuit blocked at " + str(aisle))
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

    print("AETHERFALL_COLLISION_CAMERA_02Y_OK: doors, grounding, tight gate towers and portcullis, all wall buttress collisions, camera shells, solid barrels and lamp posts, soft bushes")
    town.queue_free()
    quit(0)

func _fail(detail: String) -> void:
    push_error("AETHERFALL_COLLISION_CAMERA_FAIL: " + detail)
    quit(1)
