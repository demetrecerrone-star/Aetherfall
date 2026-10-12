extends SceneTree
## Two NEW Quaternius Universal Base characters must play in Starter Town,
## with their own 65-joint rig and 25-clip animation library.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Missing starter town")
        return
    var town := scene.instantiate() as Node3D
    root.add_child(town)
    for i in range(12):
        await process_frame
    if not _check(town, "male"):
        return
    town.call("_set_motion", "WALK")
    if not _current_clip(town).to_lower().ends_with("walk_loop"):
        _fail("Male should walk using smoother Universal Jog_Fwd_Loop")
        return
    town.call("_set_motion", "RUN")
    if not _current_clip(town).to_lower().ends_with("jog_fwd_loop"):
        _fail("Male should sprint using smoother Universal Jog_Fwd_Loop")
        return
    town.call("_set_motion", "IDLE")
    town.call("_switch_character")
    for i in range(12):
        await process_frame
    if not _check(town, "female"):
        return
    town.call("_set_motion", "WALK")
    if not _current_clip(town).to_lower().ends_with("walk_loop"):
        _fail("Female should walk using smoother Universal Jog_Fwd_Loop")
        return
    town.call("_set_motion", "RUN")
    if not _current_clip(town).to_lower().ends_with("jog_fwd_loop"):
        _fail("Female should sprint using smoother Universal Jog_Fwd_Loop")
        return
    town.call("_set_motion", "IDLE")
    town.call("_cycle_idle_pose")
    if not _current_clip(town).to_lower().ends_with("idle_loop"):
        _fail("Female idle pose cycle failed")
        return
    var buttons := town.find_children("*", "Button", true, false)
    var action_found := false
    for child in buttons:
        if child.name == "UniversalActionButton" and child.text == "INTERACT":
            action_found = true
            break
    if not action_found:
        _fail("Expected in-town action preview, NOT old creator UI")
        return
    print("AETHERFALL_CHARACTER_SWITCH_OK: Universal male/female, 65-bone rigs, 25 native clips, idle/walk/sprint, interaction control")
    town.queue_free()
    quit(0)

func _current_clip(town: Node) -> String:
    var player := town.get("_animation") as AnimationPlayer
    return String(player.current_animation) if player != null else ""

func _check(town: Node3D, gender: String) -> bool:
    if not bool(town.get("_loaded")) or not bool(town.get("_universal_active")):
        _fail("Universal player failed to become playable: "+gender)
        return false
    if String(town.get("_character_variant")) != gender:
        _fail("Wrong character selected: "+gender)
        return false
    var model := town.get("_model") as Node3D
    if model == null or model.name != "Universal_"+gender:
        _fail("Old character appeared instead of Universal "+gender)
        return false
    # Another 10% visual shrink from Build #147 for both sexes; actor/HUD unchanged.
    if absf(model.scale.y - 0.5175) > 0.0001:
        _fail("New Universal "+gender+" height was not applied")
        return false
    var actor := town.get_node_or_null("TripoActor") as Node3D
    if actor == null or absf(actor.scale.y - 1.62) > 0.001:
        _fail("Visual resize unexpectedly changed the gameplay actor collider: "+gender)
        return false
    # The boot-floor solver must recalibrate when the body scale changes.
    var road_height: float = town.call("_ground_surface_y", actor.global_position)
    var lowest_sole: float = town.call("_sole_floor_y")
    if absf(lowest_sole - road_height) > 0.14:
        _fail("Universal "+gender+" foot contact changed after resize: "+str(lowest_sole - road_height))
        return false
    var rig := town.get("_skeleton") as Skeleton3D
    var player := town.get("_animation") as AnimationPlayer
    if rig == null or player == null or rig.get_bone_count() != 65:
        _fail("New player skeleton and animation player missing: "+gender)
        return false
    for clip in ["Idle_Loop","Walk_Loop","Sprint_Loop","Sword_Attack","Sword_Block","Interact"]:
        if String(town.call("_clip_for",clip)).is_empty():
            _fail("Native Universal animation missing: "+clip)
            return false
    if player.get_animation_list().size() < 25:
        _fail("Universal action library is incomplete for "+gender)
        return false
    if town.get("_left_foot_index") < 0 or town.get("_right_foot_index") < 0:
        _fail("Both feet bones must remain grounded: "+gender)
        return false
    print("AETHERFALL_UNIVERSAL_CHARACTER_OK: "+gender+"; 65 bones, 25 animations and valid feet")
    return true

func _fail(message: String) -> void:
    push_error("AETHERFALL_CHARACTER_QA_FAIL: "+message)
    quit(1)
