extends SceneTree
## Confirm that both characters can actually load and animate in the town.

func _initialize() -> void:
    call_deferred("_test_characters")


func _test_characters() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Starter town scene missing")
        return
    var town := scene.instantiate()
    root.add_child(town)
    for i in range(8):
        await process_frame

    if not _assert_character(town, "male", "standing_relax"):
        return
    town.call("_switch_character")
    for i in range(4):
        await process_frame
    if not _assert_character(town, "female", "idle"):
        return
    # No joystick is held in headless QA, so do not wait frames between these
    # checks: the normal controller would correctly return the actor to idle.
    town.call("_set_motion", "WALK")
    var walk_player := town.get("_animation") as AnimationPlayer
    if String(town.get("_motion")) != "WALK" or walk_player == null or not String(walk_player.current_animation).to_lower().ends_with("walk"):
        _fail("Female walk animation did not activate")
        return
    town.call("_set_motion", "RUN")
    var run_player := town.get("_animation") as AnimationPlayer
    if String(town.get("_motion")) != "RUN" or run_player == null or not String(run_player.current_animation).to_lower().ends_with("run"):
        _fail("Female run animation did not activate")
        return
    town.call("_set_motion", "IDLE")
    town.call("_switch_character")
    for i in range(4):
        await process_frame
    if not _assert_character(town, "male", "standing_relax"):
        return
    print("AETHERFALL_CHARACTER_SWITCH_OK: male -> female -> male; authored idle and shared walk/run passed")
    town.queue_free()
    quit(0)


func _assert_character(town: Node, expected: String, expected_idle: String) -> bool:
    if not bool(town.get("_loaded")):
        _fail("Character did not finish loading: " + expected)
        return false
    if String(town.get("_character_variant")) != expected:
        _fail("Character selection state incorrect: " + expected)
        return false
    var actor := town.get_node_or_null("TripoActor") as Node3D
    if actor == null or absf(actor.scale.x - 1.62) > 0.01 or absf(actor.scale.y - 1.62) > 0.01:
        _fail("Both adventurers must use the new slightly smaller world scale: " + expected)
        return false
    var sole_y: float = town.call("_sole_floor_y")
    var floor_y: float = town.call("_ground_surface_y", actor.global_position)
    if absf(sole_y - floor_y) > 0.10:
        _fail("Rescaling caused boot grounding regression: %s sole=%f ground=%f" % [expected, sole_y, floor_y])
        return false
    var rig := town.get("_skeleton") as Skeleton3D
    if rig == null or rig.get_bone_count() != 65:
        _fail("Active character has no valid 65-joint skeleton: " + expected)
        return false
    var player := town.get("_animation") as AnimationPlayer
    if player == null:
        _fail("Active character missing AnimationPlayer: " + expected)
        return false
    var current := String(player.current_animation).to_lower()
    if not current.ends_with(expected_idle):
        _fail("Wrong idle clip for %s: %s" % [expected, current])
        return false
    print("AETHERFALL_CHARACTER_OK: " + expected + " idle=" + current)
    return true


func _fail(message: String) -> void:
    push_error("AETHERFALL_CHARACTER_QA_FAIL: " + message)
    quit(1)
