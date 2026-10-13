extends SceneTree
## Isolated clothing QA: corrected Tripo male + stable Universal female fallback.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene := load("res://starter_town.tscn") as PackedScene
    if scene == null:
        _fail("Missing starter town")
        return
    var town := scene.instantiate() as Node3D
    root.add_child(town)
    for i in range(16):
        await process_frame

    if not _check_corrected_male(town):
        return
    town.call("_set_motion", "WALK")
    if not _current_clip(town).to_lower().ends_with("walk"):
        _fail("Corrected male did not enter Walk")
        return
    town.call("_set_motion", "RUN")
    if not _current_clip(town).to_lower().ends_with("run"):
        _fail("Corrected male did not enter Run")
        return
    town.call("_set_motion", "IDLE")
    if String(town.call("_clip_for", "jump")).is_empty():
        _fail("Corrected male playtest Jump fallback is missing")
        return

    # Female remains the last-tested Universal model until her corrected outfit is ready.
    town.call("_switch_character")
    for i in range(16):
        await process_frame
    if not _check_universal_female(town):
        return
    town.call("_set_motion", "WALK")
    if not _current_clip(town).to_lower().ends_with("walk_loop"):
        _fail("Female should walk using Universal Walk_Loop")
        return
    town.call("_set_motion", "RUN")
    if not _current_clip(town).to_lower().ends_with("jog_fwd_loop"):
        _fail("Female should sprint using Universal Jog_Fwd_Loop")
        return

    # Switch back once to catch mixed-loader state leaks.
    town.call("_set_motion", "IDLE")
    town.call("_switch_character")
    for i in range(16):
        await process_frame
    if not _check_corrected_male(town):
        return

    print("AETHERFALL_CHARACTER_SWITCH_OK: corrected 65-bone Tripo male with embedded peasant clothes; Universal female fallback; idle/walk/run; two-way switching")
    town.queue_free()
    quit(0)

func _current_clip(town: Node) -> String:
    var player := town.get("_animation") as AnimationPlayer
    return String(player.current_animation) if player != null else ""

func _find_mesh_prefix(model: Node, prefix: String) -> MeshInstance3D:
    for node in model.find_children("*", "MeshInstance3D", true, false):
        if String(node.name).begins_with(prefix):
            return node as MeshInstance3D
    return null

func _check_corrected_male(town: Node3D) -> bool:
    if not bool(town.get("_loaded")) or not bool(town.get("_tripo_active")):
        _fail("Corrected Tripo male failed to become playable")
        return false
    if bool(town.get("_universal_active")) or String(town.get("_character_variant")) != "male":
        _fail("Male loader state is incorrect")
        return false
    var model := town.get("_model") as Node3D
    if model == null or model.name != "Tripo_male":
        _fail("Corrected Tripo male was not selected")
        return false
    if absf(model.scale.y - 0.97) > 0.001:
        _fail("Corrected male visual scale changed")
        return false
    if String(model.get_meta("equipped_outfit", "")) != "peasant_clothes_v21" or not bool(model.get_meta("starter_clothing_embedded", false)):
        _fail("Corrected embedded peasant outfit metadata missing")
        return false
    if bool(model.get_meta("tutorial_armor_unlocked", true)):
        _fail("Tutorial armor must remain locked")
        return false
    var items: Dictionary = model.get_meta("starting_equipment", {})
    if items.get("chest") != "worn_linen_tunic" or items.get("feet") != "scuffed_leather_boots":
        _fail("Corrected male starter loadout metadata is wrong")
        return false

    # These are the actual fitted Blender garments, not the old generated shells.
    for prefix in [
        "AF_Peasant_Tunic_Upper", "AF_Peasant_Tunic_Lower",
        "AF_Peasant_Sleeve_L", "AF_Peasant_Sleeve_R",
        "AF_Peasant_Belt", "AF_Peasant_Trousers_L",
        "AF_Peasant_Trousers_R", "AF_Peasant_BootFoot_L",
        "AF_Peasant_BootFoot_R"
    ]:
        var garment := _find_mesh_prefix(model, prefix)
        if garment == null or garment.mesh == null or garment.skin == null:
            _fail("Missing corrected skinned garment: " + prefix)
            return false

    var rig := town.get("_skeleton") as Skeleton3D
    var player := town.get("_animation") as AnimationPlayer
    if rig == null or player == null or rig.get_bone_count() != 65:
        _fail("Corrected male must use the 65-bone runtime rig")
        return false
    for clip in ["standing_relax", "walk", "run", "jump"]:
        if String(town.call("_clip_for", clip)).is_empty():
            _fail("Corrected male animation missing: " + clip)
            return false
    if town.get("_left_foot_index") < 0 or town.get("_right_foot_index") < 0:
        _fail("Corrected male foot bones were not found")
        return false

    var actor := town.get_node_or_null("TripoActor") as Node3D
    if actor == null or absf(actor.scale.y - 1.62) > 0.001:
        _fail("Gameplay actor scale changed for corrected male")
        return false
    print("AETHERFALL_CORRECTED_MALE_OK: embedded fitted tunic/belt/trousers/boots; 65 bones; idle/walk/run/jump QA")
    return true

func _check_universal_female(town: Node3D) -> bool:
    if not bool(town.get("_loaded")) or not bool(town.get("_universal_active")) or bool(town.get("_tripo_active")):
        _fail("Universal female fallback failed to become playable")
        return false
    if String(town.get("_character_variant")) != "female":
        _fail("Wrong female character selected")
        return false
    var model := town.get("_model") as Node3D
    if model == null or model.name != "Universal_female":
        _fail("Stable Universal female fallback was not selected")
        return false
    if absf(model.scale.y - 0.46575) > 0.0001:
        _fail("Universal female scale changed")
        return false
    if String(model.get_meta("equipped_outfit", "")) != "peasant_clothes":
        _fail("Universal female starter clothing is missing")
        return false
    var rig := town.get("_skeleton") as Skeleton3D
    var player := town.get("_animation") as AnimationPlayer
    if rig == null or player == null or rig.get_bone_count() != 65:
        _fail("Universal female rig is invalid")
        return false
    for clip in ["Idle_Loop","Walk_Loop","Sprint_Loop","Sword_Attack","Sword_Block","Interact"]:
        if String(town.call("_clip_for",clip)).is_empty():
            _fail("Universal female animation missing: "+clip)
            return false
    if player.get_animation_list().size() < 25:
        _fail("Universal female action library is incomplete")
        return false
    print("AETHERFALL_UNIVERSAL_FEMALE_OK: stable fallback preserved")
    return true

func _fail(message: String) -> void:
    push_error("AETHERFALL_CHARACTER_QA_FAIL: "+message)
    quit(1)
