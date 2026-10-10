extends Node3D
## Runtime Tripo/Mixamo QA scene for Aetherfall character pass.
## Loads the supplied GLB directly and adds game-ready preview behavior:
## gameplay locomotion test: touch movement, camera orbit, auto animation states, grounding.

const MODEL_PATH := "res://models/tripo_adventurer.glb"
const MOTION_BLEND_TIME := 0.24
const WALK_SPEED := 0.92
const RUN_SPEED := 1.06
const ACTOR_SCALE := 1.70
# Mixamo joint origins sit above the visible boot sole in this specific model.
# Source-model measurements: Foot ~= 0.067 m above sole, ToeBase ~= 0.017 m.
const FOOT_TO_SOLE_SOURCE_Y := 0.067
const TOE_TO_SOLE_SOURCE_Y := 0.017
const SOLE_CLEARANCE_WORLD := 0.010
# Adjust idle stance separately from the already-calibrated sole-height offsets.
const IDLE_ARM_LOWER_DEGREES := 86.0
const IDLE_ELBOW_BEND_DEGREES := 12.0
const IDLE_WRIST_ROLL_DEGREES := 92.0
const WALK_WORLD_SPEED := 1.75
const RUN_WORLD_SPEED := 4.15
const MOVE_ACCEL := 7.5
const MOVE_DECEL := 10.5
const TURN_RATE := 9.0
const STICK_DEADZONE := 0.10
const STICK_RADIUS := 68.0
const HDRI_PATH := "res://environment/kloppenheim_03_puresky_1k.hdr"

# Starter-town world dimensions. The hard bounds are authoritative: even if a
# decorative wall has a mesh gap, the player cannot leave this rectangle.
const TOWN_MIN_X := -27.0
const TOWN_MAX_X := 27.0
const TOWN_MIN_Z := -25.0
const TOWN_MAX_Z := 25.0
const PLAYER_WORLD_RADIUS := 0.58

var _actor: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _neutral_pose: Array[Transform3D] = []
var _idle_pose: Array[Transform3D] = []
var _transition_from: Array[Transform3D] = []
var _transition_elapsed := 0.0
var _transitioning := false

var _hips_index := -1
var _spine_index := -1
var _spine1_index := -1
var _head_index := -1
var _left_foot_index := -1
var _right_foot_index := -1
var _left_toe_index := -1
var _right_toe_index := -1
var _left_arm_index := -1
var _right_arm_index := -1
var _left_forearm_index := -1
var _right_forearm_index := -1
var _left_hand_index := -1
var _right_hand_index := -1
var _left_finger_bones: Array[int] = []
var _right_finger_bones: Array[int] = []
var _neutral_hips_origin := Vector3.ZERO
var _neutral_model_position := Vector3.ZERO
var _base_actor_y := 0.0

var _ground_contact_shadow: MeshInstance3D
var _camera: Camera3D
var _status: Label
var _detail: Label
var _motion := "IDLE"
var _paused := false
var _idle_time := 0.0
var _loaded := false

# Gameplay locomotion harness.
var _move_input := Vector2.ZERO
var _move_touch := -1
var _camera_touch := -1
var _sprint_held := false
var _move_speed := 0.0
var _travel_direction := Vector3(0.0, 0.0, -1.0)
var _camera_yaw := 0.0
var _camera_pitch := 0.18
var _camera_distance := 4.0
var _drag_mouse := false
var _joystick_base: Panel
var _joystick_knob: Panel
var _sprint_button: Button
var _world_blockers: Array[Rect2] = []
var _circle_blockers: Array[Vector3] = []
var _boundary_flash := 0.0

# Permanent on-device startup diagnostics. Parse errors are blocked by CI before
# an APK is shipped; runtime startup stages are shown here on the phone.
var _diag_panel: Panel
var _diag_code_label: Label
var _diag_detail_label: Label
var _diag_button: Button
var _diag_code := "AF-BOOT-100"
var _diag_detail_text := "Starter Town controller loaded."
var _startup_elapsed := 0.0
var _startup_complete := false
var _startup_failed := false
const STARTUP_WATCHDOG_SECONDS := 12.0

# Fountain animation state. Kept intentionally lightweight for Android.
var _fountain_time := 0.0
var _fountain_water: MeshInstance3D
var _fountain_crystal: MeshInstance3D
var _fountain_glow: OmniLight3D
var _fountain_jets: Array[MeshInstance3D] = []

func _ready() -> void:
    # Keep the same direct-scene startup path as the proven v0.1.3 build.
    # The diagnostic overlay is created first so later runtime failures remain visible.
    process_priority = 1000
    _build_diagnostic_overlay()
    _diag_stage("AF-WORLD-200", "Starter Town controller entered _ready().")

    _diag_stage("AF-TOWN-220", "Building Starter Town geometry and collision blockers.")
    _build_stage()
    _diag_stage("AF-TOWN-221", "Starter Town geometry finished successfully.")

    _diag_stage("AF-PLAYER-230", "Creating player actor root.")
    _actor = Node3D.new()
    _actor.name = "TripoActor"
    _actor.scale = Vector3.ONE * ACTOR_SCALE
    _actor.position = Vector3(0.0, 0.0, 18.0)
    add_child(_actor)
    _build_ground_contact_shadow()

    _diag_stage("AF-CAMERA-240", "Creating third-person camera.")
    _camera = Camera3D.new()
    _camera.name = "OrbitCamera"
    _camera.current = true
    _camera.fov = 52.0
    _camera.near = 0.03
    _camera.far = 160.0
    add_child(_camera)

    _diag_stage("AF-UI-250", "Building gameplay HUD and touch controls.")
    _build_ui()
    _set_status("LOADING", "Diagnostics active • reading embedded Tripo GLB…")
    _update_camera(1.0)
    _diag_stage("AF-MODEL-300", "Town is visible. Loading embedded character GLB next.")
    call_deferred("_load_runtime_glb")

func _build_diagnostic_overlay() -> void:
    var layer := CanvasLayer.new()
    layer.name = "DiagnosticsLayer"
    layer.layer = 100
    add_child(layer)

    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    _diag_button = Button.new()
    _diag_button.text = "DEBUG BOOT"
    _diag_button.anchor_left = 0.5
    _diag_button.anchor_right = 0.5
    _diag_button.anchor_top = 1.0
    _diag_button.anchor_bottom = 1.0
    _diag_button.offset_left = -76.0
    _diag_button.offset_right = 76.0
    _diag_button.offset_top = -52.0
    _diag_button.offset_bottom = -8.0
    _diag_button.add_theme_font_size_override("font_size", 14)
    _diag_button.pressed.connect(_toggle_diagnostics)
    ui.add_child(_diag_button)

    _diag_panel = Panel.new()
    _diag_panel.anchor_left = 0.5
    _diag_panel.anchor_right = 0.5
    _diag_panel.anchor_top = 0.5
    _diag_panel.anchor_bottom = 0.5
    _diag_panel.offset_left = -360.0
    _diag_panel.offset_right = 360.0
    _diag_panel.offset_top = -145.0
    _diag_panel.offset_bottom = 145.0
    _diag_panel.visible = false
    ui.add_child(_diag_panel)

    var title := Label.new()
    title.position = Vector2(22, 18)
    title.size = Vector2(676, 32)
    title.text = "AETHERFALL DIAGNOSTICS"
    title.add_theme_font_size_override("font_size", 22)
    _diag_panel.add_child(title)

    _diag_code_label = Label.new()
    _diag_code_label.position = Vector2(22, 60)
    _diag_code_label.size = Vector2(676, 34)
    _diag_code_label.add_theme_font_size_override("font_size", 20)
    _diag_panel.add_child(_diag_code_label)

    _diag_detail_label = Label.new()
    _diag_detail_label.position = Vector2(22, 104)
    _diag_detail_label.size = Vector2(676, 150)
    _diag_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _diag_detail_label.add_theme_font_size_override("font_size", 16)
    _diag_panel.add_child(_diag_detail_label)
    _refresh_diagnostics()

