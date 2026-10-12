extends Node3D
## Touch-first character equipment studio. This is a completely separate APK.

const AVATAR_SCRIPT := "res://scripts/studio_avatar.gd"
const ACCENT := Color(0.93, 0.73, 0.37)
const PALE := Color(0.94, 0.92, 0.86)
const SUBTLE := Color(0.62, 0.70, 0.79)
const PANEL := Color(0.054, 0.073, 0.115, 0.965)
const DEEP := Color(0.035, 0.044, 0.080, 0.98)
const PROFILE_FILE := "user://aetherfall_hero_profile_v1.json"
const TABS := ["BODY", "HAIR", "FACE", "VIEW"]
const TAB_KEYS := {
    "BODY": ["gender", "skin", "height_down", "height_up", "appearance_reset", "neck_fit"],
    "HAIR": ["hair_previous", "hair_next", "hair_color", "beard"],
    "FACE": ["eye_color", "eye_style", "view_face"],
    "VIEW": ["view_reset", "zoom_in", "zoom_out", "view_face_copy"]
}
const SKIN_SWATCHES := [
    Color("f5dfc5"), Color("eecbad"), Color("d9a87e"), Color("b18a67"),
    Color("a16e4e"), Color("74503d"), Color("4b342c")
]
const HAIR_SWATCHES := [
    Color("b9b0a4"), Color("865134"), Color("282a39"), Color("f1c976"),
    Color("d36c35"), Color("dce3f0"), Color("4c7dc9"), Color("d78eab")
]
const EYE_SWATCHES := [
    Color("835436"), Color("478dca"), Color("4c9b70"), Color("9a8654"),
    Color("8e9fa9"), Color("8f68bb")
]
var avatar
var camera: Camera3D
var status_label: Label
var instruction_label: Label
var heading_label: Label
var error_label: Label
var profile_name_field: LineEdit
var buttons: Dictionary = {}
var busy: bool = true
var pending_gender: String = "male"
var loading_id: int = 0
var touch_points: Dictionary = {}
var last_pinch_distance: float = 0.0
var last_pinch_midpoint: Vector2 = Vector2.ZERO
var mouse_held: bool = false
var zoom_distance: float = 3.50
var camera_pan_y: float = 0.0
const ZOOM_MIN := 0.95
const ZOOM_MAX := 6.0
const PAN_MIN := -0.70
const PAN_MAX := 1.50
var rotation_y: float = 0.0
var appearance_page: int = 0
var pending_profile: Dictionary = {}
var keep_rotation_on_reload: bool = false
var swatches: Dictionary = {}
var page_labels: Dictionary = {}
var current_profile_name: String = "Adventurer"

func _ready() -> void:
    _build_studio_environment()
    _build_interface()
    # Only dismiss native-scene startup fallback once interface exists.
    var fallback := get_node_or_null("StartupFallback") as CanvasLayer
    if fallback != null:
        fallback.visible = false
    _set_status("STARTING STUDIO", "Preparing character preview...")
    var script_resource = load(AVATAR_SCRIPT)
    if script_resource == null:
        _set_error("AF-STUDIO-001", "Avatar controller file was not bundled")
        return
    avatar = script_resource.new()
    if avatar == null:
        _set_error("AF-STUDIO-002", "Unable to create avatar controller")
        return
    avatar.name = "ModularAvatar"
    add_child(avatar)
    _update_buttons()
    _restore_profile_on_launch()
    _start_loading.call_deferred()

func _build_studio_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.090, 0.106, 0.158)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.76, 0.80, 0.95)
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    var world := WorldEnvironment.new()
    world.environment = environment
    add_child(world)
    var warm := DirectionalLight3D.new()
    warm.rotation_degrees = Vector3(-38, 25, 0)
    warm.light_energy = 1.75
    warm.light_color = Color(1.0, 0.90, 0.77)
    warm.shadow_enabled = true
    add_child(warm)
    var cool := OmniLight3D.new()
    cool.position = Vector3(-1.8, 2.3, -1.8)
    cool.light_energy = 1.2
    cool.omni_range = 5.0
    cool.light_color = Color(0.53, 0.67, 1.0)
    add_child(cool)
    _make_pedestal()
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 40.0
    camera.near = 0.08
    camera.far = 40.0
    add_child(camera)
    _update_camera()

