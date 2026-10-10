extends SceneTree
## Headless smoke gate for the isolated Android character test app.
func _initialize() -> void:
    call_deferred("_check")

func _rig(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _rig(child)
        if found != null:
            return found
    return null

func _check() -> void:
    var source: PackedScene = load("res://lab.tscn")
    if source == null:
        push_error("CHARACTER_LAB_FAIL: lab scene missing")
        quit(1)
        return
    var scene := source.instantiate()
    root.add_child(scene)
    await process_frame
    var model_rig := _rig(scene)
    if model_rig == null or model_rig.get_bone_count() != 96:
        push_error("CHARACTER_LAB_FAIL: 96-bone model not displayed")
        quit(1)
        return
    for name in ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]:
        if model_rig.find_bone(name) < 0:
            push_error("CHARACTER_LAB_FAIL: missing gait joint: " + name)
            quit(1)
            return
    for style in range(4):
        scene.call("_select_style", style)
        await process_frame
        model_rig = _rig(scene)
        if model_rig == null or model_rig.get_bone_count() != 96:
            push_error("CHARACTER_LAB_FAIL: bad hairstyle/rig variant %d" % style)
            quit(1)
            return
        scene.call("_on_button", "WALK")
        await process_frame
        scene.call("_on_button", "RUN")
        await process_frame
        scene.call("_on_button", "JUMP")
        await process_frame
        scene.call("_on_button", "IDLE")
        await process_frame
    print("AETHERFALL_CHARACTER_LAB_OK: 4 styles, 96 bones, walk/run/jump UI")
    scene.queue_free()
    quit(0)