func _diag_stage(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _diag_code = code
    _diag_detail_text = detail
    _startup_elapsed = 0.0
    if code == "AF-READY-900":
        _startup_complete = true
        if _diag_button != null:
            _diag_button.text = "DEBUG OK"
    _refresh_diagnostics()

func _diag_failure(code: String, detail: String) -> void:
    if _startup_failed:
        return
    _startup_failed = true
    _diag_code = code
    _diag_detail_text = detail
    push_error("AETHERFALL_DIAGNOSTIC " + code + ": " + detail)
    if _diag_button != null:
        _diag_button.text = "ERROR " + code
    if _diag_panel != null:
        _diag_panel.visible = true
    _refresh_diagnostics()

func _toggle_diagnostics() -> void:
    if _diag_panel != null:
        _diag_panel.visible = not _diag_panel.visible

func _refresh_diagnostics() -> void:
    if _diag_code_label != null:
        _diag_code_label.text = _diag_code
    if _diag_detail_label != null:
        var state := "STARTING"
        if _startup_complete:
            state = "READY - no startup errors detected"
        elif _startup_failed:
            state = "FAILED - photograph this panel"
        _diag_detail_label.text = "Starter Town v0.1.9 diagnostics\nState: " + state + "\n\n" + _diag_detail_text + "\n\nLast stage: " + _diag_code

func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _water_mat(color: Color, alpha: float = 0.72) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    var tinted := color
    tinted.a = alpha
    material.albedo_color = tinted
    material.roughness = 0.16
    material.metallic = 0.08
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func _crystal_mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.14
    material.metallic = 0.05
    material.emission_enabled = true
    material.emission = color.lightened(0.12)
    material.emission_energy_multiplier = 0.66
    return material

func _box(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, rotation_degrees: Vector3 = Vector3.ZERO, roughness: float = 0.9) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.rotation_degrees = rotation_degrees
    mesh_instance.material_override = _mat(color, roughness)
    parent.add_child(mesh_instance)
    return mesh_instance

func _cylinder(parent: Node, name: String, radius: float, height: float, position: Vector3, color: Color, roughness: float = 0.9) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 18
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _mat(color, roughness)
    parent.add_child(mesh_instance)
    return mesh_instance

func _tapered_cylinder(parent: Node, name: String, bottom_radius: float, top_radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_radius
    mesh.bottom_radius = bottom_radius
    mesh.height = height
    mesh.radial_segments = 14
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _mat(color, 0.95)
    parent.add_child(mesh_instance)
    return mesh_instance

func _sphere(parent: Node, name: String, radius: float, position: Vector3, color: Color, roughness: float = 0.88) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    mesh_instance.material_override = _mat(color, roughness)
    parent.add_child(mesh_instance)
    return mesh_instance

func _add_blocker(center: Vector2, size: Vector2, padding: float = PLAYER_WORLD_RADIUS) -> void:
    _world_blockers.append(Rect2(center - size * 0.5 - Vector2.ONE * padding, size + Vector2.ONE * padding * 2.0))

func _add_circle_blocker(center: Vector2, radius: float, padding: float = PLAYER_WORLD_RADIUS) -> void:
    _circle_blockers.append(Vector3(center.x, center.y, radius + padding))

func _window_frame(parent: Node, center: Vector3, width: float, height: float) -> void:
    var frame := Color("#3a2a22")
    _box(parent, "WindowGlass", Vector3(width, height, 0.09), center, Color("#8cc8d8"), Vector3.ZERO, 0.22)
    _box(parent, "WindowTrimT", Vector3(width + 0.18, 0.10, 0.13), center + Vector3(0, height * 0.5 + 0.05, 0.02), frame)
    _box(parent, "WindowTrimB", Vector3(width + 0.18, 0.10, 0.13), center + Vector3(0, -height * 0.5 - 0.05, 0.02), frame)
    _box(parent, "WindowTrimL", Vector3(0.10, height, 0.13), center + Vector3(-width * 0.5 - 0.05, 0, 0.02), frame)
    _box(parent, "WindowTrimR", Vector3(0.10, height, 0.13), center + Vector3(width * 0.5 + 0.05, 0, 0.02), frame)
    _box(parent, "WindowCrossV", Vector3(0.055, height * 0.92, 0.14), center + Vector3(0, 0, 0.03), frame)
    _box(parent, "WindowCrossH", Vector3(width * 0.92, 0.055, 0.14), center + Vector3(0, 0, 0.03), frame)

func _window_frame_side(parent: Node, center: Vector3, width: float, height: float) -> void:
    var frame := Color("#3a2a22")
    _box(parent, "SideWindowGlass", Vector3(0.09, height, width), center, Color("#8cc8d8"), Vector3.ZERO, 0.22)
    _box(parent, "SideWindowTrimT", Vector3(0.13, 0.10, width + 0.18), center + Vector3(0.02, height * 0.5 + 0.05, 0), frame)
    _box(parent, "SideWindowTrimB", Vector3(0.13, 0.10, width + 0.18), center + Vector3(0.02, -height * 0.5 - 0.05, 0), frame)
    _box(parent, "SideWindowTrimL", Vector3(0.13, height, 0.10), center + Vector3(0.02, 0, -width * 0.5 - 0.05), frame)
    _box(parent, "SideWindowTrimR", Vector3(0.13, height, 0.10), center + Vector3(0.02, 0, width * 0.5 + 0.05), frame)
    _box(parent, "SideWindowCrossV", Vector3(0.14, height * 0.92, 0.055), center + Vector3(0.03, 0, 0), frame)
    _box(parent, "SideWindowCrossH", Vector3(0.14, 0.055, width * 0.92), center + Vector3(0.03, 0, 0), frame)

func _front_shutters(parent: Node, center: Vector3, width: float, height: float) -> void:
    var wood := Color("#5b3b2d")
    var offset := width * 0.5 + 0.18
    _box(parent, "ShutterL", Vector3(0.25, height * 0.92, 0.10), center + Vector3(-offset, 0, 0.08), wood, Vector3.ZERO, 0.84)
    _box(parent, "ShutterR", Vector3(0.25, height * 0.92, 0.10), center + Vector3(offset, 0, 0.08), wood, Vector3.ZERO, 0.84)
    _box(parent, "ShutterBarL", Vector3(0.29, 0.07, 0.12), center + Vector3(-offset, 0, 0.10), Color("#34251f"))
    _box(parent, "ShutterBarR", Vector3(0.29, 0.07, 0.12), center + Vector3(offset, 0, 0.10), Color("#34251f"))

func _flower_box(parent: Node, center: Vector3, width: float) -> void:
    _box(parent, "FlowerBox", Vector3(width, 0.24, 0.28), center, Color("#5b3b2d"), Vector3.ZERO, 0.90)
    for i in range(3):
        var fx := -width * 0.28 + float(i) * width * 0.28
        _sphere(parent, "Flower", 0.11, center + Vector3(fx, 0.20, 0.02), [Color("#c85d64"), Color("#d9a84d"), Color("#7c79c9")][i % 3], 0.9)

func _add_house(position: Vector3, body_size: Vector3, wall_color: Color, roof_color: Color, title: String = "") -> Node3D:
    var house := Node3D.new()
    house.name = title if not title.is_empty() else "House"
    house.position = position
    add_child(house)
    var width := body_size.x
    var depth := body_size.z
    var body_center_y := 0.52 + body_size.y * 0.5
    var front_z := depth * 0.505
    var stone := Color("#66655f")
    var stone_light := Color("#85827a")
    var beam := Color("#34251f")
    var door_wood := Color("#4c3022")

    _box(house, "Foundation", Vector3(width + 0.52, 0.56, depth + 0.52), Vector3(0, 0.28, 0), stone)
    _box(house, "FoundationCourse", Vector3(width + 0.58, 0.10, depth + 0.58), Vector3(0, 0.52, 0), stone_light)
    _box(house, "PlasterWalls", body_size, Vector3(0, body_center_y, 0), wall_color, Vector3.ZERO, 0.98)

    # Strong timber silhouette: corners, floor band, ridge band, and diagonal braces.
    for x in [-width * 0.45, 0.0, width * 0.45]:
        _box(house, "FrontPost", Vector3(0.15, body_size.y + 0.08, 0.17), Vector3(x, body_center_y, front_z), beam)
    _box(house, "FrontBandLow", Vector3(width * 0.94, 0.14, 0.17), Vector3(0, 1.42, front_z), beam)
    _box(house, "FrontBandHigh", Vector3(width * 0.94, 0.14, 0.17), Vector3(0, body_size.y + 0.26, front_z), beam)
    _box(house, "BraceL", Vector3(0.13, 1.55, 0.18), Vector3(-width * 0.31, 2.15, front_z + 0.01), beam, Vector3(0, 0, -28))
    _box(house, "BraceR", Vector3(0.13, 1.55, 0.18), Vector3(width * 0.31, 2.15, front_z + 0.01), beam, Vector3(0, 0, 28))

    # Door with stone threshold and a little timber rain hood.
    _box(house, "Door", Vector3(1.05, 1.95, 0.16), Vector3(0, 1.46, depth * 0.515), door_wood, Vector3.ZERO, 0.72)
    _box(house, "DoorThreshold", Vector3(1.35, 0.12, 0.55), Vector3(0, 0.62, depth * 0.60), stone_light)
    _box(house, "DoorHood", Vector3(1.65, 0.14, 0.88), Vector3(0, 2.52, depth * 0.60), roof_color, Vector3(-10, 0, 0))

    var left_front_window := Vector3(-width * 0.27, 2.10, depth * 0.518)
    var right_front_window := Vector3(width * 0.27, 2.10, depth * 0.518)
    _window_frame(house, left_front_window, 0.72, 0.82)
    _window_frame(house, right_front_window, 0.72, 0.82)
    _front_shutters(house, left_front_window, 0.72, 0.82)
    _front_shutters(house, right_front_window, 0.72, 0.82)
    _flower_box(house, left_front_window + Vector3(0, -0.58, 0.14), 0.84)
    _flower_box(house, right_front_window + Vector3(0, -0.58, 0.14), 0.84)

    # Side elevations: timber posts/bands and one framed window per side prevent blank box walls.
    for side_index in range(2):
        var side: float = -1.0 if side_index == 0 else 1.0
        var sx: float = side * width * 0.505
        for z_index in range(3):
            var z: float = [-depth * 0.34, 0.0, depth * 0.34][z_index]
            _box(house, "SidePost", Vector3(0.17, body_size.y + 0.08, 0.15), Vector3(sx, body_center_y, z), beam)
        _box(house, "SideBandLow", Vector3(0.17, 0.14, depth * 0.92), Vector3(sx, 1.42, 0), beam)
        _box(house, "SideBandHigh", Vector3(0.17, 0.14, depth * 0.92), Vector3(sx, body_size.y + 0.26, 0), beam)
        _window_frame_side(house, Vector3(sx + side * 0.012, 2.05, -depth * 0.08), 0.74, 0.80)

    # Stone quoins at the four corners break up the foundation/plaster transition.
    for sx_index in range(2):
        var corner_x: float = -1.0 if sx_index == 0 else 1.0
        for sz_index in range(2):
            var corner_z: float = -1.0 if sz_index == 0 else 1.0
            var corner: Vector3 = Vector3(corner_x * width * 0.505, 1.02, corner_z * depth * 0.505)
            _box(house, "CornerStoneLow", Vector3(0.30, 0.32, 0.30), corner, stone_light)
            _box(house, "CornerStoneHigh", Vector3(0.26, 0.28, 0.26), corner + Vector3(0, 0.36, 0), stone)

    # Door frame, lintel and visible handle add scale cues at character eye level.
    _box(house, "DoorFrameL", Vector3(0.12, 2.08, 0.20), Vector3(-0.60, 1.50, depth * 0.526), beam)
    _box(house, "DoorFrameR", Vector3(0.12, 2.08, 0.20), Vector3(0.60, 1.50, depth * 0.526), beam)
    _box(house, "DoorLintel", Vector3(1.32, 0.13, 0.20), Vector3(0, 2.49, depth * 0.526), beam)
    _sphere(house, "DoorHandle", 0.07, Vector3(0.32, 1.48, depth * 0.615), Color("#b58a45"), 0.38)

    # Deep eaves, ridge cap, and fascia make the simple roof read as an intentional stylized asset.
    _box(house, "RoofLeft", Vector3(width * 0.64, 0.34, depth + 1.05), Vector3(-width * 0.245, body_size.y + 1.08, 0), roof_color, Vector3(0, 0, 25), 0.82)
    _box(house, "RoofRight", Vector3(width * 0.64, 0.34, depth + 1.05), Vector3(width * 0.245, body_size.y + 1.08, 0), roof_color, Vector3(0, 0, -25), 0.82)
    _box(house, "RoofRidge", Vector3(0.26, 0.30, depth + 1.12), Vector3(0, body_size.y + 1.62, 0), roof_color.darkened(0.18), Vector3.ZERO, 0.78)
    _box(house, "FasciaFront", Vector3(width + 0.58, 0.16, 0.18), Vector3(0, body_size.y + 0.76, depth * 0.57), beam)
    _box(house, "FasciaBack", Vector3(width + 0.58, 0.16, 0.18), Vector3(0, body_size.y + 0.76, -depth * 0.57), beam)
    _box(house, "EaveTrimL", Vector3(0.14, 0.18, depth + 1.02), Vector3(-width * 0.51, body_size.y + 0.78, 0), beam)
    _box(house, "EaveTrimR", Vector3(0.14, 0.18, depth + 1.02), Vector3(width * 0.51, body_size.y + 0.78, 0), beam)

    _box(house, "Chimney", Vector3(0.52, 1.28, 0.52), Vector3(width * 0.25, body_size.y + 1.63, -depth * 0.18), Color("#5f5c58"))
    _box(house, "ChimneyCap", Vector3(0.68, 0.15, 0.68), Vector3(width * 0.25, body_size.y + 2.29, -depth * 0.18), Color("#474744"))

    if not title.is_empty():
        var sign_back := _box(house, "ShopSign", Vector3(minf(width * 0.75, 5.6), 0.54, 0.12), Vector3(0, body_size.y + 0.08, depth * 0.575), Color("#4a3528"))
        var sign := Label3D.new()
        sign.text = title
        sign.font_size = 36
        sign.outline_size = 7
        sign.modulate = Color("#f6e2ad")
        sign.position = Vector3(0, body_size.y + 0.08, depth * 0.65)
        house.add_child(sign)

    _add_blocker(Vector2(position.x, position.z), Vector2(width + 0.80, depth + 0.80), PLAYER_WORLD_RADIUS + 0.10)
    return house

func _add_tree(position: Vector3, scale_factor: float = 1.0) -> void:
    var tree := Node3D.new()
    tree.position = position
    add_child(tree)
    var trunk := Color("#4a3326")
    var bark_dark := Color("#35271f")
    var leaf_dark := Color("#2f5538")
    var leaf_mid := Color("#477249")
    var leaf_light := Color("#668d56")

    # Soft dirt ring makes the tree feel planted instead of dropped onto grass.
    _cylinder(tree, "TreeDirt", 0.78 * scale_factor, 0.022, Vector3(0, 0.012, 0), Color("#5b4937"), 1.0)
    _tapered_cylinder(tree, "Trunk", 0.30 * scale_factor, 0.16 * scale_factor, 2.55 * scale_factor, Vector3(0, 1.28 * scale_factor, 0), trunk)

    # Simple angled branches improve the silhouette without a heavy mesh.
    _box(tree, "BranchL", Vector3(0.12, 0.95, 0.12) * scale_factor, Vector3(-0.22, 2.15, 0) * scale_factor, bark_dark, Vector3(0, 0, -36))
    _box(tree, "BranchR", Vector3(0.11, 0.88, 0.11) * scale_factor, Vector3(0.25, 2.10, 0.05) * scale_factor, bark_dark, Vector3(0, 0, 39))
    _box(tree, "BranchBack", Vector3(0.10, 0.76, 0.10) * scale_factor, Vector3(0.02, 2.20, -0.18) * scale_factor, bark_dark, Vector3(34, 0, 0))

    # Layered crown: asymmetric clusters keep trees from reading as green balls.
    _sphere(tree, "LeafA", 0.70 * scale_factor, Vector3(-0.48, 2.68, 0.08) * scale_factor, leaf_dark)
    _sphere(tree, "LeafB", 0.78 * scale_factor, Vector3(0.38, 2.74, 0.10) * scale_factor, leaf_mid)
    _sphere(tree, "LeafC", 0.67 * scale_factor, Vector3(0.02, 3.34, -0.12) * scale_factor, leaf_light)
    _sphere(tree, "LeafD", 0.52 * scale_factor, Vector3(-0.58, 3.18, 0.24) * scale_factor, leaf_mid)
    _sphere(tree, "LeafE", 0.52 * scale_factor, Vector3(0.58, 3.16, 0.18) * scale_factor, leaf_dark)
    _sphere(tree, "LeafF", 0.44 * scale_factor, Vector3(0.02, 2.92, -0.52) * scale_factor, leaf_mid)
    _add_circle_blocker(Vector2(position.x, position.z), 0.34 * scale_factor, PLAYER_WORLD_RADIUS + 0.10)

func _add_shrub(position: Vector3, scale_factor: float = 1.0, variant: int = 0) -> void:
    var shrub := Node3D.new()
    shrub.position = position
    add_child(shrub)
    var dark := Color("#365f3d")
    var mid := Color("#4f7d49")
    var light := Color("#6c9458")
    if variant % 2 == 0:
        _sphere(shrub, "ShrubA", 0.34 * scale_factor, Vector3(-0.24, 0.30, 0.04), dark)
        _sphere(shrub, "ShrubB", 0.40 * scale_factor, Vector3(0.18, 0.38, -0.02), mid)
        _sphere(shrub, "ShrubC", 0.26 * scale_factor, Vector3(0.02, 0.62, 0.03), light)
    else:
        _sphere(shrub, "ShrubA", 0.30 * scale_factor, Vector3(-0.30, 0.28, 0.06), mid)
        _sphere(shrub, "ShrubB", 0.34 * scale_factor, Vector3(0.00, 0.34, -0.08), dark)
        _sphere(shrub, "ShrubC", 0.31 * scale_factor, Vector3(0.31, 0.31, 0.05), light)
        _sphere(shrub, "ShrubD", 0.22 * scale_factor, Vector3(0.12, 0.58, 0.00), mid)

func _add_grass_clump(position: Vector3, scale_factor: float = 1.0) -> void:
    var clump := Node3D.new()
    clump.position = position
    add_child(clump)
    var green_a := Color("#496841")
    var green_b := Color("#5c7848")
    _box(clump, "BladeA", Vector3(0.035, 0.42, 0.05) * scale_factor, Vector3(-0.12, 0.20, 0), green_a, Vector3(0, 0, -13))
    _box(clump, "BladeB", Vector3(0.035, 0.48, 0.05) * scale_factor, Vector3(0.00, 0.23, 0), green_b, Vector3(0, 0, 7))
    _box(clump, "BladeC", Vector3(0.035, 0.38, 0.05) * scale_factor, Vector3(0.12, 0.18, 0), green_a, Vector3(0, 0, 16))

func _add_flower_patch(position: Vector3, flower_color: Color) -> void:
    var patch := Node3D.new()
    patch.position = position
    add_child(patch)
    var stem := Color("#47683f")
    for i in range(4):
        var x: float = -0.30 + float(i) * 0.20
        var z: float = 0.10 if i % 2 == 0 else -0.10
        var h: float = 0.26 + 0.04 * float(i % 2)
        _box(patch, "FlowerStem", Vector3(0.025, h, 0.025), Vector3(x, h * 0.5, z), stem)
        _sphere(patch, "FlowerHead", 0.07, Vector3(x, h + 0.03, z), flower_color)

func _add_rock(position: Vector3, scale_factor: float = 1.0) -> void:
    var rock := Node3D.new()
    rock.position = position
    add_child(rock)
    _sphere(rock, "Rock", 0.26 * scale_factor, Vector3(0, 0.18 * scale_factor, 0), Color("#686861"), 1.0)
    rock.scale = Vector3(1.25, 0.70, 0.95)

func _add_market_stall(position: Vector3, awning: Color) -> void:
    var stall := Node3D.new()
    stall.position = position
    add_child(stall)
    var wood := Color("#5b3c2a")
    var dark_wood := Color("#3e2b22")
    _box(stall, "Counter", Vector3(2.55, 0.20, 1.25), Vector3(0, 1.05, 0), wood)
    _box(stall, "Shelf", Vector3(2.35, 0.14, 0.75), Vector3(0, 0.54, 0.18), dark_wood)
    for x in [-1.08, 1.08]:
        for z in [-0.46, 0.46]:
            _box(stall, "Post", Vector3(0.12, 2.50, 0.12), Vector3(float(x), 1.28, float(z)), dark_wood)
    # Striped awning reads much better than a single floating slab.
    for stripe in range(5):
        var sx := -1.06 + float(stripe) * 0.53
        var stripe_color := awning if stripe % 2 == 0 else awning.lightened(0.28)
        _box(stall, "AwningStripe", Vector3(0.54, 0.12, 1.72), Vector3(sx, 2.52, -0.04), stripe_color, Vector3(-8, 0, 0), 0.84)
    _box(stall, "CrateA", Vector3(0.62, 0.55, 0.62), Vector3(-0.70, 0.30, -0.35), Color("#79543a"))
    _box(stall, "CrateB", Vector3(0.55, 0.40, 0.55), Vector3(0.62, 0.22, 0.30), Color("#875f40"))
    _add_blocker(Vector2(position.x, position.z), Vector2(2.9, 1.95), PLAYER_WORLD_RADIUS + 0.08)

func _add_bench(position: Vector3, yaw: float = 0.0) -> void:
    var bench := Node3D.new()
    bench.position = position
    bench.rotation_degrees.y = yaw
    add_child(bench)
    var wood := Color("#64442e")
    var iron := Color("#353739")
    _box(bench, "Seat", Vector3(2.0, 0.18, 0.58), Vector3(0, 0.62, 0), wood)
    _box(bench, "Back", Vector3(2.0, 0.70, 0.14), Vector3(0, 1.02, 0.28), wood, Vector3(-8, 0, 0))
    _box(bench, "LegL", Vector3(0.16, 0.62, 0.16), Vector3(-0.72, 0.31, 0), iron)
    _box(bench, "LegR", Vector3(0.16, 0.62, 0.16), Vector3(0.72, 0.31, 0), iron)
    var sx := absf(cos(deg_to_rad(yaw))) * 2.15 + absf(sin(deg_to_rad(yaw))) * 0.85
    var sz := absf(sin(deg_to_rad(yaw))) * 2.15 + absf(cos(deg_to_rad(yaw))) * 0.85
    _add_blocker(Vector2(position.x, position.z), Vector2(sx, sz), 0.25)

func _add_barrel(position: Vector3) -> void:
    var barrel := Node3D.new()
    barrel.position = position
    add_child(barrel)
    _cylinder(barrel, "Barrel", 0.34, 0.82, Vector3(0, 0.41, 0), Color("#765039"))
    _cylinder(barrel, "BandLow", 0.355, 0.07, Vector3(0, 0.18, 0), Color("#333638"), 0.45)
    _cylinder(barrel, "BandHigh", 0.355, 0.07, Vector3(0, 0.64, 0), Color("#333638"), 0.45)

func _add_lamp(position: Vector3) -> void:
    var lamp := Node3D.new()
    lamp.position = position
    add_child(lamp)
    _tapered_cylinder(lamp, "Post", 0.08, 0.055, 2.7, Vector3(0, 1.35, 0), Color("#2e3337"))
    _box(lamp, "Arm", Vector3(0.65, 0.08, 0.08), Vector3(0.25, 2.55, 0), Color("#2e3337"))
    _sphere(lamp, "Lantern", 0.18, Vector3(0.55, 2.40, 0), Color("#ffd889"), 0.28)
    var glow := OmniLight3D.new()
    glow.position = Vector3(0.55, 2.40, 0)
    glow.light_color = Color("#ffd38a")
    glow.light_energy = 0.55
    glow.omni_range = 3.8
    glow.shadow_enabled = false
    lamp.add_child(glow)

func _add_wall_segment(position: Vector3, size: Vector3) -> void:
    var stone := Color("#716f68")
    _box(self, "TownWall", size, position, stone)
    _box(self, "WallCap", Vector3(size.x + 0.14, 0.20, size.z + 0.14), position + Vector3(0, size.y * 0.5 + 0.10, 0), Color("#8b877d"))

func _road_base(name: String, center: Vector3, size: Vector2) -> void:
    _box(self, name, Vector3(size.x, 0.055, size.y), center + Vector3(0, 0.028, 0), Color("#5f5c55"), Vector3.ZERO, 0.96)

func _road_seams_z(center: Vector3, width: float, length: float) -> void:
    # Cross seams plus two long irregular lanes. Low node count but reads as cobbled paving from the player camera.
    var count := int(length / 1.45)
    for i in range(count + 1):
        var z := center.z - length * 0.5 + float(i) * 1.45
        var shift := 0.18 if i % 2 == 0 else -0.18
        _box(self, "StoneJoint", Vector3(width - 0.18, 0.014, 0.045), Vector3(center.x + shift, 0.064, z), Color("#54544f"))
    for x in [-width * 0.28, width * 0.28]:
        _box(self, "StoneJointLong", Vector3(0.045, 0.014, length - 0.20), Vector3(center.x + x, 0.064, center.z), Color("#565650"))

func _road_seams_x(center: Vector3, width: float, length: float) -> void:
    var count := int(width / 1.45)
    for i in range(count + 1):
        var x := center.x - width * 0.5 + float(i) * 1.45
        var shift := 0.18 if i % 2 == 0 else -0.18
        _box(self, "StoneJoint", Vector3(0.045, 0.014, length - 0.18), Vector3(x, 0.064, center.z + shift), Color("#54544f"))
    for z in [-length * 0.28, length * 0.28]:
        _box(self, "StoneJointLong", Vector3(width - 0.20, 0.014, 0.045), Vector3(center.x, 0.064, center.z + z), Color("#565650"))

func _market_grid(center: Vector3, size: Vector2) -> void:
    var x_count := int(size.x / 1.65)
    var z_count := int(size.y / 1.65)
    for ix in range(x_count + 1):
        var x := center.x - size.x * 0.5 + float(ix) * 1.65
        _box(self, "SquareJointX", Vector3(0.045, 0.014, size.y - 0.15), Vector3(x, 0.071, center.z), Color("#555650"))
    for iz in range(z_count + 1):
        var z := center.z - size.y * 0.5 + float(iz) * 1.65
        _box(self, "SquareJointZ", Vector3(size.x - 0.15, 0.014, 0.045), Vector3(center.x, 0.071, z), Color("#555650"))


func _stone_tone(index: int) -> Color:
    var tones := [
        Color("#66635c"), Color("#706c64"), Color("#5f5d57"),
        Color("#767168"), Color("#64615b")
    ]
    return tones[index % tones.size()]

func _road_stones_z(center: Vector3, width: float, length: float) -> void:
    var cols := 3
    var rows := int(length / 2.0)
    var stone_w := (width - 0.34) / float(cols)
    var stone_l := length / float(rows)
    for row in range(rows):
        var z := center.z - length * 0.5 + (float(row) + 0.5) * stone_l
        var stagger := stone_w * 0.22 if row % 2 == 1 else 0.0
        for col in range(cols):
            var x := center.x - width * 0.5 + (float(col) + 0.5) * stone_w + stagger
            if x > center.x + width * 0.5 - stone_w * 0.35:
                x -= width
            var inset := 0.14 + 0.025 * float((row + col) % 3)
            _box(self, "RoadStone", Vector3(stone_w - inset, 0.045, stone_l - 0.11), Vector3(x, 0.080, z), _stone_tone(row * cols + col), Vector3.ZERO, 0.98)

func _road_stones_x(center: Vector3, width: float, length: float) -> void:
    var rows := 3
    var cols := int(width / 2.0)
    var stone_w := width / float(cols)
    var stone_l := (length - 0.34) / float(rows)
    for col in range(cols):
        var x := center.x - width * 0.5 + (float(col) + 0.5) * stone_w
        var stagger := stone_l * 0.22 if col % 2 == 1 else 0.0
        for row in range(rows):
            var z := center.z - length * 0.5 + (float(row) + 0.5) * stone_l + stagger
            if z > center.z + length * 0.5 - stone_l * 0.35:
                z -= length
            var inset := 0.14 + 0.025 * float((row + col) % 3)
            _box(self, "RoadStone", Vector3(stone_w - 0.11, 0.045, stone_l - inset), Vector3(x, 0.080, z), _stone_tone(col * rows + row + 2), Vector3.ZERO, 0.98)

func _market_stones(center: Vector3, size: Vector2) -> void:
    var cols := 8
    var rows := 7
    var stone_w := size.x / float(cols)
    var stone_l := size.y / float(rows)
    for row in range(rows):
        var stagger := stone_w * 0.22 if row % 2 == 1 else 0.0
        for col in range(cols):
            var x := center.x - size.x * 0.5 + (float(col) + 0.5) * stone_w + stagger
            if x > center.x + size.x * 0.5 - stone_w * 0.35:
                x -= size.x
            var z := center.z - size.y * 0.5 + (float(row) + 0.5) * stone_l
            var inset := 0.14 + 0.02 * float((row * 3 + col) % 4)
            _box(self, "SquareStone", Vector3(stone_w - inset, 0.048, stone_l - 0.11), Vector3(x, 0.083, z), _stone_tone(row * cols + col + 1), Vector3.ZERO, 0.98)

func _road_shoulders() -> void:
    var dirt := Color("#695744")
    _box(self, "EntryShoulderL", Vector3(0.44, 0.028, 43.5), Vector3(-3.30, 0.022, 2.0), dirt, Vector3.ZERO, 1.0)
    _box(self, "EntryShoulderR", Vector3(0.44, 0.028, 43.5), Vector3(3.30, 0.022, 2.0), dirt, Vector3.ZERO, 1.0)
    _box(self, "CrossShoulderN", Vector3(41.5, 0.028, 0.42), Vector3(0, 0.022, -2.02), dirt, Vector3.ZERO, 1.0)
    _box(self, "CrossShoulderS", Vector3(41.5, 0.028, 0.42), Vector3(0, 0.022, 4.02), dirt, Vector3.ZERO, 1.0)

func _configure_hdri_environment(env: Environment) -> bool:
    if not FileAccess.file_exists(HDRI_PATH):
        return false
    var hdri_image: Image = Image.load_from_file(HDRI_PATH)
    if hdri_image == null or hdri_image.is_empty():
        return false
    var sky_texture: ImageTexture = ImageTexture.create_from_image(hdri_image)
    if sky_texture == null:
        return false
    var panorama := PanoramaSkyMaterial.new()
    panorama.panorama = sky_texture
    panorama.energy_multiplier = 0.82
    panorama.filter = true
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    sky.sky_material = panorama
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.background_energy_multiplier = 0.90
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_sky_contribution = 0.90
    env.ambient_light_color = Color("#d7e0e5")
    env.ambient_light_energy = 0.70
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    return true

func _configure_fallback_environment(env: Environment) -> void:
    var fallback := ProceduralSkyMaterial.new()
    fallback.sky_top_color = Color("#557b9a")
    fallback.sky_horizon_color = Color("#a9bac6")
    fallback.ground_horizon_color = Color("#87937f")
    fallback.ground_bottom_color = Color("#404b3c")
    fallback.energy_multiplier = 0.86
    var sky := Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    sky.sky_material = fallback
    env.sky = sky
    env.background_mode = Environment.BG_SKY
    env.background_energy_multiplier = 0.86
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_sky_contribution = 0.82
    env.ambient_light_color = Color("#d6e0e5")
    env.ambient_light_energy = 0.66
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG

func _build_stage() -> void:
    _world_blockers.clear()
    _circle_blockers.clear()

    # Concentrate mobile shadow resolution near the player.
    RenderingServer.directional_shadow_atlas_set_size(4096, true)
    RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

    var world := WorldEnvironment.new()
    var env := Environment.new()
    _diag_stage("AF-LIGHT-222", "Loading Poly Haven Kloppenheim 03 1K HDR atmosphere.")
    var hdri_ready := _configure_hdri_environment(env)
    if not hdri_ready:
        _configure_fallback_environment(env)
        _diag_stage("AF-LIGHT-223", "HDRI unavailable; using mobile procedural-sky fallback.")
    else:
        _diag_stage("AF-LIGHT-224", "Poly Haven HDRI loaded successfully.")

    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 0.88
    env.tonemap_white = 4.6
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.03
    env.adjustment_contrast = 1.01
    env.adjustment_saturation = 0.97

    # Lightweight depth fog adds distance separation without Forward+ volumetrics.
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_DEPTH
    env.fog_light_color = Color("#a8b8c3")
    env.fog_light_energy = 0.34
    env.fog_depth_begin = 38.0
    env.fog_depth_end = 92.0
    env.fog_depth_curve = 1.08
    env.fog_sky_affect = 0.09
    env.fog_sun_scatter = 0.03

    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-39, -28, 0)
    sun.light_color = Color("#ffe0b9")
    sun.light_energy = 0.86
    sun.shadow_enabled = true
    # Tight blended cascades plus softer contrast reduce blocky road shadows.
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    sun.directional_shadow_max_distance = 38.0
    sun.directional_shadow_split_1 = 0.10
    sun.directional_shadow_split_2 = 0.26
    sun.directional_shadow_split_3 = 0.52
    sun.directional_shadow_blend_splits = true
    sun.directional_shadow_fade_start = 0.84
    sun.directional_shadow_pancake_size = 9.0
    sun.shadow_bias = 0.035
    sun.shadow_normal_bias = 0.55
    sun.shadow_blur = 2.0
    sun.shadow_opacity = 0.72
    add_child(sun)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-22, 148, 0)
    fill.light_color = Color("#c2d6e2")
    fill.light_energy = 0.24
    fill.shadow_enabled = false
    add_child(fill)

    # Ground: deeper grass tone with subtle patch variation around the edges.
    _box(self, "TownGround", Vector3(58.0, 0.16, 55.0), Vector3(0, -0.08, 0), Color("#536b45"), Vector3.ZERO, 1.0)
    for patch in [
        Vector3(-22,0,-18), Vector3(20,0,-19), Vector3(-23,0,10), Vector3(22,0,12),
        Vector3(-15,0,21), Vector3(16,0,21), Vector3(-18,0,-3), Vector3(19,0,2)
    ]:
        _cylinder(self, "GrassPatch", 2.4, 0.018, patch + Vector3(0,0.010,0), Color("#5f7750"))

    # Layered road beds with staggered stone courses and dirt shoulders.
    _road_shoulders()
    _road_base("EntryRoad", Vector3(0,0,2.0), Vector2(6.2,44.0))
    _road_stones_z(Vector3(0,0,2.0), 6.2, 44.0)
    _road_base("CrossRoad", Vector3(0,0,1.0), Vector2(42.0,5.6))
    _road_stones_x(Vector3(0,0,1.0), 42.0, 5.6)
    _road_base("MarketSquare", Vector3(0,0,-4.0), Vector2(16.0,14.0))
    _market_stones(Vector3(0,0,-4.0), Vector2(16.0,14.0))

    # Perimeter walls with caps and simple buttresses. The hard software boundary remains authoritative.
    _add_wall_segment(Vector3(-27.6, 1.7, 0), Vector3(1.2, 3.4, 52.0))
    _add_wall_segment(Vector3(27.6, 1.7, 0), Vector3(1.2, 3.4, 52.0))
    _add_wall_segment(Vector3(0, 1.7, -25.6), Vector3(56.4, 3.4, 1.2))
    _add_wall_segment(Vector3(-15.3, 1.7, 25.6), Vector3(25.8, 3.4, 1.2))
    _add_wall_segment(Vector3(15.3, 1.7, 25.6), Vector3(25.8, 3.4, 1.2))
    for z in range(-21, 22, 6):
        _box(self, "WallButtressL", Vector3(0.55, 2.4, 0.85), Vector3(-26.72,1.2,float(z)), Color("#625f59"))
        _box(self, "WallButtressR", Vector3(0.55, 2.4, 0.85), Vector3(26.72,1.2,float(z)), Color("#625f59"))
    for x in range(-22, 23, 6):
        _box(self, "WallButtressN", Vector3(0.85, 2.4, 0.55), Vector3(float(x),1.2,-24.72), Color("#625f59"))

    # Gatehouse towers, roofs and closed portcullis.
    _cylinder(self, "GateTowerL", 2.3, 6.0, Vector3(-4.1, 3.0, 24.6), Color("#706e68"))
    _cylinder(self, "GateTowerR", 2.3, 6.0, Vector3(4.1, 3.0, 24.6), Color("#706e68"))
    _tapered_cylinder(self, "GateRoofL", 2.65, 0.08, 2.2, Vector3(-4.1, 7.05, 24.6), Color("#5d3931"))
    _tapered_cylinder(self, "GateRoofR", 2.65, 0.08, 2.2, Vector3(4.1, 7.05, 24.6), Color("#5d3931"))
    _add_circle_blocker(Vector2(-4.1,24.6), 2.35, PLAYER_WORLD_RADIUS + 0.10)
    _add_circle_blocker(Vector2(4.1,24.6), 2.35, PLAYER_WORLD_RADIUS + 0.10)
    for x in range(-2, 3):
        _box(self, "GateBar", Vector3(0.18, 3.25, 0.22), Vector3(float(x) * 0.75, 1.63, 25.0), Color("#3e2c24"))
    _box(self, "GateCrossbar", Vector3(4.4, 0.20, 0.24), Vector3(0, 2.15, 25.0), Color("#3e2c24"))

    # Landmark buildings.
    _add_house(Vector3(-10.5, 0, -7.5), Vector3(7.7, 3.8, 6.3), Color("#d4c29e"), Color("#704039"), "ADVENTURERS GUILD")
    _add_house(Vector3(10.3, 0, -7.0), Vector3(7.0, 3.5, 6.0), Color("#d5b486"), Color("#60352f"), "THE INN")
    _add_house(Vector3(-11.0, 0, 7.8), Vector3(6.2, 3.2, 5.2), Color("#c6b38e"), Color("#494746"), "BLACKSMITH")
    _add_house(Vector3(10.6, 0, 7.8), Vector3(5.8, 3.1, 5.1), Color("#d2c092"), Color("#674638"), "GENERAL SHOP")

    # Residential ring.
    _add_house(Vector3(-20.0, 0, -15.7), Vector3(4.8, 2.9, 4.6), Color("#d7c7aa"), Color("#694a41"))
    _add_house(Vector3(19.8, 0, -15.0), Vector3(5.0, 3.0, 4.4), Color("#cbb99b"), Color("#624139"))
    _add_house(Vector3(-20.1, 0, 16.4), Vector3(4.7, 2.8, 4.2), Color("#d3c19e"), Color("#6b4a42"))
    _add_house(Vector3(19.8, 0, 16.2), Vector3(5.2, 3.0, 4.5), Color("#d1be9b"), Color("#603d36"))
    _add_house(Vector3(-10.0, 0, 17.0), Vector3(4.7, 2.8, 4.3), Color("#d8c6a4"), Color("#62443b"))
    _add_house(Vector3(10.0, 0, 17.2), Vector3(4.8, 2.9, 4.2), Color("#d2bc92"), Color("#684438"))

    # Fountain centerpiece: deeper stonework, wet accents, animated water and light streams.
    _cylinder(self, "FountainPlinth", 2.32, 0.20, Vector3(0, 0.10, -4.0), Color("#656966"), 0.94)
    _cylinder(self, "FountainBase", 2.15, 0.30, Vector3(0, 0.30, -4.0), Color("#777c79"), 0.91)
    _cylinder(self, "FountainStep", 1.82, 0.20, Vector3(0, 0.52, -4.0), Color("#8d928f"), 0.88)
    _cylinder(self, "FountainWetStone", 1.58, 0.17, Vector3(0, 0.68, -4.0), Color("#566466"), 0.46)
    _cylinder(self, "FountainBasinOuter", 1.52, 0.34, Vector3(0, 0.78, -4.0), Color("#999e9b"), 0.84)
    _cylinder(self, "FountainBasinInner", 1.30, 0.18, Vector3(0, 0.89, -4.0), Color("#4f6466"), 0.48)

    _fountain_water = _cylinder(self, "FountainWater", 1.21, 0.055, Vector3(0, 0.995, -4.0), Color("#55afc3"), 0.15)
    _fountain_water.material_override = _water_mat(Color("#55b8cd"), 0.70)

    _cylinder(self, "FountainColumnBase", 0.42, 0.20, Vector3(0, 1.05, -4.0), Color("#777f7c"), 0.82)
    _cylinder(self, "FountainColumn", 0.24, 1.36, Vector3(0, 1.70, -4.0), Color("#858d89"), 0.82)
    _cylinder(self, "FountainSpoutRing", 0.38, 0.18, Vector3(0, 2.28, -4.0), Color("#707875"), 0.74)

    # Four lightweight translucent streams angle from the spout toward the basin.
    _fountain_jets.clear()
    var jet_data := [
        [Vector3(0.62, 1.77, -4.0), Vector3(0, 0, -40)],
        [Vector3(-0.62, 1.77, -4.0), Vector3(0, 0, 40)],
        [Vector3(0, 1.77, -3.38), Vector3(40, 0, 0)],
        [Vector3(0, 1.77, -4.62), Vector3(-40, 0, 0)]
    ]
    for jet_entry in jet_data:
        var jet := _cylinder(self, "FountainJet", 0.032, 1.06, jet_entry[0], Color("#70c8da"), 0.12)
        jet.rotation_degrees = jet_entry[1]
        jet.material_override = _water_mat(Color("#79cddd"), 0.44)
        _fountain_jets.append(jet)

    _fountain_crystal = _sphere(self, "FountainCrystal", 0.34, Vector3(0, 2.68, -4.0), Color("#8ee2ec"), 0.10)
    _fountain_crystal.material_override = _crystal_mat(Color("#78d8e7"))
    _fountain_glow = OmniLight3D.new()
    _fountain_glow.position = Vector3(0, 2.68, -4.0)
    _fountain_glow.light_color = Color("#72d8e8")
    _fountain_glow.light_energy = 0.36
    _fountain_glow.omni_range = 3.8
    _fountain_glow.shadow_enabled = false
    add_child(_fountain_glow)

    # Low decorative stone accents outside the collision ring keep the square open.
    for accent_pos in [Vector3(-2.55,0.13,-5.85), Vector3(2.55,0.13,-5.85)]:
        _cylinder(self, "FountainAccent", 0.34, 0.26, accent_pos, Color("#737873"), 0.92)

    _add_circle_blocker(Vector2(0,-4.0), 2.05, PLAYER_WORLD_RADIUS + 0.08)

    # Market and props. Vendor fronts/backs are reserved: no benches, lamps, or
    # loose storage are placed inside the stall working/customer zones.
    _add_market_stall(Vector3(-5.1, 0, 0.8), Color("#9d4540"))
    _add_market_stall(Vector3(5.1, 0, 0.8), Color("#416791"))

    # Storage props sit beside buildings with explicit clearance from foundations.
    # Blacksmith barrels are on the west service side; shop barrel is east of the shop.
    _add_barrel(Vector3(-15.75,0,7.35))
    _add_barrel(Vector3(-15.75,0,8.25))
    _add_barrel(Vector3(15.20,0,8.10))

    # Organic trees plus shrubs tucked near buildings instead of lollipop spheres in the street.
    for tree_pos in [
        Vector3(-23,0,-6), Vector3(23,0,-5), Vector3(-22,0,5), Vector3(22,0,4),
        Vector3(-16,0,-21), Vector3(16,0,-21), Vector3(-5,0,-20), Vector3(6,0,-20),
        Vector3(-24,0,21), Vector3(24,0,21)
    ]:
        _add_tree(tree_pos, 0.82)
    var shrub_index := 0
    for shrub_pos in [
        Vector3(-15,0,-11), Vector3(-6,0,-11), Vector3(6,0,-11), Vector3(15,0,-11),
        Vector3(-15,0,11), Vector3(-7,0,11), Vector3(7,0,11), Vector3(15,0,11)
    ]:
        _add_shrub(shrub_pos, 0.9, shrub_index)
        shrub_index += 1

    # Lightweight landscaping around foundations and perimeter green space.
    for grass_pos in [
        Vector3(-18.0,0,-10.8), Vector3(-16.8,0,-12.2), Vector3(-7.5,0,-12.0),
        Vector3(8.2,0,-11.8), Vector3(17.2,0,-10.7), Vector3(18.4,0,-12.1),
        Vector3(-18.4,0,11.7), Vector3(-8.2,0,12.1), Vector3(8.6,0,12.0),
        Vector3(17.9,0,11.5), Vector3(-23.2,0,-11.5), Vector3(23.0,0,-10.8),
        Vector3(-23.0,0,12.0), Vector3(23.1,0,12.4)
    ]:
        _add_grass_clump(grass_pos, 1.0)

    _add_flower_patch(Vector3(-14.3,0,-10.9), Color("#d9879b"))
    _add_flower_patch(Vector3(-7.0,0,-11.1), Color("#d9b05f"))
    _add_flower_patch(Vector3(7.3,0,-11.0), Color("#8ea9d8"))
    _add_flower_patch(Vector3(14.2,0,-10.8), Color("#d9879b"))
    _add_flower_patch(Vector3(-14.0,0,11.0), Color("#9f86cf"))
    _add_flower_patch(Vector3(13.8,0,11.1), Color("#d9b05f"))

    for rock_pos in [
        Vector3(-24.0,0,-14.0), Vector3(24.1,0,-14.3),
        Vector3(-24.2,0,15.0), Vector3(24.0,0,15.2),
        Vector3(-18.5,0,-22.2), Vector3(18.7,0,-22.0)
    ]:
        _add_rock(rock_pos, 0.85)

    # Rest zones stay on the square perimeter and never occupy vendor work space.
    _add_bench(Vector3(-3.9,0,-8.9), 0)
    _add_bench(Vector3(3.9,0,-8.9), 0)
    _add_bench(Vector3(-3.15,0,4.35), 180)
    _add_bench(Vector3(3.15,0,4.35), 180)

    # Lamps sit on clear road/square edges, outside all building and stall footprints.
    _add_lamp(Vector3(-4.70,0,-10.25))
    _add_lamp(Vector3(4.70,0,-10.25))
    _add_lamp(Vector3(-5.45,0,4.45))
    _add_lamp(Vector3(5.45,0,4.45))

