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
    town.call("_set_motion", "WALK")
    for i in range(4):
        await process_frame
    if String(town.get("_motion")) != "WALK":
        _fail("Female walk animation did not start")
        return
    town.call("_set_motion", "RUN")
    for i in range(4):
        await process_frame
    if String(town.get("_motion")) != "RUN":
        _fail("Female run animation did not start")
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
