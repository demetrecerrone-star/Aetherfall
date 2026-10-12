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
    if not bool(town.get("_creator_v065_active")):
        _fail("Recovered v0.6.5 male must replace the starter-town original male")
        return
    var creator := town.get("_creator_v065_avatar") as Node3D
    if creator == null:
        _fail("Original v0.6.5 modular appearance controller is not loaded")
        return
    var creator_meshes: Array = creator.get("meshes")
    if creator_meshes.size() < 10:
        _fail("Original v0.6.5 equipment meshes are missing")
        return
    var costume: Dictionary = creator.call("export_profile")
    if str(costume.get("gender", "")) != "male":
        _fail("Loaded creator profile is not the recovered male avatar")
        return
    town.call("_toggle_v065_creator")
    if not bool(town.get("_creator_v065_open")):
        _fail("LOOKS button did not open the creator")
        return
    town.call("_creator_v065_action", "hair")
    town.call("_creator_v065_action", "outfit")
    town.call("_toggle_v065_creator")
    if bool(town.get("_creator_v065_open")):
        _fail("Creator remained open after returning to town")
        return
    town.call("_switch_character")
    for i in range(4):
        await process_frame
    if not _assert_character(town, "female", "idle"):
        return
    if bool(town.get("_creator_v065_active")):
        _fail("Incomplete v0.6.5 female must not be silently substituted")
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
    print("AETHERFALL_CHARACTER_SWITCH_OK: original creator v0.6.5 male with equipment/LOOKS; female fallback retained; walk/run passed")
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