func _make_pedestal() -> void:
    var base := CylinderMesh.new()
    base.top_radius = 1.18
    base.bottom_radius = 1.26
    base.height = 0.14
    base.radial_segments = 64
    var platform := MeshInstance3D.new()
    platform.mesh = base
    platform.position.y = -0.15
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.16, 0.18, 0.27)
    mat.metallic = 0.32
    mat.roughness = 0.6
    platform.material_override = mat
    add_child(platform)
    var trim := CylinderMesh.new()
    trim.top_radius = 1.29
    trim.bottom_radius = 1.29
    trim.height = 0.04
    trim.radial_segments = 64
    var trim_mesh := MeshInstance3D.new()
    trim_mesh.mesh = trim
    trim_mesh.position.y = -0.235
    var trim_mat := StandardMaterial3D.new()
    trim_mat.albedo_color = Color(0.74, 0.52, 0.23)
    trim_mat.metallic = 0.7
    trim_mat.roughness = 0.42
    trim_mesh.material_override = trim_mat
    add_child(trim_mesh)
    var rune_mat := StandardMaterial3D.new()
    rune_mat.albedo_color = Color(0.97, 0.72, 0.35)
    rune_mat.emission_enabled = true
    rune_mat.emission = Color(0.34, 0.22, 0.09)
    rune_mat.emission_energy_multiplier = 0.7
    rune_mat.roughness = 0.37
    for i in range(20):
        var rune := MeshInstance3D.new()
        rune.name = "PedestalMarker_%02d" % i
        var cube := BoxMesh.new()
        cube.size = Vector3(0.046, 0.011, 0.115 if i % 5 == 0 else 0.065)
        rune.mesh = cube
        var angle := TAU * float(i) / 20.0
        rune.position = Vector3(sin(angle) * 1.12, -0.075, cos(angle) * 1.12)
        rune.rotation.y = angle
        rune.material_override = rune_mat
        add_child(rune)