func _round_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    var header := ColorRect.new()
    header.position = Vector2(14, 12)
    header.size = Vector2(1010, 124)
    header.color = Color(0.035, 0.055, 0.10, 0.88)
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(header)

    _status = Label.new()
    _status.position = Vector2(28, 20)
    _status.size = Vector2(970, 54)
    _status.add_theme_font_size_override("font_size", 24)
    _status.add_theme_color_override("font_color", Color("#f3f6fa"))
    ui.add_child(_status)

    _detail = Label.new()
    _detail.position = Vector2(28, 70)
    _detail.size = Vector2(970, 58)
    _detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _detail.add_theme_font_size_override("font_size", 16)
    _detail.add_theme_color_override("font_color", Color("#b8cade"))
    ui.add_child(_detail)

    # Fixed left virtual stick. Touch anywhere in this zone and drag.
    _joystick_base = Panel.new()
    _joystick_base.name = "MoveStick"
    _joystick_base.anchor_left = 0.0
    _joystick_base.anchor_right = 0.0
    _joystick_base.anchor_top = 1.0
    _joystick_base.anchor_bottom = 1.0
    _joystick_base.offset_left = 38.0
    _joystick_base.offset_right = 206.0
    _joystick_base.offset_top = -210.0
    _joystick_base.offset_bottom = -42.0
    _joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_base.add_theme_stylebox_override("panel", _round_style(Color(0.12, 0.17, 0.24, 0.70), 84))
    ui.add_child(_joystick_base)

    _joystick_knob = Panel.new()
    _joystick_knob.size = Vector2(70, 70)
    _joystick_knob.position = (_joystick_base.size - _joystick_knob.size) * 0.5
    _joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_knob.add_theme_stylebox_override("panel", _round_style(Color(0.62, 0.73, 0.84, 0.88), 35))
    _joystick_base.add_child(_joystick_knob)

    _sprint_button = Button.new()
    _sprint_button.text = "SPRINT OFF"
    _sprint_button.anchor_left = 1.0
    _sprint_button.anchor_right = 1.0
    _sprint_button.anchor_top = 1.0
    _sprint_button.anchor_bottom = 1.0
    _sprint_button.offset_left = -202.0
    _sprint_button.offset_right = -34.0
    _sprint_button.offset_top = -142.0
    _sprint_button.offset_bottom = -48.0
    _sprint_button.add_theme_font_size_override("font_size", 21)
    _sprint_button.toggle_mode = true
    _sprint_button.toggled.connect(_on_sprint_toggled)
    ui.add_child(_sprint_button)

    var pause_button := Button.new()
    pause_button.text = "PAUSE"
    pause_button.anchor_left = 1.0
    pause_button.anchor_right = 1.0
    pause_button.offset_left = -202.0
    pause_button.offset_right = -92.0
    pause_button.offset_top = 18.0
    pause_button.offset_bottom = 70.0
    pause_button.pressed.connect(_toggle_pause)
    ui.add_child(pause_button)

    var reset_button := Button.new()
    reset_button.text = "RESET CAM"
    reset_button.anchor_left = 1.0
    reset_button.anchor_right = 1.0
    reset_button.offset_left = -326.0
    reset_button.offset_right = -210.0
    reset_button.offset_top = 18.0
    reset_button.offset_bottom = 70.0
    reset_button.pressed.connect(_reset_camera)
    ui.add_child(reset_button)

