extends SceneTree
## CI gate for actual user-supplied Tripo 65-joint Mixamo avatar + embedded animations.
func _initialize() -> void:
    call_deferred("_check")

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_player(child)
        if found != null:
            return found
    return null

func _check() -> void:
    var scene_res: PackedScene = load("res://tripo_lab.tscn")
    if scene_res == null:
        push_error("TRIPO_GODOT_TEST_FAIL: scene missing")
        quit(1)
        return
    var scene := scene_res.instantiate()
    root.add_child(scene)
    await process_frame
    var rig := _find_skeleton(scene)
    var player := _find_player(scene)
    if rig == null or rig.get_bone_count() != 65:
        push_error("TRIPO_GODOT_TEST_FAIL: expected verified 65-joint Mixamo skeleton")
        quit(1)
        return
    if player == null:
        push_error("TRIPO_GODOT_TEST_FAIL: missing embedded animation player")
        quit(1)
        return
    for joint_name in ["Hips", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "RightArm", "Head"]:
        var found := false
        for i in range(rig.get_bone_count()):
            if String(rig.get_bone_name(i)).to_lower().ends_with(joint_name.to_lower()):
                found = true
                break
        if not found:
            push_error("TRIPO_GODOT_TEST_FAIL: missing deform bone " + joint_name)
            quit(1)
            return
    var clips := player.get_animation_list()
    for target in ["walk", "run"]:
        var found := false
        for clip_name in clips:
            if String(clip_name).to_lower().ends_with(target):
                var clip := player.get_animation(clip_name)
                if clip == null or clip.get_length() < 0.4:
                    push_error("TRIPO_GODOT_TEST_FAIL: empty or invalid " + target)
                    quit(1)
                    return
                found = true
                break
        if not found:
            push_error("TRIPO_GODOT_TEST_FAIL: missing " + target + " animation")
            quit(1)
            return
    var actor := scene.get_node("TripoActor") as Node3D
    var start_position := actor.position
    scene.set("_move_input", Vector2(0.0, -1.0))
    scene.set("_sprint_held", false)
    for frame in range(8):
        scene.call("_update_gameplay_movement", 0.10)
    if scene.get("_motion") != "WALK" or actor.position.distance_to(start_position) < 0.25:
        push_error("TRIPO_GODOT_TEST_FAIL: gameplay walk input did not move actor")
        quit(1)
        return
    var walked_position := actor.position
    scene.set("_sprint_held", true)
    for frame in range(10):
        scene.call("_update_gameplay_movement", 0.10)
    if scene.get("_motion") != "RUN" or actor.position.distance_to(walked_position) < 1.0:
        push_error("TRIPO_GODOT_TEST_FAIL: sprint did not engage real travel")
        quit(1)
        return
    var before_lock := actor.position
    scene.call("_lock_root_motion")
    if Vector2(actor.position.x, actor.position.z).distance_to(Vector2(before_lock.x, before_lock.z)) > 0.001:
        push_error("TRIPO_GODOT_TEST_FAIL: root lock erased gameplay travel")
        quit(1)
        return
    scene.set("_move_input", Vector2.ZERO)
    scene.set("_sprint_held", false)
    for frame in range(12):
        scene.call("_update_gameplay_movement", 0.10)
    if scene.get("_motion") != "IDLE":
        push_error("TRIPO_GODOT_TEST_FAIL: release did not decelerate to idle")
        quit(1)
        return
    scene.call("_reset_idle_target")
    scene.call("_apply_idle_offsets", 1.1)
    var sole_y: float = scene.call("_sole_floor_y")
    if sole_y < -0.005:
        push_error("TRIPO_GODOT_TEST_FAIL: boot sole penetrates floor")
        quit(1)
        return
    print("AETHERFALL_TRIPO_PASS4_OK %d joints, touch locomotion, sprint, auto states, root lock, foot grounding" % rig.get_bone_count())
    scene.queue_free()
    quit(0)