func _build_interface() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)

    # Aetherfall's intended in-game presentation: parchment-gold, midnight
    # slate, segmented menus and a clean central character showcase.
    var top := Panel.new()
    _panel(top, DEEP, 11)
    top.anchor_right = 1.0
    top.offset_left = 12.0
    top.offset_right = -12.0
    top.offset_top = 9.0
    top.offset_bottom = 83.0
    root.add_child(top)
    heading_label = _label(top, "AETHERFALL  /  FORGE YOUR HERO", Vector2(21, 10), Vector2(800, 31), 25, ACCENT)
    instruction_label = _label(top, "CHARACTER CREATION   •   Drag to rotate and pan   •   Pinch to zoom", Vector2(22, 43), Vector2(900, 21), 13, SUBTLE)
    var version := _label(top, "CREATOR PREVIEW   0.6.5", Vector2(-258, 22), Vector2(222, 25), 14, PALE)
    version.set_anchors_preset(Control.PRESET_TOP_RIGHT)

    var left := Panel.new()
    _panel(left, PANEL, 14)
    left.anchor_bottom = 1.0
    left.offset_left = 14.0
    left.offset_right = 306.0
    left.offset_top = 97.0
    left.offset_bottom = -101.0
    root.add_child(left)
    _label(left, "01    CHARACTER", Vector2(16, 12), Vector2(258, 30), 20, ACCENT)
    _label(left, "Customize your appearance", Vector2(16, 39), Vector2(258, 23), 12, SUBTLE)
    var tab_names := ["BODY", "HAIR", "FACE", "VIEW"]
    for i in range(tab_names.size()):
        _add_button(left, "tab_" + tab_names[i].to_lower(), 74, tab_names[i], 39, 61, 14 + i * 66, 12)
    _add_rule(left, 125.0, 260.0)

    _add_button(left, "gender", 140, "BODY: MALE", 46, 260)
    _add_button(left, "skin", 195, "SKIN: WARM  ▶", 46, 260)
    _page_label(left, "SKIN PALETTE", Vector2(18, 255), Vector2(251, 20), "BODY")
    for i in range(SKIN_SWATCHES.size()):
        _add_swatch(left, "swatch_skin_" + str(i), Vector2(17 + i * 36, 282), SKIN_SWATCHES[i])
    _add_button(left, "height_down", 332, "HEIGHT: 100%   −", 43, 125)
    _add_button(left, "height_up", 332, "HEIGHT: 100%   +", 43, 125, 151)
    _add_button(left, "appearance_reset", 389, "RESET APPEARANCE", 44, 260)
    _add_button(left, "neck_fit", 442, "MALE NECK: REFINED", 37, 260, 16, 12)

    _add_button(left, "hair_previous", 140, "◀   PREVIOUS STYLE", 45, 124)
    _add_button(left, "hair_next", 140, "NEXT STYLE   ▶", 45, 124, 152)
    _add_button(left, "hair_color", 200, "HAIR COLOR: CHESTNUT", 45, 260)
    _page_label(left, "COLOR PALETTE", Vector2(18, 264), Vector2(251, 20), "HAIR")
    for i in range(HAIR_SWATCHES.size()):
        _add_swatch(left, "swatch_hair_" + str(i), Vector2(14 + i * 32, 290), HAIR_SWATCHES[i], 27)
    _add_button(left, "beard", 348, "BEARD: OFF", 45, 260)
    _page_label(left, "Compatible base-pack hairstyles", Vector2(18, 418), Vector2(258, 20), "HAIR")

    _add_button(left, "eye_color", 140, "IRIS: BROWN  ▶", 48, 260)
    _page_label(left, "EYE PALETTE", Vector2(18, 208), Vector2(251, 20), "FACE")
    for i in range(EYE_SWATCHES.size()):
        _add_swatch(left, "swatch_eye_" + str(i), Vector2(19 + i * 42, 239), EYE_SWATCHES[i], 34)
    _add_button(left, "eye_style", 297, "EYE FINISH: NATURAL", 47, 260)
    _add_button(left, "view_face", 363, "INSPECT FACE   +", 45, 260)
    _page_label(left, "Facial sculpting requires new morph meshes", Vector2(18, 424), Vector2(260, 34), "FACE")

    _add_button(left, "view_reset", 140, "RESET CAMERA", 47, 260)
    _add_button(left, "view_face_copy", 200, "FOCUS ON FACE", 47, 260)
    _add_button(left, "zoom_in", 260, "ZOOM IN    +", 47, 260)
    _add_button(left, "zoom_out", 320, "ZOOM OUT    −", 47, 260)
    _page_label(left, "1 finger  ·  turn / raise / lower", Vector2(18, 402), Vector2(257, 22), "VIEW")
    _page_label(left, "2 fingers  ·  pinch to zoom", Vector2(18, 430), Vector2(257, 22), "VIEW")

    var right := Panel.new()
    _panel(right, PANEL, 14)
    right.anchor_left = 1.0
    right.anchor_right = 1.0
    right.anchor_bottom = 1.0
    right.offset_left = -306.0
    right.offset_right = -14.0
    right.offset_top = 97.0
    right.offset_bottom = -101.0
    root.add_child(right)
    _label(right, "02    EQUIPMENT", Vector2(16, 12), Vector2(264, 30), 20, ACCENT)
    _label(right, "Mix & match modular armor", Vector2(16, 39), Vector2(264, 23), 12, SUBTLE)
    _add_rule(right, 70.0, 260.0)
    _add_button(right, "outfit", 82, "COMPLETE OUTFIT: RANGER", 45, 260)
    _add_button(right, "body", 137, "CHEST: RANGER", 45, 260)
    _add_button(right, "arms", 192, "ARMS: RANGER", 45, 260)
    _add_button(right, "legs", 247, "LEGS: RANGER", 45, 260)
    _add_button(right, "feet", 302, "BOOTS: RANGER", 45, 260)
    _add_button(right, "shoulders", 357, "SHOULDERS: ON", 45, 260)
    _add_button(right, "hood", 412, "HOOD: OFF", 45, 260)
    _add_button(right, "gear_reset", 467, "RESET EQUIPMENT", 43, 260)

    var footer := Panel.new()
    _panel(footer, DEEP, 10)
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.anchor_right = 1.0
    footer.offset_left = 12
    footer.offset_right = -12
    footer.offset_top = -90
    footer.offset_bottom = -9
    root.add_child(footer)
    _label(footer, "HERO NAME", Vector2(14, 7), Vector2(125, 18), 12, ACCENT)
    profile_name_field = LineEdit.new()
    profile_name_field.name = "HeroNameInput"
    profile_name_field.text = current_profile_name
    profile_name_field.placeholder_text = "Adventurer"
    profile_name_field.max_length = 24
    profile_name_field.position = Vector2(15, 28)
    profile_name_field.size = Vector2(209, 42)
    profile_name_field.add_theme_font_size_override("font_size", 15)
    profile_name_field.add_theme_color_override("font_color", PALE)
    var input_style := StyleBoxFlat.new()
    input_style.bg_color = Color(0.12, 0.15, 0.22)
    input_style.set_corner_radius_all(7)
    input_style.border_color = Color(0.56, 0.43, 0.28)
    input_style.set_border_width_all(1)
    profile_name_field.add_theme_stylebox_override("normal", input_style)
    footer.add_child(profile_name_field)
    _add_button(footer, "save_profile", 26, "SAVE HERO", 42, 128, 241, 14)
    _add_button(footer, "load_profile", 26, "LOAD HERO", 42, 128, 380, 14)
    _add_button(footer, "randomize", 26, "SURPRISE ME", 42, 147, 519, 14)
    status_label = _label(footer, "READY TO CREATE", Vector2(687, 31), Vector2(525, 35), 13, SUBTLE)
    status_label.anchor_right = 1.0
    status_label.offset_right = -20.0
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var error_panel := Panel.new()
    error_panel.name = "FailureDiagnostics"
    _panel(error_panel, Color(0.21, 0.069, 0.09, 0.97), 8)
    error_panel.anchor_left = 0.25
    error_panel.anchor_right = 0.75
    error_panel.anchor_top = 0.37
    error_panel.anchor_bottom = 0.65
    error_panel.offset_left = -14.0
    error_panel.offset_right = 14.0
    error_panel.visible = false
    root.add_child(error_panel)
    error_label = _label(error_panel, "", Vector2(20, 18), Vector2(620, 146), 16, PALE)
    error_label.anchor_right = 1.0
    error_label.anchor_bottom = 1.0
    error_label.offset_right = -20.0
    error_label.offset_bottom = -14.0
    error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _panel(panel: Panel, fill: Color, corners: int = 12) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(corners)
    style.border_color = Color(0.58, 0.46, 0.28, 0.78)
    style.set_border_width_all(1)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
    style.shadow_size = 4
    panel.add_theme_stylebox_override("panel", style)

