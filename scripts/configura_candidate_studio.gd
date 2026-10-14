extends Node3D
## Isolated Aetherfall/Configura proof-of-concept.
## Loads staged copies of user-approved bald characters; never writes to their GLBs,
## renames bones, or replaces the playable Starter Town.
## Configura supplies CharacterConfig, ColorOption, and CharacterState persistence.
const FaceHairAttachments = preload("res://scripts/configura_face_hair_attachments.gd")
const CANDIDATE_DIR := "res://assets/characters/configura_candidates/"
const PROFILE_PATH := "user://aetherfall_configura_candidate_state.tres"
const CHARACTER_IDS := ["male", "female"]
const COLOR_PRESETS := [
    Color("#bfc5d0"), Color("#dfbba0"), Color("#bb886a"),
    Color("#8a5d47"), Color("#6b82a9")
]

var character_config: CharacterConfig
var character_state: CharacterState
var current_character := "male"
var _model: Node3D
var _camera: Camera3D
var _message: Label
const HAIR_PRESETS := [Color("#343047"), Color("#745046"), Color("#b2b9cf"), Color("#be7651"), Color("#d5b071")]
const IRIS_PRESETS := [Color("#478bd1"), Color("#42ad7c"), Color("#ad76db"), Color("#8e5f38"), Color("#e3b451")]
var _appearance: Dictionary = {}
var _swatch_index := 0
var _orbit := 0.0


func _ready() -> void:
    _setup_configura_state()
    _setup_preview_scene()
    _setup_ui()
    _load_character(current_character)


func _setup_configura_state() -> void:
    character_config = CharacterConfig.new()
    character_config.resource_name = "Aetherfall Bald Base Candidates"
    character_config.allow_randomize = false
    character_config.preview_camera_distance = 3.6
    character_config.preview_camera_height = 1.0
    character_config.state_save_path = PROFILE_PATH.trim_prefix("user://")

    # Only whole-mesh tint is currently available. This is deliberately NOT
    # advertised as eye/skin/outfit masking: the GLBs have no material groups.
    var tint := ColorOption.new()
    tint.resource_name = "prototype_base_tint"
    tint.display_name = "Prototype Base Tint"
    tint.group = "Base Prototype"
    tint.default_color = COLOR_PRESETS[0]
    character_config.options.append(tint)
    # Configura option data types, with an isolated custom preview UI.
    var hair_swap := MeshSwapOption.new()
    hair_swap.resource_name = "hairstyle"
    hair_swap.display_name = "Hairstyle"
    hair_swap.group = "Hair"
    hair_swap.default_choice = 1
    for label in ["Bald", "Style 1", "Style 2"]:
        var choice := MeshSwapChoice.new()
        choice.label = label
        hair_swap.choices.append(choice)
    character_config.options.append(hair_swap)

    var hair_color := ColorOption.new()
    hair_color.resource_name = "hair_color"
    hair_color.display_name = "Hair Color"
    hair_color.group = "Hair"
    hair_color.default_color = HAIR_PRESETS[0]
    character_config.options.append(hair_color)

    var iris_color := ColorOption.new()
    iris_color.resource_name = "iris_color"
    iris_color.display_name = "Iris Color"
    iris_color.group = "Eyes"
    iris_color.default_color = IRIS_PRESETS[0]
    character_config.options.append(iris_color)

    character_state = CharacterState.from_config(character_config)
    if ResourceLoader.exists(PROFILE_PATH):
        var loaded := ResourceLoader.load(
            PROFILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterState
        if loaded != null:
            character_state = loaded
    var chosen := str(character_state.metadata.get("character_model", "male"))
    current_character = chosen if chosen in CHARACTER_IDS else "male"


func _setup_preview_scene() -> void:
    var env := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("#182032")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("#d2e0f8")
    settings.ambient_light_energy = 0.9
    env.environment = settings
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-35, -30, 0)
    sun.light_energy = 1.3
    add_child(sun)

    _camera = Camera3D.new()
    _camera.name = "ConfiguraCandidateCamera"
    _camera.position = Vector3(0.0, 1.06, 3.65)
    _camera.current = true
    _camera.fov = 42
    add_child(_camera)
    _camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)

    var pad := MeshInstance3D.new()
    pad.name = "PreviewPad"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.72
    cylinder.bottom_radius = 0.79
    cylinder.height = 0.09
    pad.mesh = cylinder
    pad.position.y = -0.06
    var finish := StandardMaterial3D.new()
    finish.albedo_color = Color("#455473")
    pad.material_override = finish
    add_child(pad)


