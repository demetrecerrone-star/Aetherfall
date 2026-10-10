extends Node3D
## Standalone QA for a user-authored Tripo GLB, never the release Aetherfall avatar.
## Uses embedded Mixamo walk/run animation rather than approximate procedural poses.
const MODEL_PATH := "res://models/tripo_adventurer.glb"

var _actor: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _neutral_pose: Array[Transform3D] = []
var _camera: Camera3D
var _status: Label
var _motion := "IDLE"
var _zoom := 2.9
var _yaw := 0.0
var _pitch := 0.08
var _front := true
var _drag_mouse := false
var _last_status := -1

func _ready() -> void:
    _create_stage()
    _actor = Node3D.new()
    _actor.name = "TripoActor"
    # Source geometry is approximately 0.98 m tall. Scale the actor, not the
    # imported skeleton, to a consistent 1.65 m Godot world height.
    _actor.scale = Vector3.ONE * 1.7
    add_child(_actor)
    _camera = Camera3D.new()
    _camera.name = "OrbitCamera"
    _camera.current = true
    _camera.fov = 52.0
    _camera.near = 0.04
    _camera.far = 125.0
    add_child(_camera)
    _create_interface()
    _load_model()
    _update_camera(1.0)

func _create_stage() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#192637")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#c1d0df")
    env.ambient_light_energy = 0.40
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-52, -36, 0)
    key_light.light_energy = 0.80
    key_light.shadow_enabled = true
    add_child(key_light)
    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-35, 155, 0)
    fill_light.light_energy = 0.24
    add_child(fill_light)
    var floor := MeshInstance3D.new()
    floor.name = "PreviewFloor"
    var base := BoxMesh.new()
    base.size = Vector3(50.0, 0.12, 50.0)
    floor.mesh = base
    floor.position.y = -0.06
    var m := StandardMaterial3D.new()
    m.albedo_color = Color("#35465b")
    m.roughness = 1.0
    floor.material_override = m
    add_child(floor)

func _create_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root_control := Control.new()
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root_control)

    var back := ColorRect.new()
    back.position = Vector2(14, 12)
    back.size = Vector2(1020, 117)
    back.color = Color(0.04, 0.06, 0.11, 0.85)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(back)

    _status = Label.new()
    _status.position = Vector2(26, 20)
    _status.size = Vector2(990, 90)
    _status.add_theme_font_size_override("font_size", 22)
    _status.add_theme_color_override("font_color", Color("#eef3f9"))
    root_control.add_child(_status)

    var hint := Label.new()
    hint.position = Vector2(26, 104)
    hint.size = Vector2(1000, 28)
    hint.text = "REAL Tripo GLB + embedded Mixamo clips • Swipe to orbit • Zoom to inspect"
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color("#b5c8d9"))
    root_control.add_child(hint)

    var controls := HBoxContainer.new()
    controls.anchor_left = 0
    controls.anchor_right = 1
    controls.anchor_top = 1
    controls.anchor_bottom = 1
    controls.offset_left = 18
    controls.offset_right = -18
    controls.offset_top = -100
    controls.offset_bottom = -15
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 10)
    root_control.add_child(controls)
    for key in ["IDLE", "WALK", "RUN", "PAUSE", "VIEW", "ZOOM +", "ZOOM -"]:
        var control := Button.new()
        control.text = key
        control.custom_minimum_size = Vector2(154, 72)
        control.add_theme_font_size_override("font_size", 21)
        control.pressed.connect(_on_control.bind(key))
        controls.add_child(control)