func _add_rule(parent: Control, y: float, length: float) -> void:
    var divider := ColorRect.new()
    divider.position = Vector2(16, y)
    divider.size = Vector2(length, 1)
    divider.color = Color(0.55, 0.43, 0.27, 0.6)
    divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(divider)

func _label(parent: Control, value: String, xy: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
    var item := Label.new()
    item.text = value
    item.position = xy
    item.size = dimensions
    item.add_theme_font_size_override("font_size", font_size)
    item.add_theme_color_override("font_color", color)
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(item)
    return item

func _page_label(parent: Control, value: String, xy: Vector2, dimensions: Vector2, page: String) -> void:
    var item := _label(parent, value, xy, dimensions, 12, SUBTLE)
    page_labels[item.get_instance_id()] = {"label": item, "page": page}

func _add_button(parent: Control, key: String, y: float, value: String, h: float = 47.0, w: float = 260.0, x: float = 16.0, font_size: int = 14) -> void:
    var button := Button.new()
    button.name = "Control_" + key
    button.text = value
    button.position = Vector2(x, y)
    button.size = Vector2(w, h)
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", PALE)
    button.add_theme_color_override("font_hover_color", ACCENT)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.123, 0.157, 0.237)
    normal.set_corner_radius_all(7)
    normal.border_color = Color(0.30, 0.35, 0.43, 0.8)
    normal.set_border_width_all(1)
    button.add_theme_stylebox_override("normal", normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.20, 0.25, 0.34)
    hover.border_color = ACCENT
    button.add_theme_stylebox_override("hover", hover)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.38, 0.28, 0.16)
    pressed.border_color = ACCENT
    button.add_theme_stylebox_override("pressed", pressed)
    var focused := normal.duplicate() as StyleBoxFlat
    focused.bg_color = Color(0.20, 0.20, 0.28)
    focused.border_color = ACCENT
    button.add_theme_stylebox_override("focus", focused)
    button.pressed.connect(_on_action.bind(key))
    parent.add_child(button)
    buttons[key] = button

