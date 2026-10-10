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
    if rig == null or rig.get_bone_count() < 55:
        push_error("TRIPO_GODOT_TEST_FAIL: Mixamo skeleton was not imported")
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
    for mode in ["WALK", "RUN", "IDLE"]:
        scene.call("_on_control", mode)
        for frame in range(3):
            await process_frame
    var start_zoom: float = scene.get("_zoom")
    scene.call("_on_control", "ZOOM +")
    if not float(scene.get("_zoom")) < start_zoom:
        push_error("TRIPO_GODOT_TEST_FAIL: zoom controls broken")
        quit(1)
        return
    scene.call("_on_control", "ZOOM -")
    if not is_equal_approx(float(scene.get("_zoom")), start_zoom):
        push_error("TRIPO_GODOT_TEST_FAIL: zoom restore failed")
        quit(1)
        return
    print("AETHERFALL_TRIPO_IMPORT_OK %d joints, walk/run clips, controls, separate scene" % rig.get_bone_count())
    scene.queue_free()
    quit(0)
