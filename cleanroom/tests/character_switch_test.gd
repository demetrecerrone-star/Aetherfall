extends SceneTree
## Tripo peasant integration: validates both imported 65-bone rigs in playable town.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://starter_town.tscn") as PackedScene
    if packed == null:
        _fail("Town scene missing")
        return
    var town := packed.instantiate() as Node3D
    root.add_child(town)
    for i in range(15):
        await process_frame
    if not _check(town, "male"):
        return
    for clip in ["WALK", "RUN", "IDLE"]:
        town.call("_set_motion", clip)
        var player := town.get("_animation") as AnimationPlayer
        var current := String(player.current_animation).to_lower()
        var expected: String = "standing_relax" if clip == "IDLE" else clip.to_lower()
        if not current.ends_with(expected):
            _fail("Male animation "+clip+" got "+current)
            return
    town.call("_switch_character")
    for i in range(15):
        await process_frame
    if not _check(town, "female"):
        return
    for clip in ["WALK", "RUN", "IDLE"]:
        town.call("_set_motion", clip)
        var player := town.get("_animation") as AnimationPlayer
        var current := String(player.current_animation).to_lower()
        var expected: String = "idle" if clip == "IDLE" else clip.to_lower()
        if not current.ends_with(expected):
            _fail("Female animation "+clip+" got "+current)
            return
    print("AETHERFALL_CHARACTER_SWITCH_OK: Tripo male/female 65 bones, peasant gear, idle/walk/run, camera fade and ground contacts")
    quit(0)

func _check(town: Node3D, gender: String) -> bool:
    if not bool(town.get("_loaded")) or not bool(town.get("_tripo_active")):
        return _fail_bool("Tripo player did not initialize: "+gender)
    if String(town.get("_character_variant")) != gender:
        return _fail_bool("Wrong gender")
    var model := town.get("_model") as Node3D
    if model == null or model.name != "Tripo_"+gender:
        return _fail_bool("Wrong model loaded: "+gender)
    if absf(model.scale.y-0.97) > 0.0001:
        return _fail_bool("Tripo character scale mismatch")
    if String(model.get_meta("equipped_outfit", "")) != "tripo_peasant":
        return _fail_bool("Imported peasant clothing is not equipped")
    if bool(model.get_meta("tutorial_armor_unlocked", true)):
        return _fail_bool("Tutorial armor should not be unlocked")
    var rig := town.get("_skeleton") as Skeleton3D
    var player := town.get("_animation") as AnimationPlayer
    if rig == null or player == null or rig.get_bone_count() != 65 or player.get_animation_list().size() < 3:
        return _fail_bool("Tripo rig or animation clips missing")
    if int(model.get_meta("peasant_skinned_parts", 0)) != 15:
        return _fail_bool("All 15 fitted garment parts must be present")
    if int(model.get_meta("concealed_body_parts", 0)) != 12:
        return _fail_bool("Concealed geometry must hide the 12 covered body sections")
    for name in ["AF_HeadAndHair", "AF_LeftHand", "AF_RightHand"]:
        var mesh := model.find_child(name, true, false) as MeshInstance3D
        if mesh == null or not mesh.visible or mesh.skin == null:
            return _fail_bool("Uncovered body mesh hidden or not skinned: "+name)
    var gear_count := 0
    for mesh in model.find_children("*", "MeshInstance3D", true, false):
        if String(mesh.name).begins_with("AF_Gear_"):
            if not mesh.visible or mesh.mesh == null or mesh.skin == null:
                return _fail_bool("Equipped gear is not visible/skinned")
            gear_count += 1
    if gear_count != 15:
        return _fail_bool("Expected 15 equipped peasant garment meshes")
    if town.get("_left_foot_index") < 0 or town.get("_right_foot_index") < 0:
        return _fail_bool("Foot bones missing")
    if (town.get("_camera_fade_surfaces") as Array).size() < 15:
        return _fail_bool("Close-wall camera fade did not cache clothing materials")
    var actor := town.get_node_or_null("TripoActor") as Node3D
    if actor == null or absf(actor.scale.y-1.62) > 0.001:
        return _fail_bool("Actor collision scale changed")
    var road: float = town.call("_ground_surface_y",actor.global_position)
    var sole: float = town.call("_sole_floor_y")
    if absf(road-sole)>0.18:
        return _fail_bool("Foot grounding difference: "+str(road-sole))
    var constants: Dictionary = town.get_script().get_script_constant_map()
    if absf(float(constants.get("RUN_WORLD_SPEED",-1.0))-5.0)>0.001:
        return _fail_bool("Sprint speed regression")
    return true

func _fail_bool(message: String) -> bool:
    _fail(message)
    return false

func _fail(message: String) -> void:
    push_error("AETHERFALL_CHARACTER_QA_FAIL: "+message)
    quit(1)
