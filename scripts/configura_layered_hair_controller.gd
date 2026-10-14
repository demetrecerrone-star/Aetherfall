extends RefCounted
## Aetherfall v94: private-model-safe modular hair pilot.
## Attach the five fitted model-space GLBs to the existing Head BoneAttachment
## frame. Never mutate the original models or skeleton.
const LAYERS := ["crown_top", "back_and_nape", "side_left", "side_right", "front_fringe"]
const ROOT_PATH := "res://assets/characters/configura_candidates/hair_layers/"
const BANGS_KEY := "layered_bangs"
const SIDES_KEY := "layered_sides"

static func add_configura_options(config: CharacterConfig) -> void:
    for info in [
        {"id": BANGS_KEY, "label": "Bangs"},
        {"id": SIDES_KEY, "label": "Side Locks"}
    ]:
        var opt := MeshSwapOption.new()
        opt.resource_name = info["id"]
        opt.display_name = info["label"]
        opt.group = "Hair Layers"
        opt.default_choice = 1
        for label in ["Off", "On"]:
            var choice := MeshSwapChoice.new()
            choice.label = label
            opt.choices.append(choice)
        config.options.append(opt)

static func mount(frame: Node3D, variant: String, parent_path: String = ROOT_PATH) -> Dictionary:
    if variant not in ["male", "female"]:
        return {"ok": false, "reason": "unknown character variant"}
    var files: Dictionary = {}
    for label in LAYERS:
        var file_path := parent_path.path_join(variant).path_join(label + "_runtime.bin")
        if not FileAccess.file_exists(file_path):
            return {"ok": false, "reason": "missing fitted layer: " + file_path}
        files[label] = file_path
    var imported: Dictionary = {}
    var staged: Array[Node3D] = []
    for label in LAYERS:
        var document := GLTFDocument.new()
        var state := GLTFState.new()
        var err := document.append_from_buffer(FileAccess.get_file_as_bytes(files[label]), "", state)
        if err != OK:
            for item in staged:
                item.free()
            return {"ok": false, "reason": "cannot read " + label + ": " + str(err)}
        var node := document.generate_scene(state) as Node3D
        if node == null:
            for item in staged:
                item.free()
            return {"ok": false, "reason": "cannot generate " + label}
        node.name = "Layer_" + label
        staged.append(node)
        imported[label] = node
    for node in staged:
        frame.add_child(node)
    return {"ok": true, "layers": imported, "variant": variant}

static func set_part_visibility(parts: Dictionary, bangs_enabled: bool, sides_enabled: bool, hair_enabled: bool = true) -> void:
    for label in LAYERS:
        var node := parts.get(label) as Node3D
        if node == null:
            continue
        var show := hair_enabled
        if label == "front_fringe":
            show = show and bangs_enabled
        elif label in ["side_left", "side_right"]:
            show = show and sides_enabled
        node.visible = show

static func apply_configura_state(parts: Dictionary, state: CharacterState, hair_enabled: bool = true) -> void:
    var bangs := int(state.values.get(BANGS_KEY, 1)) == 1
    var sides := int(state.values.get(SIDES_KEY, 1)) == 1
    set_part_visibility(parts, bangs, sides, hair_enabled)

static func color_hair(parts: Dictionary, value: Color) -> void:
    var finish := StandardMaterial3D.new()
    finish.albedo_color = value
    finish.roughness = 0.83
    for label in LAYERS:
        var node := parts.get(label) as Node3D
        if node == null:
            continue
        for item in node.find_children("*", "MeshInstance3D", true, false):
            (item as MeshInstance3D).material_override = finish