func _setup_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var stack := VBoxContainer.new()
    stack.name = "ConfiguraCandidateControls"
    stack.position = Vector2(24.0, 28.0)
    stack.custom_minimum_size = Vector2(312, 0)
    layer.add_child(stack)

    var heading := Label.new()
    heading.text = "AETHERFALL / CONFIGURA LAB"
    heading.add_theme_font_size_override("font_size", 24)
    stack.add_child(heading)
    var caption := Label.new()
    caption.text = "Rig-safe model preview • No animations yet"
    stack.add_child(caption)

    var row := HBoxContainer.new()
    stack.add_child(row)
    for variant in CHARACTER_IDS:
        var button := Button.new()
        button.name = "Choose_" + variant
        button.text = variant.to_upper()
        button.custom_minimum_size = Vector2(142, 54)
        button.pressed.connect(_load_character.bind(variant))
        row.add_child(button)

    var hair_heading := Label.new()
    hair_heading.text = "HAIR STYLE (BONE-ATTACHED PROTOTYPE)"
    stack.add_child(hair_heading)
    var choices := HBoxContainer.new()
    stack.add_child(choices)
    for index in range(3):
        var option := Button.new()
        option.name = "HairStyle_" + str(index)
        option.text = ["BALD", "SHORT", "LONG"][index]
        option.custom_minimum_size = Vector2(95, 48)
        option.pressed.connect(_choose_hairstyle.bind(index))
        choices.add_child(option)

    var hair_heading_color := Label.new()
    hair_heading_color.text = "HAIR COLOR"
    stack.add_child(hair_heading_color)
    var hair_swatches := HBoxContainer.new()
    stack.add_child(hair_swatches)
    for index in range(HAIR_PRESETS.size()):
        var option := Button.new()
        option.name = "HairColor_" + str(index)
        option.text = str(index + 1)
        option.modulate = HAIR_PRESETS[index]
        option.custom_minimum_size = Vector2(56, 48)
        option.pressed.connect(_choose_hair_color.bind(index))
        hair_swatches.add_child(option)

    var iris_heading := Label.new()
    iris_heading.text = "IRIS COLOR (EYES ONLY)"
    stack.add_child(iris_heading)
    var iris_swatches := HBoxContainer.new()
    stack.add_child(iris_swatches)
    for index in range(IRIS_PRESETS.size()):
        var option := Button.new()
        option.name = "IrisColor_" + str(index)
        option.text = str(index + 1)
        option.modulate = IRIS_PRESETS[index]
        option.custom_minimum_size = Vector2(56, 48)
        option.pressed.connect(_choose_iris_color.bind(index))
        iris_swatches.add_child(option)

    var tint_label := Label.new()
    tint_label.text = "WHOLE-MODEL COLOR TEST"
    stack.add_child(tint_label)
    var swatches := HBoxContainer.new()
    stack.add_child(swatches)
    for index in range(COLOR_PRESETS.size()):
        var swatch := Button.new()
        swatch.name = "Tint_" + str(index)
        swatch.text = str(index + 1)
        swatch.custom_minimum_size = Vector2(56, 48)
        swatch.modulate = COLOR_PRESETS[index]
        swatch.pressed.connect(_choose_tint.bind(index))
        swatches.add_child(swatch)

    var button_save := Button.new()
    button_save.name = "SaveConfiguraChoice"
    button_save.text = "SAVE PREVIEW CHOICES"
    button_save.custom_minimum_size.y = 56
    button_save.pressed.connect(_save_state)
    stack.add_child(button_save)

    _message = Label.new()
    _message.name = "CandidateStatus"
    _message.custom_minimum_size = Vector2(320, 150)
    _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(_message)
    _message.text = "Loading candidate...\nDrag the model to orbit."


