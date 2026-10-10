extends SceneTree
## Standalone isolated Godot import check for MPFB/Rigify 3D skinned prototype.
## This does NOT replace res://scenes/player.tscn or the existing Aetherfall rig.
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var avatar: PackedScene = load("res://prototype.glb")
    if avatar == null:
        push_error("MPFB_GODOT_FAIL: GLB missing or not imported")
        quit(1)
        return
    var character: Node = avatar.instantiate()
    root.add_child(character)
    await process_frame
    var stack: Array[Node] = [character]
    var mesh_count := 0
    var rig_count := 0
    var bone_count := 0
    var skinned_meshes := 0
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            mesh_count += 1
            if node.skin != null or not node.skeleton.is_empty():
                skinned_meshes += 1
        elif node is Skeleton3D:
            rig_count += 1
            bone_count = maxi(bone_count,(node as Skeleton3D).get_bone_count())
        for child in node.get_children():
            stack.append(child)
    print("MPFB_GODOT_STATS: meshes=%d skeletons=%d bones=%d skinned_meshes=%d" % [
        mesh_count,rig_count,bone_count,skinned_meshes
    ])
    if rig_count >= 1 and mesh_count >= 1 and bone_count >= 40 and skinned_meshes >= 1:
        print("MPFB_GODOT_IMPORT_OK")
        quit(0)
    else:
        push_error("MPFB_GODOT_FAIL: skeleton, skin or mesh lost in exported GLB")
        quit(1)
