extends Node3D
## Aetherfall MPFB+Rigify character-test APK ONLY.
## This is an isolated motion/weighting preview, not final gameplay animation.
## Four independently generated skinned GLBs; no shipping avatar references.

const HAIR_NAMES := ["Windswept", "Long", "Short", "Ponytail"]
const MODEL_PATHS := [
    "res://models/prototype.glb",
    "res://models/long.glb",
    "res://models/short.glb",
    "res://models/ponytail.glb"
]

var _model: Node3D
var _actor: Node3D
var _rig: Skeleton3D
var _camera: Camera3D
var _status: Label
var _style_index := 0
var _mode := "IDLE"
var _time := 0.0
var _jump_time := -1.0
var _yaw := 0.0
var _pitch := 0.12
var _front_camera := true
var _mouse_dragging := false

func _ready() -> void:
    _build_world()
    _actor = Node3D.new()
    _actor.name = "DemoActor"
    add_child(_actor)
    _camera = Camera3D.new()
    _camera.name = "OrbitCamera"
    _camera.current = true
    _camera.fov = 56.0
    _camera.near = 0.05
    _camera.far = 180.0
    add_child(_camera)
    _build_ui()
    _select_style(0)
    _update_camera(1.0)

func _build_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#192539")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#bdcbea")
    env.ambient_light_energy = 0.80
    world.environment = env
    add_child(world)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48, -28, 0)
    key_light.light_energy = 1.35
    key_light.shadow_enabled = true
    add_child(key_light)

    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-28, 155, 0)
    fill_light.light_energy = 0.40
    fill_light.light_color = Color("#91b5ff")
    add_child(fill_light)

    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(180, 0.16, 180)
    var floor_visual := MeshInstance3D.new()
    floor_visual.name = "TestArenaFloor"
    floor_visual.mesh = floor_mesh
    floor_visual.position.y = -0.08
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#35485a")
    floor_material.roughness = 0.95
    floor_visual.material_override = floor_material
    add_child(floor_visual)

    var grid_material := StandardMaterial3D.new()
    grid_material.albedo_color = Color("#637383")
    grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for line in range(-8, 9):
        for orientation in range(2):
            var guide := MeshInstance3D.new()
            var line_mesh := BoxMesh.new()
            line_mesh.size = Vector3(0.016, 0.009, 40) if orientation == 0 else Vector3(40, 0.009, 0.016)
            guide.mesh = line_mesh
            guide.position = Vector3(float(line) * 2.5, 0.008, 0) if orientation == 0 else Vector3(0, 0.008, float(line) * 2.5)
            guide.material_override = grid_material
            add_child(guide)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "TouchInterface"
    add_child(layer)

    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)

    _status = Label.new()
    _status.position = Vector2(28, 22)
    _status.size = Vector2(1080, 76)
    _status.add_theme_font_size_override("font_size", 23)
    _status.add_theme_color_override("font_color", Color("#f0f3fa"))
    ui.add_child(_status)

    var help := Label.new()
    help.position = Vector2(28, 99)
    help.size = Vector2(1120, 38)
    help.text = "Swipe to orbit • View switches front/back • Motion is procedural QA, not final animation"
    help.add_theme_font_size_override("font_size", 16)
    help.add_theme_color_override("font_color", Color("#b7c8e4"))
    ui.add_child(help)

    var bottom := HBoxContainer.new()
    bottom.anchor_left = 0.0
    bottom.anchor_right = 1.0
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_left = 22.0
    bottom.offset_right = -22.0
    bottom.offset_top = -103.0
    bottom.offset_bottom = -17.0
    bottom.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom.add_theme_constant_override("separation", 14)
    ui.add_child(bottom)
    for name in ["IDLE", "WALK", "RUN", "JUMP", "HAIR", "VIEW"]:
        var button := Button.new()
        button.text = name
        button.custom_minimum_size = Vector2(170, 76)
        button.add_theme_font_size_override("font_size", 21)
        button.pressed.connect(_on_button.bind(name))
        bottom.add_child(button)

func _on_button(name: String) -> void:
    match name:
        "IDLE", "WALK", "RUN":
            _mode = name
        "JUMP":
            _jump_time = 0.0
        "HAIR":
            _select_style((_style_index + 1) % HAIR_NAMES.size())
        "VIEW":
            _front_camera = not _front_camera
    _update_status()