func _load_character(variant: String) -> void:
    if not variant in CHARACTER_IDS:
        return
    var source := CANDIDATE_DIR + variant + "_runtime.bin"
    if not FileAccess.file_exists(source):
        _message.text = "Candidate not staged: " + variant + ".\n" + (
            "Run tools/stage_tripo_configura_candidates.py on the two supplied GLBs.")
        return
    var doc := GLTFDocument.new()
    var gltf_state := GLTFState.new()
    var result := doc.append_from_buffer(FileAccess.get_file_as_bytes(source), "", gltf_state)
    if result != OK:
        _message.text = "GLB import failed for " + variant + " (" + str(result) + ")"
        return
    var imported := doc.generate_scene(gltf_state) as Node3D
    if imported == null:
        _message.text = "Could not generate candidate scene."
        return

    var skeletons := imported.find_children("*", "Skeleton3D", true, false)
    if skeletons.size() != 1 or (skeletons[0] as Skeleton3D).get_bone_count() != 65:
        imported.queue_free()
        _message.text = "Candidate skeleton failed the 65-joint compatibility gate."
        return

    if _model != null:
        _model.queue_free()
        _model = null
        _appearance.clear()
    _model = imported
    _model.name = "ConfiguraCandidate_" + variant
    add_child(_model)
    # The supplied bald GLBs are approximately 0.98m tall.
    _model.scale = Vector3.ONE * 1.92
    current_character = variant
    character_state.metadata["character_model"] = variant
    # Apply body tint before creating independent eye/hair meshes.
    _apply_tint()
    _appearance = FaceHairAttachments.mount(_model, variant)
    if _appearance.is_empty():
        _message.text = "Could not create 65-bone head attachments."
        return
    _sync_appearance()
    _message.text = variant.capitalize() + " imported. 65 joints verified.\n" + (
        "Finger joints preserved. Hair/eye options are separately attached. "
        + "Animation and garment fitting still need testing.")


func _sync_appearance() -> void:
    if _appearance.is_empty():
        return
    var hair_selection: int = int(character_state.values.get("hairstyle", 1))
    FaceHairAttachments.select_hairstyle(_appearance, hair_selection - 1)
    var hair: Variant = character_state.values.get("hair_color", HAIR_PRESETS[0])
    var iris: Variant = character_state.values.get("iris_color", IRIS_PRESETS[0])
    FaceHairAttachments.color_hair(_appearance, hair if hair is Color else HAIR_PRESETS[0])
    FaceHairAttachments.color_iris(_appearance, iris if iris is Color else IRIS_PRESETS[0])


func _choose_hairstyle(index: int) -> void:
    if index < 0 or index > 2:
        return
    character_state.record("hairstyle", index)
    _sync_appearance()


func _choose_hair_color(index: int) -> void:
    if index < 0 or index >= HAIR_PRESETS.size():
        return
    character_state.record("hair_color", HAIR_PRESETS[index])
    _sync_appearance()


func _choose_iris_color(index: int) -> void:
    if index < 0 or index >= IRIS_PRESETS.size():
        return
    character_state.record("iris_color", IRIS_PRESETS[index])
    _sync_appearance()


func _choose_tint(index: int) -> void:
    if index < 0 or index >= COLOR_PRESETS.size():
        return
    _swatch_index = index
    character_state.record("prototype_base_tint", COLOR_PRESETS[index])
    _apply_tint()


func _apply_tint() -> void:
    if _model == null:
        return
    var tint: Variant = character_state.values.get("prototype_base_tint", COLOR_PRESETS[0])
    if not tint is Color:
        tint = COLOR_PRESETS[0]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.0
    mat.roughness = 0.9
    for item in _model.find_children("*", "MeshInstance3D", true, false):
        if not _appearance.is_empty():
            var attachment := _appearance.get("attachment") as Node3D
            if attachment != null and attachment.is_ancestor_of(item):
                continue
        (item as MeshInstance3D).material_override = mat


func _save_state() -> void:
    character_state.metadata["character_model"] = current_character
    var err := ResourceSaver.save(character_state, PROFILE_PATH)
    _message.text = ("Preview choices saved locally." if err == OK
        else "Could not save preview choices: " + str(err))


func _unhandled_input(event: InputEvent) -> void:
    if _model == null:
        return
    if event is InputEventScreenDrag:
        _orbit -= event.relative.x * 0.005
        _model.rotation.y = _orbit
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _orbit -= event.relative.x * 0.005
        _model.rotation.y = _orbit
