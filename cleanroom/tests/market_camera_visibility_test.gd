extends SceneTree
## Verify camera sees through the market canopy without changing town walls.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Missing playable Starter Town")
        return
    var town := scene.instantiate() as Node3D
    root.add_child(town)
    for i in range(12):
        await process_frame
    var stalls := town.find_children("MarketStall_*", "Node3D", false, false)
    if stalls.size() != 4:
        _fail("Expected all four real market stands")
        return
    for node in stalls:
        var stall := node as Node3D
        if not bool(stall.get_meta("camera_awning_fade_registered", false)):
            _fail("Stall awning not registered for camera transparency")
            return
        if int(stall.get_meta("camera_awning_fade_meshes", 0)) < 1:
            _fail("No imported mesh can fade under roof")
            return
        if not bool(town.call("_market_canopy_blocks_view", stall,
                stall.to_global(Vector3(0.0, 2.0, 0.0)),
                stall.to_global(Vector3(0.0, 1.0, 2.8)))):
            _fail("Camera standing under canopy should clear roof")
            return
        if bool(town.call("_market_canopy_blocks_view", stall,
                stall.to_global(Vector3(0.0, 2.0, 5.5)),
                stall.to_global(Vector3(0.0, 1.0, 6.0)))):
            _fail("Distant stall should not fade for unobstructed camera")
            return
        if not bool(town.call("_market_canopy_blocks_view", stall,
                stall.to_global(Vector3(0.0, 3.65, 3.0)),
                stall.to_global(Vector3(0.0, 1.0, 0.0)))):
            _fail("Canopy obscuring player must fade")
            return
    var first_stall := stalls[0] as Node3D
    var camera := town.get_node_or_null("OrbitCamera") as Camera3D
    var actor := town.get_node_or_null("TripoActor") as Node3D
    if camera == null or actor == null:
        _fail("Gameplay camera/actor missing")
        return
    actor.global_position = first_stall.to_global(Vector3(0.0, 0.0, 2.5))
    camera.global_position = first_stall.to_global(Vector3(0.0, 2.0, 0.0))
    town.call("_update_market_canopy_fades", 1.0)
    var entries: Array = town.get("_market_canopy_fades")
    if entries.size() != 4:
        _fail("Four stalls must have independent camera occluders")
        return
    var first: Dictionary = entries[0]
    if float(first["fade"]) < 0.88:
        _fail("Nearby imported awning did not fade")
        return
    for data in first["meshes"]:
        var mesh: MeshInstance3D = data["mesh"]
        if mesh.transparency < 0.88:
            _fail("Imported Quaternius roof does not turn transparent")
            return
    camera.global_position = first_stall.to_global(Vector3(0.0, 2.0, 6.0))
    actor.global_position = first_stall.to_global(Vector3(0.0, 0.0, 6.5))
    town.call("_update_market_canopy_fades", 1.0)
    if float(first["fade"]) > 0.01:
        _fail("Awning did not return to opaque after moving away")
        return
    var blocked: Vector3 = town.call("_camera_safe_goal", Vector3(23.0, 1.6, 0.0), Vector3(32.0, 1.6, 0.0))
    if blocked.x > 27.0:
        _fail("Awnings change inadvertently disabled perimeter walls")
        return
    print("AETHERFALL_MARKET_CAMERA_OK: 4 independently fading stall roofs; walls still solid; restore works")
    town.queue_free()
    quit(0)

func _fail(message: String) -> void:
    push_error("AETHERFALL_MARKET_CAMERA_FAIL: " + message)
    quit(1)