func _set_status(title: String, detail: String) -> void:
    if _status != null:
        _status.text = "AETHERFALL  |  STARTER TOWN 0.2N  |  " + title
    if _detail != null:
        _detail.text = detail

func _fail(message: String) -> void:
    _loaded = false
    _diag_failure("AF-MODEL-399", message)
    push_error("TRIPO_RUNTIME_FAIL: " + message)
    _set_status("LOAD ERROR", message + "\nThe app stays open so the error can be photographed.")

func _load_runtime_glb() -> void:
    _diag_stage("AF-MODEL-301", "Checking embedded character model file.")
    if not FileAccess.file_exists(MODEL_PATH):
        _fail("Embedded model file is missing: " + MODEL_PATH)
        return

    _diag_stage("AF-MODEL-302", "Reading embedded character model bytes.")
    var bytes := FileAccess.get_file_as_bytes(MODEL_PATH)
    if bytes.is_empty():
        _fail("Embedded GLB could not be read.")
        return

    _diag_stage("AF-MODEL-303", "Parsing character GLB with Godot GLTFDocument.")
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var err := document.append_from_buffer(bytes, "", state)
    if err != OK:
        _fail("Godot GLTFDocument returned error %d while parsing the GLB." % err)
        return

    _diag_stage("AF-MODEL-304", "GLB parsed. Generating character scene.")
    var generated := document.generate_scene(state)
    if generated == null:
        _fail("Godot parsed the GLB but could not generate its scene.")
        return

    _model = generated as Node3D
    if _model == null:
        generated.queue_free()
        _fail("Generated GLB root was not a Node3D.")
        return

    _diag_stage("AF-MODEL-305", "Character scene generated. Attaching model.")
    _model.name = "TripoAdventurer"
    _actor.add_child(_model)
    # Tripo visual forward is opposite the controller's actor forward.
    # Rotate only the generated model, not gameplay/world motion.
    _model.rotation.y = PI
    _polish_actor_materials(_model)
    _skeleton = _find_skeleton(_model)
    _animation = _find_animation_player(_model)

    _diag_stage("AF-RIG-306", "Searching generated character for skeleton and animations.")
    if _skeleton == null:
        _fail("No Skeleton3D was generated from the GLB.")
        return
    _diag_stage("AF-RIG-307", "Skeleton found. Verifying 65-joint Mixamo rig.")
    if _skeleton.get_bone_count() != 65:
        _fail("Expected 65 Mixamo joints, got %d." % _skeleton.get_bone_count())
        return
    _diag_stage("AF-ANIM-308", "Rig verified. Checking AnimationPlayer.")
    if _animation == null:
        _fail("No AnimationPlayer was generated from the embedded clips.")
        return

    _diag_stage("AF-ANIM-309", "AnimationPlayer found. Verifying Walk and Run clips.")
    var walk_clip := _clip_for("walk")
    var run_clip := _clip_for("run")
    if walk_clip.is_empty() or run_clip.is_empty():
        _fail("Walk/Run clips were not found. Imported: %s" % [str(_animation.get_animation_list())])
        return

    _neutral_pose.clear()
    for i in range(_skeleton.get_bone_count()):
        _neutral_pose.append(_skeleton.get_bone_pose(i))

    _hips_index = _find_bone_suffix("hips")
    _spine_index = _find_bone_suffix("spine")
    _spine1_index = _find_bone_suffix("spine1")
    _head_index = _find_bone_suffix("head")
    _left_foot_index = _find_bone_suffix("leftfoot")
    _right_foot_index = _find_bone_suffix("rightfoot")
    _left_toe_index = _find_bone_suffix("lefttoebase")
    _right_toe_index = _find_bone_suffix("righttoebase")
    _left_arm_index = _find_bone_suffix("leftarm")
    _right_arm_index = _find_bone_suffix("rightarm")
    _left_forearm_index = _find_bone_suffix("leftforearm")
    _right_forearm_index = _find_bone_suffix("rightforearm")
    _left_hand_index = _find_bone_suffix("lefthand")
    _right_hand_index = _find_bone_suffix("righthand")
    _left_finger_bones = _collect_finger_bones("lefthand")
    _right_finger_bones = _collect_finger_bones("righthand")
    if _hips_index < 0 or _left_foot_index < 0 or _right_foot_index < 0 or _left_toe_index < 0 or _right_toe_index < 0:
        _fail("Required Mixamo Hips/Foot/ToeBase bones could not be located.")
        return

    _neutral_hips_origin = _skeleton.get_bone_pose(_hips_index).origin
    _neutral_model_position = _model.position
    _diag_stage("AF-PLAYER-320", "Rig ready. Building relaxed idle and sole grounding.")
    _build_relaxed_idle_pose()
    _align_neutral_feet_to_floor()

    _loaded = true
    _set_motion("IDLE")
    _set_status("READY", "Visual Pass 1 • object collision + wall boundary • Tap SPRINT • drag right side to look")
    _diag_stage("AF-READY-900", "Starter Town, character, rig, animations and controls initialized successfully.")