func _add_swatch(parent: Control, key: String, xy: Vector2, shade: Color, diameter: int = 31) -> void:
    var swatch := Button.new()
    swatch.name = "Shade_" + key
    swatch.position = xy
    swatch.size = Vector2(diameter, diameter)
    var normal := StyleBoxFlat.new()
    normal.bg_color = shade
    normal.set_corner_radius_all(6)
    normal.border_color = Color(0.25, 0.27, 0.31)
    normal.set_border_width_all(2)
    swatch.add_theme_stylebox_override("normal", normal)
    var selected := normal.duplicate() as StyleBoxFlat
    selected.border_color = ACCENT
    selected.set_border_width_all(3)
    swatch.add_theme_stylebox_override("pressed", selected)
    swatch.add_theme_stylebox_override("hover", selected)
    swatch.pressed.connect(_on_action.bind(key))
    parent.add_child(swatch)
    swatches[key] = {"button": swatch, "normal": normal, "selected": selected}

func _start_loading() -> void:
    # Allow real UI frames to render BEFORE running heavy Android GLB parsing.
    loading_id += 1
    var request_id := loading_id
    busy = true
    _set_status("LOADING CHARACTER", "Preparing " + pending_gender.to_upper() + " modular mesh...")
    _update_buttons()
    await get_tree().process_frame
    await get_tree().process_frame
    if request_id != loading_id or not is_instance_valid(avatar):
        return
    avatar.set_gender(pending_gender)
    var success: bool = avatar.load_selected_gender()
    busy = false
    if success:
        _set_status("READY", "Relaxed pose • Character: " + pending_gender.to_upper() + "  •  Drag to spin / pan  •  Pinch to zoom")
        if not keep_rotation_on_reload:
            rotation_y = 0.0
        keep_rotation_on_reload = false
        avatar.rotation.y = rotation_y
        _hide_error()
        if not pending_profile.is_empty():
            _apply_pending_profile()
        _update_camera()
    else:
        _set_error(str(avatar.error_code), str(avatar.last_error))
    _update_buttons()

func _set_status(code: String, details: String) -> void:
    if status_label != null:
        status_label.text = code + "  •  " + details

func _set_error(code: String, details: String) -> void:
    _set_status("LOAD ERROR " + code, details)
    if error_label != null:
        error_label.text = "CHARACTER LOADING ERROR\n\n" + code + "\n" + details
        error_label.get_parent().visible = true

func _hide_error() -> void:
    if error_label != null:
        error_label.get_parent().visible = false