func _find_rig(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_rig(child)
        if found != null:
            return found
    return null

func _select_style(index: int) -> void:
    if _model != null:
        _actor.remove_child(_model)
        _model.queue_free()
    _style_index = index
    var source: PackedScene = load(MODEL_PATHS[index])
    if source == null:
        push_error("Missing test character: " + MODEL_PATHS[index])
        return
    _model = source.instantiate() as Node3D
    if _model == null:
        push_error("GLB root is not Node3D: " + MODEL_PATHS[index])
        return
    _model.name = "Character_" + HAIR_NAMES[index]
    _actor.add_child(_model)
    _rig = _find_rig(_model)
    if _rig == null or _rig.get_bone_count() != 96:
        push_error("Character rig import did not preserve 96 deformation joints")
    _update_status()

func _update_status() -> void:
    if _status == null:
        return
    var bone_count := _rig.get_bone_count() if _rig != null else 0
    _status.text = "AETHERFALL  |  3D CHARACTER TEST\n%s hair  •  %s pose  •  %d deform bones" % [
        HAIR_NAMES[_style_index], _mode, bone_count
    ]

func _pose_bone(name: String, degrees: float) -> void:
    if _rig == null:
        return
    var idx := _rig.find_bone(name)
    if idx < 0:
        return
    # Convert the desired character-local hinge axis into this Rigify bone's
    # rest frame. This prevents mirrored legs bending around a guessed axis.
    var rest_basis := _rig.get_bone_global_rest(idx).basis
    var axis := (rest_basis.inverse() * Vector3.RIGHT).normalized()
    _rig.set_bone_pose_rotation(idx, Quaternion(axis, deg_to_rad(degrees)))

func _set_demo_pose(delta: float) -> void:
    if _rig == null:
        return
    _rig.reset_bone_poses()
    var speed := 0.0
    var swing := 0.0
    var lift_left := 0.0
    var lift_right := 0.0
    if _mode == "WALK":
        speed = 7.0
        swing = 27.0
    elif _mode == "RUN":
        speed = 11.0
        swing = 43.0
    var phase := _time * speed
    if speed > 0.0:
        lift_left = maxf(0.0, sin(phase + 0.5))
        lift_right = maxf(0.0, -sin(phase + 0.5))

    var left := sin(phase) * swing
    var right := -left
    var left_knee := -lift_left * (44.0 if _mode == "RUN" else 29.0)
    var right_knee := -lift_right * (44.0 if _mode == "RUN" else 29.0)

    if _jump_time >= 0.0:
        _jump_time += delta
        _actor.position.y = maxf(0.0, sin(_jump_time * PI / 0.82)) * 0.78
        left = 16.0
        right = 16.0
        left_knee = -40.0
        right_knee = -40.0
        if _jump_time >= 0.82:
            _jump_time = -1.0
            _actor.position.y = 0.0
    else:
        _actor.position.y = 0.0

    _pose_bone("DEF-thigh.L", left)
    _pose_bone("DEF-thigh.R", right)
    _pose_bone("DEF-shin.L", left_knee)
    _pose_bone("DEF-shin.R", right_knee)
    _pose_bone("DEF-foot.L", -left * 0.23 - left_knee * 0.36)
    _pose_bone("DEF-foot.R", -right * 0.23 - right_knee * 0.36)
    _pose_bone("DEF-upper_arm.L", -left * 0.42)
    _pose_bone("DEF-upper_arm.R", -right * 0.42)
    _pose_bone("DEF-forearm.L", -11.0 - lift_left * 9.0)
    _pose_bone("DEF-forearm.R", -11.0 - lift_right * 9.0)

func _process(delta: float) -> void:
    _time += delta
    var moving := _mode == "WALK" or _mode == "RUN"
    if moving:
        var velocity := 1.25 if _mode == "WALK" else 2.45
        _actor.position.z = clampf(_actor.position.z - velocity * delta, -65.0, 20.0)
        if _actor.position.z <= -64.9:
            _actor.position.z = 0.0
    _set_demo_pose(delta)
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    if _camera == null or _actor == null:
        return
    var radius := 4.2
    var azimuth := _yaw + (0.0 if _front_camera else PI)
    var center := _actor.global_position + Vector3(0.0, 1.0, 0.0)
    var destination := center + Vector3(sin(azimuth) * radius,
        1.0 + _pitch * 2.3, -cos(azimuth) * radius)
    _camera.global_position = _camera.global_position.lerp(destination, clampf(delta * 8.0, 0.0, 1.0))
    _camera.look_at(center, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        _yaw -= event.relative.x * 0.006
        _pitch = clampf(_pitch + event.relative.y * 0.002, -0.32, 0.7)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _mouse_dragging = event.pressed
    elif event is InputEventMouseMotion and _mouse_dragging:
        _yaw -= event.relative.x * 0.006
        _pitch = clampf(_pitch + event.relative.y * 0.002, -0.32, 0.7)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1: _on_button("IDLE")
            KEY_2: _on_button("WALK")
            KEY_3: _on_button("RUN")
            KEY_SPACE: _on_button("JUMP")
            KEY_H: _on_button("HAIR")
            KEY_C: _on_button("VIEW")