func _polish_actor_materials(node: Node) -> void:
    # Restrict changes to recognizable hair and garment materials; retain
    # imported textured skin and unknown materials unchanged.
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var source := mesh_instance.get_active_material(surface_index)
                if not (source is StandardMaterial3D):
                    continue
                var surface_name := (String(source.resource_name) + " " + mesh_instance.name).to_lower()
                var roughness_target := -1.0
                if surface_name.contains("hair"):
                    roughness_target = 0.67
                elif surface_name.contains("leather") or surface_name.contains("coat") or surface_name.contains("jacket"):
                    roughness_target = 0.74
                elif surface_name.contains("boot"):
                    roughness_target = 0.79
                if roughness_target < 0.0:
                    continue
                var polished := source.duplicate() as StandardMaterial3D
                polished.roughness = lerpf(source.roughness, roughness_target, 0.45)
                mesh_instance.set_surface_override_material(surface_index, polished)
    for child in node.get_children():
        _polish_actor_materials(child)


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _find_bone_suffix(suffix: String) -> int:
    if _skeleton == null:
        return -1
    var needle := suffix.to_lower()
    for i in range(_skeleton.get_bone_count()):
        if String(_skeleton.get_bone_name(i)).to_lower().ends_with(needle):
            return i
    return -1

func _collect_finger_bones(hand_prefix: String) -> Array[int]:
    var result: Array[int] = []
    if _skeleton == null:
        return result
    var prefix := hand_prefix.to_lower()
    for i in range(_skeleton.get_bone_count()):
        var name := String(_skeleton.get_bone_name(i)).to_lower()
        if not name.contains(prefix):
            continue
        if name.contains("thumb") or name.contains("index") or name.contains("middle") or name.contains("ring") or name.contains("pinky"):
            result.append(i)
    return result

