extends SceneTree
## Configura candidate studio smoke test without publishing an APK or GLBs.
## Actual uploaded models are verified separately by tools/stage_tripo_configura_candidates.py.
func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("CONFIGURA_STAGE_1_LOADING_SCENE")
    var candidate_scene := load("res://scenes/configura_candidate_studio.tscn") as PackedScene
    if candidate_scene == null:
        _fail("Candidate studio scene does not parse")
        return
    var node := candidate_scene.instantiate() as Node3D
    if node == null:
        _fail("Candidate studio is not a Node3D")
        return
    print("CONFIGURA_STAGE_2_SCENE_INSTANCE")
    root.add_child(node)
    await process_frame
    print("CONFIGURA_STAGE_3_FIRST_FRAME")

    print("CONFIGURA_STAGE_4_CHECKING_CONFIG")
    var config := node.get("character_config") as CharacterConfig
    var state := node.get("character_state") as CharacterState
    if config == null or state == null:
        _fail("Configura config/state did not initialize")
        return
    if config.options.size() != 6:
        _fail("Expected body, hairstyle, hair and iris options")
        return
    var expected := ["prototype_base_tint", "hairstyle", "hair_color", "iris_color", "layered_bangs", "layered_sides"]
    for i in range(expected.size()):
        if config.options[i].resource_name != expected[i]:
            _fail("Configura option missing: " + expected[i])
            return
    var screen := node.find_child("ConfiguraCandidateControls", true, false)
    if screen == null:
        _fail("Candidate selection interface is missing")
        return
    print("CONFIGURA_STAGE_5_CHECKING_COLORS")
    node.call("_toggle_hair_layer", "layered_bangs")
    if int(state.values.get("layered_bangs", 1)) != 0:
        _fail("Bangs toggle was not recorded in Configura")
        return
    node.call("_toggle_hair_layer", "layered_sides")
    if int(state.values.get("layered_sides", 1)) != 0:
        _fail("Side toggle was not recorded in Configura")
        return
    node.call("_choose_tint", 2)
    if state.values.get("prototype_base_tint") != Color("#bb886a"):
        _fail("Configura ColorOption not recorded in CharacterState")
        return

    node.call("_choose_hairstyle", 2)
    node.call("_choose_hair_color", 2)
    node.call("_choose_iris_color", 1)
    if state.values.get("hairstyle") != 2:
        _fail("Hair swap choice was not recorded")
        return
    if state.values.get("hair_color") != Color("#b2b9cf"):
        _fail("Hair color was not recorded independently")
        return
    if state.values.get("iris_color") != Color("#42ad7c"):
        _fail("Eye iris color was not recorded independently")
        return

    # Missing private GLBs should give a useful UI explanation, not crash.
    print("CONFIGURA_STAGE_6_CHECKING_MISSING_MODEL_UI")
    node.call("_load_character", "female")
    var message := node.find_child("CandidateStatus", true, false) as Label
    if message == null or message.text.is_empty():
        _fail("Studio did not provide an import status")
        return
    if str(node.get("current_character")) not in ["male", "female"]:
        _fail("Studio accepted an unknown character type")
        return
    print("CONFIGURA_STAGE_7_COMPLETE")
    print("AETHERFALL_CONFIGURA_CANDIDATE_STUDIO_OK: model, three appearance options, isolated color state, UI initialized")
    node.queue_free()
    quit(0)


func _fail(reason: String) -> void:
    push_error("AETHERFALL_CONFIGURA_CANDIDATE_STUDIO_FAIL: " + reason)
    quit(1)