func _find_rig(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for c in node.get_children():
        var s := _find_rig(c)
        if s != null:
            return s
    return null

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for c in node.get_children():
        var p := _find_animation_player(c)
        if p != null:
            return p
    return null

func _clip_for(mode: String) -> String:
    if _animation == null:
        return ""
    for entry in _animation.get_animation_list():
        var label := String(entry).to_lower()
        if label == mode.to_lower() or label.ends_with("/" + mode.to_lower()) or label.ends_with("|" + mode.to_lower()):
            return String(entry)
    return ""

func _load_model() -> void:
    var packed: PackedScene = load(MODEL_PATH)
    if packed == null:
        push_error("TRIPO_TEST_FAIL: No model file. Upload Tripo GLB to workflow.")
        return
    _model = packed.instantiate() as Node3D
    if _model == null:
        push_error("TRIPO_TEST_FAIL: GLB root not Node3D")
        return
    _model.name = "TripoAdventurer"
    _actor.add_child(_model)
    _skeleton = _find_rig(_model)
    _animation = _find_animation_player(_model)
    if _skeleton == null or _skeleton.get_bone_count() != 65:
        push_error("TRIPO_TEST_FAIL: expected the verified 65-joint Mixamo rig")
        return
    if _animation == null or _clip_for("walk").is_empty() or _clip_for("run").is_empty():
        push_error("TRIPO_TEST_FAIL: missing imported walk/run clips")
        return
    for idx in range(_skeleton.get_bone_count()):
        _neutral_pose.append(_skeleton.get_bone_pose(idx))
    # User can inspect a safe unchanged bind-pose before playing clips.
    _set_motion("IDLE")
    _update_status()

func _set_motion(mode: String) -> void:
    _motion = mode
    if _animation == null:
        return
    if mode == "IDLE":
        _animation.stop()
        if _skeleton != null and _neutral_pose.size() == _skeleton.get_bone_count():
            for i in range(_neutral_pose.size()):
                _skeleton.set_bone_pose(i, _neutral_pose[i])
    else:
        var clip_name := _clip_for(mode)
        if not clip_name.is_empty():
            var clip := _animation.get_animation(clip_name)
            if clip != null:
                clip.loop_mode = Animation.LOOP_LINEAR
            _animation.play(clip_name, 0.16)
        else:
            push_error("TRIPO_TEST_FAIL: missing motion clip: " + mode)
    _update_status()

func _on_control(key: String) -> void:
    match key:
        "IDLE", "WALK", "RUN":
            _set_motion(key)
        "PAUSE":
            if _animation != null:
                if _animation.is_playing():
                    _animation.pause()
                else:
                    _set_motion("RUN" if _motion == "RUN" else "WALK")
        "VIEW":
            _front = not _front
        "ZOOM +":
            _zoom = maxf(1.15, _zoom - 0.45)
        "ZOOM -":
            _zoom = minf(5.80, _zoom + 0.45)
    _update_status()

func _update_status() -> void:
    if _status == null:
        return
    var joints := _skeleton.get_bone_count() if _skeleton != null else 0
    _status.text = "AETHERFALL  |  TRIPO 3D CHARACTER TEST\n%s  •  %d/65 Mixamo joints  •  Native Walk + Run clips" % [_motion, joints]

func _process(delta: float) -> void:
    _update_camera(delta)
    var fps := Engine.get_frames_per_second()
    if fps != _last_status and _status != null and fps >= 1:
        _last_status = fps
        # Nonintrusive readout for testing Android performance.
        _status.tooltip_text = "%d FPS" % fps

func _update_camera(delta: float) -> void:
    if _actor == null or _camera == null:
        return
    var angle := _yaw + (PI if _front else 0.0)
    var target := _actor.global_position + Vector3(0.0, 0.88, 0.0)
    var goal := target + Vector3(sin(angle) * _zoom, 0.35 + _pitch * 1.7, -cos(angle) * _zoom)
    _camera.global_position = goal if delta >= 1.0 else _camera.global_position.lerp(goal, clampf(delta * 8.0, 0.0, 1.0))
    _camera.look_at(target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        _yaw -= event.relative.x * 0.006
        _pitch = clampf(_pitch + event.relative.y * 0.002, -0.38, 0.65)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _drag_mouse = event.pressed
    elif event is InputEventMouseMotion and _drag_mouse:
        _yaw -= event.relative.x * 0.006
        _pitch = clampf(_pitch + event.relative.y * 0.002, -0.38, 0.65)
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1: _on_control("IDLE")
            KEY_2: _on_control("WALK")
            KEY_3: _on_control("RUN")
            KEY_SPACE: _on_control("PAUSE")
            KEY_C: _on_control("VIEW")