func _apply_relaxed_fingers() -> void:
    if _skeleton == null:
        return
    # Mixamo finger chains are nearly straight by default. A small mirrored
    # local-Z curl removes the splayed mannequin look without making fists.
    for i in range(_left_finger_bones.size()):
        var bone_index := _left_finger_bones[i]
        var name := String(_skeleton.get_bone_name(bone_index)).to_lower()
        var amount := 10.0
        if name.ends_with("2"):
            amount = 17.0
        elif name.ends_with("3"):
            amount = 20.0
        elif name.contains("thumb"):
            amount *= 0.55
        _apply_local_rotation(bone_index, Vector3.FORWARD, amount)
    for i in range(_right_finger_bones.size()):
        var bone_index := _right_finger_bones[i]
        var name := String(_skeleton.get_bone_name(bone_index)).to_lower()
        var amount := -10.0
        if name.ends_with("2"):
            amount = -17.0
        elif name.ends_with("3"):
            amount = -20.0
        elif name.contains("thumb"):
            amount *= 0.55
        _apply_local_rotation(bone_index, Vector3.FORWARD, amount)

func _clip_for(mode: String) -> String:
    if _animation == null:
        return ""
    var needle := mode.to_lower()
    for entry in _animation.get_animation_list():
        var raw := String(entry)
        var label := raw.to_lower()
        if label == needle or label.ends_with("/" + needle) or label.ends_with("|" + needle) or label.ends_with(":" + needle):
            return raw
    return ""

