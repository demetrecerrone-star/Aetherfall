extends SceneTree
## Configura candidate studio smoke test without publishing an APK or GLBs.
## Actual uploaded models are verified separately by tools/stage_tripo_configura_candidates.py.
func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var candidate_scene := load("res://scenes/configura_candidate_studio.tscn") as PackedScene
    if candidate_scene == null:
        _fail("Candidate studio scene does not parse")
        return
    var node := candidate_scene.instantiate() as Node3D
    if node == null:
        _fail("Candidate studio is not a Node3D")
        return
    root.add_child(node)
    await process_frame

    var config := node.get("character_config") as CharacterConfig
    var state := node.get("character_state") as CharacterState
    if config == null or state == null:
        _fail("Configura config/state did not initialize")
        return
    if config.options.size() != 1 or config.options[0].resource_name != "prototype_base_tint":
        _fail("Expected the explicitly scoped prototype tint option")
        return
    var screen := node.find_child("ConfiguraCandidateControls", true, false)
    if screen == null:
        _fail("Candidate selection interface is missing")
        return
    node.call("_choose_tint", 2)
    if state.values.get("prototype_base_tint") != Color("#bb886a"):
        _fail("Configura ColorOption not recorded in CharacterState")
        return

    # Missing private GLBs should give a useful UI explanation, not crash.
    node.call("_load_character", "female")
    var message := node.find_child("CandidateStatus", true, false) as Label
    if message == null or message.text.is_empty():
        _fail("Studio did not provide an import status")
        return
    if str(node.get("current_character")) not in ["male", "female"]:
        _fail("Studio accepted an unknown character type")
        return
    print("AETHERFALL_CONFIGURA_CANDIDATE_STUDIO_OK: scene loads, state created, tint recorded, UI initialized")
    node.queue_free()
    quit(0)


func _fail(reason: String) -> void:
    push_error("AETHERFALL_CONFIGURA_CANDIDATE_STUDIO_FAIL: " + reason)
    quit(1)
