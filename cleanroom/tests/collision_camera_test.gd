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
    var solid_half: Vector2 = house.get_meta("collision_half", Vector2.ZERO)
    var solid_center: Vector2 = house.get_meta("collision_center", Vector2.ZERO)
    if model_size.y < 6.8 or model_size.x < 5.0 or solid_half.x < 1.1:
        _fail("New landmark doorway scaling/wall footprint is not calibrated")
        return
    if not house.has_meta("scenery_wall_footprint"):
        _fail("Imported wall geometry was not identified; awnings may be solid")
        return
    var wall_rect: Rect2 = house.get_meta("scenery_wall_footprint")
    if wall_rect.size.x >= model_size.x * 0.98 and wall_rect.size.y >= model_size.z * 0.98:
        _fail("Roof/awning footprint was mistaken for a solid wall")
        return
    if not bool(town.call("_world_point_blocked", solid_center)):
        _fail("Blacksmith wall has no collision")
        return
    var door_contact := solid_center + Vector2(0, solid_half.y + 0.34)
    if not bool(town.call("_world_point_blocked", door_contact + Vector2(0, -0.02))):
        _fail("Closed door/stone facade can be crossed")
        return
    if bool(town.call("_world_point_blocked", door_contact + Vector2(0, 0.44))):
        _fail("An awning passage has a phantom collision barrier")
        return
    # Blacksmith side roof extends over a visible exterior paved walk. A
    # player can stand there while the foundation itself stays impenetrable.
    var sheltered_point := Vector2(origin.x + model_size.x * 0.495, solid_center.y)
    if bool(town.call("_world_point_blocked", sheltered_point)):
        _fail("Covered side walk is blocked by invisible roof collision")
        return
    if float(town.call("_ground_surface_y", Vector3(door_contact.x, 0.0, door_contact.y + 0.3))) > 0.10:
        _fail("Removed steps still raise floor outside entrance")
        return
    var safe: Vector3 = town.call("_camera_safe_goal", Vector3(solid_center.x, 1.6, solid_center.y + 6.0), Vector3(solid_center.x, 1.6, solid_center.y))
    if safe.z < solid_center.y + solid_half.y - 0.08:
        _fail("Camera penetrates the solid blacksmith wall")
        return
    var wall: Vector3 = town.call("_camera_safe_goal", Vector3(23.0, 1.6, 0.0), Vector3(32.0, 1.6, 0.0))
    if wall.x > 27.0:
        _fail("Camera moved through perimeter wall")
        return
    var footing: float = town.call("_ground_surface_y", Vector3(origin.x, 0.0, origin.z + 4.3))
    if footing > 0.1:
        _fail("Removed stairs still affect boot grounding")
        return
    # Stone finish should match nearby stone foundations, not the old timber.
    var stone_towers := town.find_children("StoneGateTower_*", "MeshInstance3D", true, false)
    if stone_towers.size() != 2:
        _fail("Gate watchtowers must both be weathered masonry")
        return
    if not town.find_children("TimberGateTower", "MeshInstance3D", true, false).is_empty():
        _fail("Old timber tower cylinders still visible")
        return
    if String(town.get_meta("gate_tower_material", "")) != "staggered_chiseled_ashlar":
        _fail("Gate masonry has not switched to dressed ashlar blocks")
        return
    var dressed := town.find_child("GateChiseledAshlar", true, false) as MeshInstance3D
    if dressed == null or dressed.mesh == null:
        _fail("Batched chiseled gate masonry is missing")
        return
    if int(town.get_meta("gate_ashlar_block_count", 0)) != 468:
        _fail("Not all staggered cut-stone courses were laid across two towers")
        return
    if String(town.get_meta("gate_ashlar_tone", "")) != "deep_fortress_grey":
        _fail("The tower stones were not darkened to the approved fortress grey")
        return
    if not bool(town.get_meta("gate_roof_wood_matches_leaves", false)):
        _fail("Tower roof timbers do not match the gate")
        return
    var tower_roofs := town.find_children("TimberGateRoof*", "MeshInstance3D", true, false)
    if tower_roofs.size() != 2:
        _fail("Both gate sentry towers must have timber roofs")
        return
    for roof in tower_roofs:
        var roof_mat := (roof as MeshInstance3D).material_override as StandardMaterial3D
        if roof_mat == null or roof_mat.albedo_color != Color("#92704e") or roof_mat.albedo_texture == null:
            _fail("Tower roofs are not the same textured oak tint as the main gate")
            return
    var dressed_material := dressed.mesh.surface_get_material(0) as StandardMaterial3D
    if dressed_material == null or not dressed_material.vertex_color_use_as_albedo:
        _fail("Gate stone lacks individual chiseled block shading")
        return
    for tower_mesh in stone_towers:
        var stone := (tower_mesh as MeshInstance3D).material_override as StandardMaterial3D
        if stone == null or stone.albedo_texture != null:
            _fail("Gate mortar base still shows pebbly road/foundation texture")
            return
    var gate_wood := Color("#92704e")
    var leaves := town.find_children("ClosedWoodGateLeaf_*", "MeshInstance3D", true, false)
    if leaves.size() != 2:
        _fail("Expected two solid timber gates")
        return
    for leaf in leaves:
        var leaf_mat := (leaf as MeshInstance3D).material_override as StandardMaterial3D
        if leaf_mat == null or leaf_mat.albedo_color != gate_wood or leaf_mat.albedo_texture == null:
            _fail("Gate planks are not using the same timber/tint as palisade logs")
            return
    var wall_posts := town.get_node_or_null("ValleyTimberPalisade") as MultiMeshInstance3D
    if wall_posts == null:
        _fail("Palisade timber comparison missing")
        return
    var wall_mat := wall_posts.material_override as StandardMaterial3D
    if wall_mat == null or wall_mat.albedo_color != gate_wood:
        _fail("Gate wood does not match the actual wall material")
        return
    # Gate towers remain 2.3m-radius solid, but the visible entrance is
    # now an opaque fixed oak double gate instead of barred portcullis.
    if not bool(town.call("_world_point_blocked", Vector2(-4.1, 24.0))):
        _fail("Wooden gate watch tower is missing its solid footprint")
        return
    if not bool(town.call("_world_point_blocked", Vector2(-4.1, 21.95))):
        _fail("Gate tower visual may be clipped")
        return
    if bool(town.call("_world_point_blocked", Vector2(-4.1, 21.85))):
        _fail("Wooden watch tower has a large invisible halo")
        return
    if not bool(town.call("_world_point_blocked", Vector2(0.0, 24.30))):
        _fail("Player can walk through the closed wooden gate")
        return
    if bool(town.call("_world_point_blocked", Vector2(0.0, 22.40))):
        _fail("Approach zone has invisible blockers preventing area transfer")
        return
    # Front gate is fully sealed; side/rear wood walls match their visible
    # log rows without the old jutting stone buttress blockers.
    for wall_x in [-26.67, 26.67]:
        var approach := -26.30 if wall_x < 0.0 else 26.30
        var clear_x := -25.80 if wall_x < 0.0 else 25.80
        if not bool(town.call("_world_point_blocked", Vector2(approach, -21.0))):
            _fail("Solid timber perimeter was not registered as collision")
            return
        if bool(town.call("_world_point_blocked", Vector2(clear_x, -21.0))):
            _fail("Timber wall invisible collision extends into village")
            return
    if not bool(town.call("_world_point_blocked", Vector2(-22.0, -24.20))):
        _fail("Rear palisade is not solid")
        return
    if bool(town.call("_world_point_blocked", Vector2(-22.0, -23.80))):
        _fail("Palisade invisible wall protrudes into lawn")
        return
    if not bool(town.get_meta("main_gate_permanently_closed", false)):
        _fail("Closed gate can be opened")
        return
    if town.get_meta("gate_interaction", "") != "approach_loading_zone":
        _fail("No trigger associated with permanent wooden gate")
        return
    var controller := town.get_node_or_null("AetherfallZoneTransfer")
    if controller == null:
        _fail("Separate-zone transition controller missing")
        return
    var destination := String(town.get_meta("gate_destination_scene", ""))
    if bool(controller.call("has_destination", destination)):
        _fail("Unexpectedly found the not-yet-authored valley outskirts scene")
        return
    if bool(controller.call("attempt_transfer", destination,
        "Valley Outskirts", {}, "valley_entrance")):
        _fail("Gate transferred the player to a nonexistent zone")
        return
    var notice := controller.get_node_or_null("ZonePreviewNotice") as Label
    if notice == null or not notice.visible:
        _fail("Missing future area does not show an availability notice")
        return
    controller.call("clear_hint")
    if notice.visible:
        _fail("Future-area notice cannot be dismissed by leaving gate")
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

    # Every wooden support gets a compact solid footprint, while the stall
    # canopy itself and a clear walk-under strip remain accessible.
    for stall in stalls:
        var marker_positions: Array = (stall as Node3D).get_meta("support_post_positions", [])
        if marker_positions.size() != 4:
            _fail("Market awning is missing individual post footprints")
            return
        for marker in marker_positions:
            if not bool(town.call("_world_point_blocked", marker)):
                _fail("A wooden stall support still allows clipping")
                return
        var rotation := Basis(Vector3.UP, deg_to_rad((stall as Node3D).rotation_degrees.y))
        var clear_point: Vector3 = (stall as Node3D).position + rotation * Vector3(0.0, 0.0, 1.12)
        if bool(town.call("_world_point_blocked", Vector2(clear_point.x, clear_point.z))):
            _fail("The walkway below a market canopy is blocked")
            return
    var house_support_count := 0
    for building in town.get_children():
        if not (building is Node3D) or not building.has_meta("covered_walkway_clearance"):
            continue
        var supports: Array = building.get_meta("awning_support_positions", [])
        for support in supports:
            house_support_count += 1
            if not bool(town.call("_world_point_blocked", support)):
                _fail("A building porch timber post is still pass-through")
                return
    if house_support_count < 2:
        _fail("No individual support posts were registered for the building awnings")
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

    print("AETHERFALL_COLLISION_CAMERA_PASS3_OK: doors, grounding, tight gate towers and portcullis, all wall buttress collisions, camera shells, solid barrels and lamp posts, soft bushes")
    town.queue_free()
    quit(0)

func _fail(detail: String) -> void:
    push_error("AETHERFALL_COLLISION_CAMERA_FAIL: " + detail)
    quit(1)