func _capture_transition_pose() -> void:
    _transition_from.clear()
    if _skeleton == null:
        return
    for i in range(_skeleton.get_bone_count()):
        _transition_from.append(_skeleton.get_bone_pose(i))
    _transition_elapsed = 0.0
    _transitioning = _transition_from.size() == _neutral_pose.size()

func _set_motion(mode: String) -> void:
    if not _loaded or _animation == null:
        _motion = mode
        return

    _capture_transition_pose()
    _paused = false
    _motion = mode

    if mode == "IDLE":
        # Preserve the current gait frame. _process blends it smoothly into the
        # living neutral pose instead of snapping straight to bind pose.
        _animation.stop(true)
        _idle_time = 0.0
    else:
        var clip_name := _clip_for(mode)
        if clip_name.is_empty():
            _fail("Missing animation clip for " + mode)
            return
        var clip := _animation.get_animation(clip_name)
        if clip != null:
            clip.loop_mode = Animation.LOOP_LINEAR
        var speed := WALK_SPEED if mode == "WALK" else RUN_SPEED
        _animation.speed_scale = 1.0
        # Manual skeleton blending below works even when coming from procedural idle.
        _animation.play(clip_name, 0.0, speed)

    _set_status(mode, _motion_detail())

func _motion_detail() -> String:
    var sprint_state := "SPRINT ON" if _sprint_held else "SPRINT OFF"
    if _boundary_flash > 0.0:
        return "COLLISION • %.2f m/s • %s • solid town geometry" % [_move_speed, sprint_state]
    return "Natural Idle Pose • %s • %.2f m/s • %s" % [_motion, _move_speed, sprint_state]

func _on_sprint_toggled(enabled: bool) -> void:
    _sprint_held = enabled
    if _sprint_button != null:
        _sprint_button.text = "SPRINT ON" if enabled else "SPRINT OFF"
    if _loaded and not _paused:
        _set_status(_motion, _motion_detail())

func _toggle_pause() -> void:
    if not _loaded:
        return
    _paused = not _paused
    if _paused:
        if _animation != null and _animation.is_playing():
            _animation.pause()
        _set_status("PAUSED", "Movement frozen • Drag right side to inspect • Tap PAUSE to resume")
    else:
        if _motion in ["WALK", "RUN"] and _animation != null:
            _animation.play()
        _set_status(_motion, _motion_detail())

func _reset_camera() -> void:
    _camera_yaw = _actor.rotation.y if _actor != null else 0.0
    _camera_pitch = 0.18
    _camera_distance = 4.0

func _set_joystick_visual(offset: Vector2) -> void:
    if _joystick_base == null or _joystick_knob == null:
        return
    var center := _joystick_base.size * 0.5
    _joystick_knob.position = center + offset - _joystick_knob.size * 0.5

func _update_joystick(screen_position: Vector2) -> void:
    if _joystick_base == null:
        return
    var center := _joystick_base.global_position + _joystick_base.size * 0.5
    var offset := screen_position - center
    if offset.length() > STICK_RADIUS:
        offset = offset.normalized() * STICK_RADIUS
    var normalized := offset / STICK_RADIUS
    if normalized.length() < STICK_DEADZONE:
        normalized = Vector2.ZERO
        offset = Vector2.ZERO
    _move_input = normalized
    _set_joystick_visual(offset)

func _release_joystick() -> void:
    _move_input = Vector2.ZERO
    _move_touch = -1
    _set_joystick_visual(Vector2.ZERO)

func _build_relaxed_idle_pose() -> void:
    _idle_pose.clear()
    if _skeleton == null or _neutral_pose.size() != _skeleton.get_bone_count():
        return
    # Start from the imported bind pose, then lower the T-pose arms into a
    # relaxed game-ready stance. These signs are measured for this Mixamo rig.
    for i in range(_neutral_pose.size()):
        _skeleton.set_bone_pose(i, _neutral_pose[i])
    # Bring the upper arms nearly vertical instead of leaving the residual
    # wide/splayed stance from the imported T-pose.
    _apply_local_rotation(_left_arm_index, Vector3.RIGHT, -83.0)
    _apply_local_rotation(_right_arm_index, Vector3.RIGHT, 83.0)
    # A restrained elbow bend keeps the silhouette relaxed rather than rigid.
    _apply_local_rotation(_left_forearm_index, Vector3.BACK, 8.0)
    _apply_local_rotation(_right_forearm_index, Vector3.BACK, -8.0)
    # Mixamo's bind-pose wrists leave the palms facing outward after the arms
    # are lowered. Roll the hands around their local length axis so the palms
    # sit toward the thighs instead of presenting outward.
    _apply_local_rotation(_left_hand_index, Vector3.RIGHT, 155.0)
    _apply_local_rotation(_right_hand_index, Vector3.RIGHT, 155.0)
    _apply_relaxed_fingers()
    for i in range(_skeleton.get_bone_count()):
        _idle_pose.append(_skeleton.get_bone_pose(i))

func _reset_idle_target() -> void:
    if _skeleton == null or _idle_pose.size() != _skeleton.get_bone_count():
        return
    for i in range(_idle_pose.size()):
        _skeleton.set_bone_pose(i, _idle_pose[i])

func _apply_idle_offsets(delta: float) -> void:
    _idle_time += delta
    var breath := sin(_idle_time * TAU / 4.4)
    var sway := sin(_idle_time * TAU / 6.8 + 0.7)

    if _hips_index >= 0:
        var hips := _skeleton.get_bone_pose(_hips_index)
        hips.origin.y += breath * 0.0018
        _skeleton.set_bone_pose(_hips_index, hips)
    _apply_local_rotation(_spine_index, Vector3.RIGHT, breath * 0.55 + sway * 0.18)
    _apply_local_rotation(_spine1_index, Vector3.RIGHT, breath * 0.75)
    _apply_local_rotation(_spine1_index, Vector3.FORWARD, sway * 0.32)
    _apply_local_rotation(_head_index, Vector3.UP, sway * 0.45)
    _apply_local_rotation(_head_index, Vector3.RIGHT, -breath * 0.20)

func _apply_local_rotation(index: int, axis: Vector3, degrees: float) -> void:
    if index < 0 or index >= _neutral_pose.size():
        return
    var base := _skeleton.get_bone_pose(index)
    var delta_basis := Basis(Quaternion(axis.normalized(), deg_to_rad(degrees)))
    _skeleton.set_bone_pose(index, base * Transform3D(delta_basis, Vector3.ZERO))

func _apply_transition(delta: float) -> void:
    if not _transitioning or _skeleton == null:
        return
    _transition_elapsed += delta
    var t := clampf(_transition_elapsed / MOTION_BLEND_TIME, 0.0, 1.0)
    var smooth_t := t * t * (3.0 - 2.0 * t)
    for i in range(_transition_from.size()):
        var target_pose := _skeleton.get_bone_pose(i)
        _skeleton.set_bone_pose(i, _transition_from[i].interpolate_with(target_pose, smooth_t))
    if t >= 1.0:
        _transitioning = false
        _transition_from.clear()

func _lock_root_motion() -> void:
    if not _loaded or _skeleton == null or _hips_index < 0:
        return
    # Keep vertical bob from the native clip but remove horizontal travel.
    var hips_pose := _skeleton.get_bone_pose(_hips_index)
    hips_pose.origin.x = _neutral_hips_origin.x
    hips_pose.origin.z = _neutral_hips_origin.z
    _skeleton.set_bone_pose(_hips_index, hips_pose)
    if _model != null:
        var model_pos := _model.position
        model_pos.x = _neutral_model_position.x
        model_pos.z = _neutral_model_position.z
        _model.position = model_pos

func _bone_world_y(index: int) -> float:
    if _skeleton == null or index < 0:
        return 999.0
    return _skeleton.to_global(_skeleton.get_bone_global_pose(index).origin).y

func _sole_floor_y() -> float:
    if _skeleton == null:
        return 0.0
    var scale_y := absf(_actor.scale.y)
    var foot_offset := FOOT_TO_SOLE_SOURCE_Y * scale_y
    var toe_offset := TOE_TO_SOLE_SOURCE_Y * scale_y
    # Use both ankle/foot and toe origins. During a stride either the heel or
    # the toe may be the lowest planted part of the boot.
    var left_sole := minf(_bone_world_y(_left_foot_index) - foot_offset,
                          _bone_world_y(_left_toe_index) - toe_offset)
    var right_sole := minf(_bone_world_y(_right_foot_index) - foot_offset,
                           _bone_world_y(_right_toe_index) - toe_offset)
    return minf(left_sole, right_sole)

func _build_ground_contact_shadow() -> void:
    # Tiny procedurally generated alpha texture creates soft boot contact on
    # Android without screen-space effects or an extra shadow-casting light.
    var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var p := Vector2((float(x) + 0.5) / 32.0 - 1.0, (float(y) + 0.5) / 32.0 - 1.0)
            var falloff := pow(clampf(1.0 - p.length_squared(), 0.0, 1.0), 2.2)
            image.set_pixel(x, y, Color(0.035, 0.044, 0.054, falloff * 0.23))
    var shadow_material := StandardMaterial3D.new()
    shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shadow_material.albedo_texture = ImageTexture.create_from_image(image)
    _ground_contact_shadow = MeshInstance3D.new()
    _ground_contact_shadow.name = "SoftBootContactShadow"
    var plane := PlaneMesh.new()
    plane.size = Vector2(1.24, 0.96)
    _ground_contact_shadow.mesh = plane
    _ground_contact_shadow.material_override = shadow_material
    _ground_contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _ground_contact_shadow.visible = false
    add_child(_ground_contact_shadow)