func _on_action(key: String) -> void:
    if key.begins_with("tab_"):
        var target := key.trim_prefix("tab_").to_upper()
        appearance_page = TABS.find(target)
        _update_buttons()
        return
    if key == "view_reset":
        rotation_y = 0.0
        zoom_distance = 3.50
        camera_pan_y = 0.0
        if avatar != null:
            avatar.rotation.y = 0.0
        _update_camera()
        _set_status("VIEW RESET", "Full character visible")
        return
    if key in ["view_face", "view_face_copy"]:
        rotation_y = 0.0
        zoom_distance = 1.50
        camera_pan_y = 0.68
        if avatar != null:
            avatar.rotation.y = 0.0
        _update_camera()
        _set_status("FACE VIEW", "Drag up/down or pinch to inspect")
        return
    if key in ["zoom_in", "zoom_out"]:
        zoom_distance = clampf(zoom_distance + (-0.34 if key == "zoom_in" else 0.34), ZOOM_MIN, ZOOM_MAX)
        _update_camera()
        return
    if key == "load_profile":
        _load_profile_from_disk()
        return
    if avatar == null or busy or not bool(avatar.is_ready):
        _set_status("WAIT", "Character still loading")
        return
    if key == "save_profile":
        _save_profile_to_disk()
        return
    if key == "randomize":
        _randomize_look()
        return
    if key.begins_with("swatch_"):
        var fragments: PackedStringArray = key.split("_")
        if fragments.size() == 3:
            var swatch_index: int = int(fragments[2])
            match fragments[1]:
                "skin":
                    avatar.skin_index = swatch_index
                "hair":
                    avatar.hair_color_index = swatch_index
                "eye":
                    avatar.eye_color_index = swatch_index
            avatar._apply_appearance()
            _update_buttons()
            _set_status("COLOR SET", "Preview updated")
        return
    match key:
        "neck_fit":
            if pending_gender == "male":
                avatar.neck_fit = "standard" if avatar.neck_fit == "refined" else "refined"
                keep_rotation_on_reload = true
                _start_loading()
            return
        "gender":
            pending_gender = "female" if pending_gender == "male" else "male"
            pending_profile.clear()
            _start_loading()
            return
        "outfit":
            avatar.toggle_full_outfit()
        "hair_next":
            avatar.cycle_hair(1)
        "hair_previous":
            avatar.cycle_hair(-1)
        "hood":
            avatar.toggle_hood()
        "shoulders":
            avatar.toggle_shoulders()
        "beard":
            avatar.toggle_beard()
        "skin":
            avatar.cycle_skin()
        "hair_color":
            avatar.cycle_hair_color()
        "eye_color":
            avatar.cycle_eye_color()
        "eye_style":
            avatar.cycle_eye_style()
        "height_down":
            avatar.change_height(-0.05)
        "height_up":
            avatar.change_height(0.05)
        "appearance_reset":
            avatar.reset_appearance()
        "arms", "body", "legs", "feet":
            avatar.cycle_slot(key)
        "gear_reset":
            if avatar.outfit != "Ranger":
                avatar.toggle_full_outfit()
            else:
                for slot in ["arms", "body", "legs", "feet"]:
                    avatar.slot_styles[slot] = "Ranger"
                avatar._refresh_equipment()
    _set_status("PREVIEW UPDATED", "Change slots or rotate to inspect")
    _update_buttons()

