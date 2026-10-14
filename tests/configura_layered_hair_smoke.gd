extends SceneTree
const Hair = preload("res://scripts/configura_layered_hair_controller.gd")
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var cfg := CharacterConfig.new()
    Hair.add_configura_options(cfg)
    if cfg.options.size() != 2:
        _failed("Expected two Configura hair options")
        return
    if cfg.options[0].resource_name != "layered_bangs" or cfg.options[1].resource_name != "layered_sides":
        _failed("Wrong Configura identifiers")
        return
    var state := CharacterState.from_config(cfg)
    var frame := Node3D.new()
    root.add_child(frame)
    var parts := {}
    for label in Hair.LAYERS:
        var part := Node3D.new()
        frame.add_child(part)
        parts[label] = part
    Hair.apply_configura_state(parts, state)
    for label in Hair.LAYERS:
        if not (parts[label] as Node3D).visible:
            _failed("Unexpected hidden default layer " + label)
            return
    state.record("layered_bangs", 0)
    Hair.apply_configura_state(parts, state)
    if (parts["front_fringe"] as Node3D).visible or not (parts["side_left"] as Node3D).visible:
        _failed("Bangs toggle also changed side hair")
        return
    state.record("layered_bangs", 1)
    state.record("layered_sides", 0)
    Hair.apply_configura_state(parts, state)
    if not (parts["front_fringe"] as Node3D).visible or (parts["side_left"] as Node3D).visible or (parts["side_right"] as Node3D).visible:
        _failed("Side toggle changed bangs or left sides visible")
        return
    Hair.set_part_visibility(parts, true, true, false)
    for label in Hair.LAYERS:
        if (parts[label] as Node3D).visible:
            _failed("Bald choice did not hide " + label)
            return
    var missing := Hair.mount(frame, "male", "res://not-installed-for-unit-test")
    if bool(missing.get("ok", true)) or frame.get_child_count() != 5:
        _failed("Absent private assets must fail cleanly without partial nodes")
        return
    print("AETHERFALL_CONFIGURA_LAYERED_HAIR_OK: 5 layers, bangs and sides independently toggle, bald works, private files optional")
    quit(0)
func _failed(reason: String) -> void:
    push_error("AETHERFALL_CONFIGURA_LAYERED_HAIR_FAIL: " + reason)
    quit(1)
