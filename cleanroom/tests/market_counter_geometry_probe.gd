extends SceneTree
## Developer-only inspection of the actual imported MarketStand_1's timber geometry.
## This avoids guessing where the real selling surface is in the Quaternius model.
func _initialize() -> void:
    call_deferred("_inspect")

func _inspect() -> void:
    var packed := load("res://starter_town.tscn") as PackedScene
    var town := packed.instantiate() as Node3D
    root.add_child(town)
    for n in range(10):
        await process_frame
    var stall := town.get_node_or_null("MarketStall_-540_-610") as Node3D
    if stall == null:
        push_error("MARKET_PROBE_FAIL: stall not found")
        quit(1)
        return
    var imported := stall.get_node_or_null("Quaternius_MarketStand_1") as Node3D
    if imported == null:
        push_error("MARKET_PROBE_FAIL: model not loaded")
        quit(1)
        return
    print("MARKET_PROBE_ROOT: stall=", stall.global_position,
        " yaw=", stall.rotation_degrees.y,
        " model_pos=", imported.position, " model_scale=", imported.scale,
        " model_rot=", imported.rotation_degrees)
    for mesh_node in imported.find_children("*", "MeshInstance3D", true, false):
        var visual := mesh_node as MeshInstance3D
        if visual == null or visual.mesh == null:
            continue
        var bb := visual.get_aabb()
        var lo := Vector3(INF, INF, INF)
        var hi := Vector3(-INF, -INF, -INF)
        for ax in [0.0, 1.0]:
            for ay in [0.0, 1.0]:
                for az in [0.0, 1.0]:
                    var corner := bb.position + bb.size * Vector3(ax, ay, az)
                    var local_corner := stall.to_local(visual.to_global(corner))
                    lo = lo.min(local_corner)
                    hi = hi.max(local_corner)
        var materials := []
        for surf in range(visual.mesh.get_surface_count()):
            var m := visual.get_active_material(surf)
            materials.append(str(m.resource_name if m else "null"))
        print("MARKET_PROBE_MESH: ", str(visual.get_path()),
            " bounds=", AABB(lo, hi - lo),
            " visible=", visual.visible, " materials=", str(materials))
    for child in stall.get_children():
        if child is MeshInstance3D:
            var item := child as MeshInstance3D
            print("MARKET_PROBE_PLACEHOLDER: ", item.name,
                " visible=", item.visible, " at=", item.position)
    print("MARKET_PROBE_OK")
    town.queue_free()
    quit(0)
