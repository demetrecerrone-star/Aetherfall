extends Node3D
## Isolated Aetherfall/Configura proof-of-concept.
## Loads staged copies of user-approved bald characters; never writes to their GLBs,
## renames bones, or replaces the playable Starter Town.
## Configura supplies CharacterConfig, ColorOption, and CharacterState persistence.
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
    _model = imported
    _model.name = "ConfiguraCandidate_" + variant
    add_child(_model)
    # The supplied bald GLBs are approximately 0.98m tall.
    _model.scale = Vector3.ONE * 1.92
    current_character = variant
    character_state.metadata["character_model"] = variant
    _apply_tint()
    _message.text = variant.capitalize() + " imported. 65 joints verified.\n" + (
        "Finger joints preserved. Animation transfer, independent iris colors, "
        + "hair swaps, and garment fitting still need testing.")


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
