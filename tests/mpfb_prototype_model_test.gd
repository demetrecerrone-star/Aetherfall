extends SceneTree
## Isolated Godot import check for four MPFB/Rigify skinned anime variants.
## Does not alter the existing playable Aetherfall character scene.
func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var variants := {
        "Windswept": "prototype.glb",
        "Long": "long.glb",
        "Short": "short.glb",
        "Ponytail": "ponytail.glb"
    }
    for style in variants.keys():
        var path: String = "res://" + String(variants[style])
        var asset: PackedScene = load(path)
        if asset == null:
            push_error("MPFB_GODOT_FAIL: missing or unimported " + path)
            quit(1)
            return
        var character := asset.instantiate()
        root.add_child(character)
        await process_frame
        var stack: Array[Node] = [character]
        var mesh_count := 0
        var rig_count := 0
        var bone_count := 0
        var essential_legs := 0
        var skinned_meshes := 0
        var hair_count := 0
        var outfit_count := 0
        var wrong_hair_count := 0
        while not stack.is_empty():
            var node: Node = stack.pop_back()
            if node is MeshInstance3D:
                mesh_count += 1
                if node.skin != null or not node.skeleton.is_empty():
                    skinned_meshes += 1
                if str(node.name).begins_with("Hair_"):
                    if str(node.name).begins_with("Hair_" + style + "_"):
                        hair_count += 1
                    else:
                        wrong_hair_count += 1
                if str(node.name).begins_with("Outfit_Adventurer"):
                    outfit_count += 1
            elif node is Skeleton3D:
                rig_count += 1
                var skeleton := node as Skeleton3D
                bone_count = maxi(bone_count, skeleton.get_bone_count())
                for joint in ["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L", "DEF-thigh.R", "DEF-shin.R", "DEF-foot.R"]:
                    if skeleton.find_bone(joint) >= 0:
                        essential_legs += 1
            for child in node.get_children():
                stack.append(child)
        print("MPFB_GODOT_STATS %s: meshes=%d skeletons=%d bones=%d skinned=%d hair=%d outfit=%d wrong_hair=%d" % [
            style, mesh_count, rig_count, bone_count, skinned_meshes,
            hair_count, outfit_count, wrong_hair_count
        ])
        # A mobile-ready rig must preserve hip/knee/ankle chains, without
        # exporting the original 181 deformation bones / 930 control bones.
        var ok := (
            rig_count == 1 and mesh_count >= 20
            and bone_count >= 96 and bone_count <= 98
            and essential_legs == 6 and skinned_meshes == mesh_count
            and hair_count >= 8 and outfit_count >= 25 and wrong_hair_count == 0
        )
        print("MPFB_GODOT_MOBILE_LEG_JOINTS %s: %d/6" % [style, essential_legs])
        character.queue_free()
        await process_frame
        if not ok:
            push_error("MPFB_GODOT_FAIL: broken style, costume or skinning for " + style)
            quit(1)
            return
    print("MPFB_GODOT_IMPORT_OK: all four anime hairstyle variants are skinned")
    quit(0)