func _update_buttons() -> void:
    if buttons.is_empty() or avatar == null:
        return
    var page: String = TABS[appearance_page]
    for tab_name in TABS:
        var tab_key: String = "tab_" + tab_name.to_lower()
        var tab: Button = buttons[tab_key]
        tab.button_pressed = false
        tab.modulate = Color.WHITE if tab_name == page else Color(0.72, 0.74, 0.77)
        tab.add_theme_color_override("font_color", ACCENT if tab_name == page else PALE)
    for page_name in TAB_KEYS.keys():
        for key in TAB_KEYS[page_name]:
            buttons[key].visible = page_name == page
    for entry in page_labels.values():
        var label: Label = entry["label"]
        label.visible = str(entry["page"]) == page
    for key in swatches.keys():
        var swatch: Button = swatches[key]["button"]
        var split: PackedStringArray = str(key).split("_")
        var section: String = str(split[1])
        var index: int = int(split[2])
        swatch.visible = (page == "BODY" and section == "skin") or (page == "HAIR" and section == "hair") or (page == "FACE" and section == "eye")
        var selected := (section == "skin" and index == int(avatar.skin_index)) or (section == "hair" and index == int(avatar.hair_color_index)) or (section == "eye" and index == int(avatar.eye_color_index))
        swatch.add_theme_stylebox_override("normal", swatches[key]["selected"] if selected else swatches[key]["normal"])
    buttons["gender"].text = "BASE: " + pending_gender.to_upper() + "   ▶"
    buttons["skin"].text = "SKIN: " + avatar.skin_label().to_upper() + "   ▶"
    buttons["neck_fit"].text = "MALE NECK: " + str(avatar.neck_fit).to_upper()
    buttons["neck_fit"].visible = (page == "BODY" and pending_gender == "male")
    buttons["neck_fit"].disabled = busy
    buttons["height_down"].text = "HEIGHT " + avatar.height_label() + "  −"
    buttons["height_up"].text = "HEIGHT " + avatar.height_label() + "  +"
    buttons["hair_next"].text = avatar.hairstyle_label().to_upper() + "   ▶"
    buttons["hair_color"].text = "HAIR COLOR: " + avatar.hair_color_label().to_upper() + "   ▶"
    buttons["eye_color"].text = "IRIS: " + avatar.eye_color_label().to_upper() + "   ▶"
    buttons["eye_style"].text = "EYE FINISH: " + avatar.eye_style_label().to_upper() + "   ▶"
    buttons["beard"].text = "FACIAL HAIR: " + ("ON" if avatar.beard_enabled else "OFF")
    buttons["beard"].disabled = pending_gender != "male" or busy
    buttons["outfit"].text = "COMPLETE SET: " + str(avatar.outfit).to_upper()
    var labels := {"body": "CHEST", "arms": "ARMS", "legs": "LEGS", "feet": "BOOTS"}
    for key in ["body", "arms", "legs", "feet"]:
        buttons[key].text = str(labels[key]) + ": " + str(avatar.slot_styles[key]).to_upper()
    buttons["shoulders"].text = "SHOULDERS: " + ("ON" if avatar.shoulders_enabled else "OFF")
    buttons["hood"].text = "HOOD: " + ("ON" if avatar.hood_enabled else "OFF")
    for key in ["save_profile", "randomize", "outfit", "body", "arms", "legs", "feet", "shoulders", "hood", "gear_reset"]:
        buttons[key].disabled = busy

func _save_profile_to_disk() -> void:
    var data: Dictionary = avatar.export_profile()
    current_profile_name = profile_name_field.text.strip_edges().substr(0, 24)
    if current_profile_name.is_empty():
        current_profile_name = "Adventurer"
        profile_name_field.text = current_profile_name
    data["name"] = current_profile_name
    var file := FileAccess.open(PROFILE_FILE, FileAccess.WRITE)
    if file == null:
        _set_error("AF-PROFILE-201", "Cannot save hero on this device")
        return
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    _set_status("HERO SAVED", "Saved to this device")

func _restore_profile_on_launch() -> void:
    if not FileAccess.file_exists(PROFILE_FILE):
        return
    var file := FileAccess.open(PROFILE_FILE, FileAccess.READ)
    if file == null:
        return
    var raw: String = file.get_as_text()
    file.close()
    var value = JSON.parse_string(raw)
    if not (value is Dictionary):
        return
    pending_profile = value
    var saved_gender: String = str(value.get("gender", "male"))
    if saved_gender in ["male", "female"]:
        pending_gender = saved_gender
    current_profile_name = str(value.get("name", "Adventurer")).substr(0, 24)
    profile_name_field.text = current_profile_name

func _load_profile_from_disk() -> void:
    if busy:
        return
    if not FileAccess.file_exists(PROFILE_FILE):
        _set_status("NO SAVE FOUND", "Save a hero first")
        return
    _restore_profile_on_launch()
    if pending_profile.is_empty():
        _set_status("PROFILE ERROR", "Could not read saved hero")
        return
    if pending_gender != str(avatar.gender):
        _start_loading()
    else:
        _apply_pending_profile()
        _update_buttons()