func _update_ground_contact_shadow() -> void:
    if _ground_contact_shadow == null or _actor == null:
        return
    _ground_contact_shadow.visible = _loaded
    if not _loaded:
        return
    var surface_y := _ground_surface_y(_actor.global_position)
    _ground_contact_shadow.global_position = Vector3(_actor.global_position.x, surface_y + 0.018, _actor.global_position.z)
    _ground_contact_shadow.rotation.y = _actor.rotation.y


func _ground_surface_y(world_position: Vector3) -> float:
    var x := world_position.x
    var z := world_position.z

    # Individual road stones sit above their darker road bed. Use the stone
    # top surface wherever the player is inside a paved gameplay region.
    var on_entry_road := absf(x) <= 3.10 and z >= -20.0 and z <= 24.0
    var on_cross_road := absf(x) <= 21.0 and z >= -1.80 and z <= 3.80
    var on_market_square := absf(x) <= 8.0 and z >= -11.0 and z <= 3.0
    if on_entry_road or on_cross_road or on_market_square:
        return 0.105

    # Dirt shoulders are only slightly above the lawn.
    var on_entry_shoulder := absf(absf(x) - 3.30) <= 0.24 and z >= -19.75 and z <= 23.75
    var on_cross_shoulder := absf(x) <= 20.75 and (absf(z + 2.02) <= 0.22 or absf(z - 4.02) <= 0.22)
    if on_entry_shoulder or on_cross_shoulder:
        return 0.036

    return 0.0

func _align_neutral_feet_to_floor() -> void:
    var surface_y := _ground_surface_y(_actor.global_position)
    var sole_y := _sole_floor_y()
    _actor.position.y += surface_y + SOLE_CLEARANCE_WORLD - sole_y
    # Store the rig's calibrated actor offset relative to a zero-height lawn,
    # then add the current surface height dynamically during movement.
    _base_actor_y = _actor.position.y - surface_y

func _correct_foot_ground(delta: float) -> void:
    if not _loaded or _paused:
        return
    var surface_y := _ground_surface_y(_actor.global_position)
    var target_sole_y := surface_y + SOLE_CLEARANCE_WORLD
    var base_on_surface := _base_actor_y + surface_y
    var sole_y := _sole_floor_y()
    var desired_y := _actor.position.y
    if sole_y < target_sole_y:
        # Only lift enough to solve penetration into the current walk surface.
        desired_y += target_sole_y - sole_y
    else:
        # Ease back toward the calibrated standing height for this surface.
        desired_y = lerpf(desired_y, base_on_surface, clampf(delta * 3.4, 0.0, 1.0))
    desired_y = clampf(desired_y, base_on_surface, base_on_surface + 0.16)
    _actor.position.y = lerpf(_actor.position.y, desired_y, clampf(delta * 16.0, 0.0, 1.0))

func _desired_input() -> Vector2:
    var keyboard := Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        keyboard.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        keyboard.x += 1.0
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        keyboard.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        keyboard.y += 1.0
    if keyboard.length() > 0.01:
        return keyboard.normalized()
    return _move_input

func _ensure_motion(mode: String) -> void:
    if mode != _motion:
        _set_motion(mode)

func _world_point_blocked(point: Vector2) -> bool:
    for blocker in _world_blockers:
        if blocker.has_point(point):
            return true
    for circle in _circle_blockers:
        var center := Vector2(circle.x, circle.y)
        if point.distance_to(center) < circle.z:
            return true
    return false

func _resolve_world_position(previous: Vector3) -> void:
    if _actor == null:
        return
    var requested := _actor.position
    var clamped_x := clampf(requested.x, TOWN_MIN_X + PLAYER_WORLD_RADIUS, TOWN_MAX_X - PLAYER_WORLD_RADIUS)
    var clamped_z := clampf(requested.z, TOWN_MIN_Z + PLAYER_WORLD_RADIUS, TOWN_MAX_Z - PLAYER_WORLD_RADIUS)
    var resolved := previous

    # Resolve one axis at a time so the player slides naturally along walls/buildings
    # instead of sticking or teleporting backward when moving diagonally into them.
    var x_test := Vector2(clamped_x, previous.z)
    if not _world_point_blocked(x_test):
        resolved.x = clamped_x
    var z_test := Vector2(resolved.x, clamped_z)
    if not _world_point_blocked(z_test):
        resolved.z = clamped_z

    _actor.position.x = resolved.x
    _actor.position.z = resolved.z
    var hit := absf(requested.x - resolved.x) > 0.001 or absf(requested.z - resolved.z) > 0.001
    if hit:
        _boundary_flash = 0.26
        _move_speed = minf(_move_speed, WALK_WORLD_SPEED * 0.72)

func _update_gameplay_movement(delta: float) -> void:
    if _actor == null or not _loaded or _paused:
        return
    var input_vec := _desired_input()
    var strength := clampf(input_vec.length(), 0.0, 1.0)
    var moving := strength > STICK_DEADZONE
    var wants_run := _sprint_held or Input.is_key_pressed(KEY_SHIFT)
    var target_speed := 0.0
    if moving:
        target_speed = (RUN_WORLD_SPEED if wants_run else WALK_WORLD_SPEED) * strength
    var rate := MOVE_ACCEL if target_speed > _move_speed else MOVE_DECEL
    _move_speed = move_toward(_move_speed, target_speed, rate * delta)

    if moving:
        # Stick up is -Z. Rotate that vector by the camera heading so movement
        # always feels camera-relative, like the final third-person game.
        var local_dir := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
        _travel_direction = (Basis(Vector3.UP, _camera_yaw) * local_dir).normalized()
        var target_yaw := atan2(-_travel_direction.x, -_travel_direction.z)
        _actor.rotation.y = lerp_angle(_actor.rotation.y, target_yaw, clampf(delta * TURN_RATE, 0.0, 1.0))

    if _move_speed > 0.04:
        var previous_position := _actor.position
        _actor.position += _travel_direction * _move_speed * delta
        _resolve_world_position(previous_position)

    var desired_motion := "IDLE"
    if _move_speed > 0.12:
        desired_motion = "RUN" if wants_run and _move_speed > WALK_WORLD_SPEED * 0.85 else "WALK"
    _ensure_motion(desired_motion)

    # Match cadence to actual travel during acceleration/deceleration to reduce
    # visible foot sliding before we introduce full AnimationTree locomotion.
    if _animation != null and _motion == "WALK":
        _animation.speed_scale = clampf(_move_speed / WALK_WORLD_SPEED, 0.72, 1.05)
    elif _animation != null and _motion == "RUN":
        _animation.speed_scale = clampf(_move_speed / RUN_WORLD_SPEED, 0.82, 1.08)
    elif _animation != null:
        _animation.speed_scale = 1.0

func _update_fountain(delta: float) -> void:
    if _fountain_water == null:
        return
    _fountain_time += delta
    var ripple := sin(_fountain_time * 2.2)
    _fountain_water.position.y = 0.995 + ripple * 0.012
    _fountain_water.rotation.y = _fountain_time * 0.035

    if _fountain_crystal != null:
        _fountain_crystal.position.y = 2.68 + sin(_fountain_time * 1.6) * 0.035
        _fountain_crystal.rotation.y += delta * 0.48
    if _fountain_glow != null:
        _fountain_glow.light_energy = 0.34 + (sin(_fountain_time * 1.8) + 1.0) * 0.045
    for i in range(_fountain_jets.size()):
        var jet := _fountain_jets[i]
        if jet != null:
            var pulse := sin(_fountain_time * 3.0 + float(i) * 0.9)
            jet.scale.y = 1.0 + pulse * 0.035

func _process(delta: float) -> void:
    if not _startup_complete and not _startup_failed:
        _startup_elapsed += delta
        if _startup_elapsed >= STARTUP_WATCHDOG_SECONDS:
            _diag_failure("AF-WATCH-500", "Startup stopped before READY. Last stage: " + _diag_code + " - " + _diag_detail_text)
    _boundary_flash = maxf(0.0, _boundary_flash - delta)
    _update_gameplay_movement(delta)
    if _loaded and not _paused:
        if _motion == "IDLE":
            _reset_idle_target()
            _apply_idle_offsets(delta)
        _apply_transition(delta)
        _lock_root_motion()
        _correct_foot_ground(delta)
    _update_fountain(delta)
    _update_ground_contact_shadow()
    _update_camera(delta)
    if _loaded and not _paused:
        _set_status(_motion, _motion_detail())

func _update_camera(delta: float) -> void:
    if _camera == null or _actor == null:
        return
    var horizontal := cos(_camera_pitch) * _camera_distance
    var vertical := sin(_camera_pitch) * _camera_distance
    var target := _actor.global_position + Vector3(0.0, 1.03, 0.0)
    # At yaw zero the camera is +Z, behind a model whose forward is -Z.
    var offset := Vector3(sin(_camera_yaw) * horizontal, 0.55 + vertical, cos(_camera_yaw) * horizontal)
    var goal := target + offset
    if delta >= 1.0:
        _camera.global_position = goal
    else:
        _camera.global_position = _camera.global_position.lerp(goal, clampf(delta * 8.5, 0.0, 1.0))
    _camera.look_at(target, Vector3.UP)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var view := get_viewport().get_visible_rect().size
        if event.pressed:
            if event.position.x < view.x * 0.43 and event.position.y > view.y * 0.42 and _move_touch < 0:
                _move_touch = event.index
                _update_joystick(event.position)
            elif _sprint_button != null and _sprint_button.get_global_rect().has_point(event.position):
                # The GUI button handles this touch. Keep it out of camera-drag state
                # so Sprint can be tapped with a second finger while steering.
                pass
            elif event.position.x > view.x * 0.42 and _camera_touch < 0:
                _camera_touch = event.index
        else:
            if event.index == _move_touch:
                _release_joystick()
            if event.index == _camera_touch:
                _camera_touch = -1
    elif event is InputEventScreenDrag:
        if event.index == _move_touch:
            _update_joystick(event.position)
        elif event.index == _camera_touch:
            _camera_yaw -= event.relative.x * 0.0045
            _camera_pitch = clampf(_camera_pitch + event.relative.y * 0.0023, -0.08, 0.56)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _drag_mouse = event.pressed
    elif event is InputEventMouseMotion and _drag_mouse:
        _camera_yaw -= event.relative.x * 0.0045
        _camera_pitch = clampf(_camera_pitch + event.relative.y * 0.0023, -0.08, 0.56)