func _apply_pending_profile() -> void:
    if pending_profile.is_empty():
        return
    var profile: Dictionary = pending_profile.duplicate(true)
    pending_profile.clear()
    if bool(avatar.import_profile(profile)):
        _set_status("HERO RESTORED", "Welcome back, " + current_profile_name)
    else:
        _set_status("PROFILE ERROR", "Saved character type did not match")

func _randomize_look() -> void:
    avatar.randomize_look()
    _set_status("NEW LOOK CREATED", "Save it if you like this combination")
    _update_buttons()

func _update_camera() -> void:
    if camera == null:
        return
    # Fixed camera reference: height slider must not re-frame the avatar.
    # Camera shifts vertically only when the user pans the preview.
    camera.position = Vector3(0.0, 1.11 + camera_pan_y, zoom_distance)
    camera.look_at(Vector3(0.0, 0.99 + camera_pan_y, 0.0), Vector3.UP)

func _gesture_area(pos: Vector2) -> bool:
    var viewport_width := get_viewport().get_visible_rect().size.x
    return pos.x > viewport_width * 0.235 and pos.x < viewport_width * 0.76

func _touch_pair() -> Array:
    var ids := touch_points.keys()
    if ids.size() < 2:
        return []
    return [touch_points[ids[0]], touch_points[ids[1]]]

func _initialize_pinch() -> void:
    var pair := _touch_pair()
    if pair.size() == 2:
        var a: Vector2 = pair[0]
        var b: Vector2 = pair[1]
        last_pinch_distance = a.distance_to(b)
        last_pinch_midpoint = (a + b) * 0.5
    else:
        last_pinch_distance = 0.0
        last_pinch_midpoint = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if touch_points.size() < 2 and _gesture_area(event.position):
                touch_points[event.index] = event.position
                _initialize_pinch()
        elif touch_points.has(event.index):
            touch_points.erase(event.index)
            _initialize_pinch()
    elif event is InputEventScreenDrag:
        if not touch_points.has(event.index):
            return
        touch_points[event.index] = event.position
        if touch_points.size() >= 2:
            var pair := _touch_pair()
            var a: Vector2 = pair[0]
            var b: Vector2 = pair[1]
            var current_distance := a.distance_to(b)
            var current_midpoint := (a + b) * 0.5
            if last_pinch_distance > 10.0 and current_distance > 10.0:
                # Scale by distance ratio so spreading fingers zooms IN.
                zoom_distance = clampf(zoom_distance * last_pinch_distance / current_distance, ZOOM_MIN, ZOOM_MAX)
                _pan_preview(current_midpoint.y - last_pinch_midpoint.y)
            last_pinch_distance = current_distance
            last_pinch_midpoint = current_midpoint
            _update_camera()
        else:
            # Single-finger gesture: 2D model navigation, not model scaling.
            _turn_avatar(event.relative.x)
            _pan_preview(event.relative.y)
            _update_camera()
    elif event is InputEventMouseButton:
        # Android may synthesize a mouse event from the same touch. Handle
        # mobile rotation/pan only through the genuine multitouch events.
        if OS.has_feature("mobile"):
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            mouse_held = event.pressed and _gesture_area(event.position)
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            zoom_distance = maxf(ZOOM_MIN, zoom_distance * 0.89)
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            zoom_distance = minf(ZOOM_MAX, zoom_distance * 1.12)
            _update_camera()
    elif event is InputEventMouseMotion and mouse_held and not OS.has_feature("mobile"):
        _turn_avatar(event.relative.x)
        _pan_preview(event.relative.y)
        _update_camera()

func _pan_preview(dy_pixels: float) -> void:
    # Translate camera in world space so the character follows your finger.
    # Scale motion to current zoom; it feels consistent at face/full-body view.
    var screen_h := maxf(1.0, get_viewport().get_visible_rect().size.y)
    var world_per_pixel := 2.0 * zoom_distance * tan(deg_to_rad(camera.fov * 0.5)) / screen_h
    camera_pan_y = clampf(camera_pan_y + dy_pixels * world_per_pixel, PAN_MIN, PAN_MAX)

func _turn_avatar(dx: float) -> void:
    rotation_y += dx * 0.009
    if avatar != null:
        avatar.rotation.y = rotation_y
