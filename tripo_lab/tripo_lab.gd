extends Node3D
## Standalone QA for a user-authored Tripo GLB, never the release Aetherfall avatar.
## Uses embedded Mixamo walk/run animation rather than approximate procedural poses.
const MODEL_PATH := "res://models/tripo_adventurer.glb"
const FOOT_TO_SOLE_SOURCE_Y := 0.067
const TOE_TO_SOLE_SOURCE_Y := 0.017
const SOLE_CLEARANCE_WORLD := 0.010
const WALK_WORLD_SPEED := 1.75
const RUN_WORLD_SPEED := 4.15
const MOVE_ACCEL := 7.5
const MOVE_DECEL := 10.5
const TURN_RATE := 9.0
const STICK_DEADZONE := 0.10
const STICK_RADIUS := 68.0

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
var _neutral_hips_origin := Vector3.ZERO
var _neutral_model_position := Vector3.ZERO
var _base_actor_y := 0.0
var _idle_time := 0.0
var _paused := false
var _camera: Camera3D
var _status: Label
var _motion := "IDLE"
var _zoom := 2.25
var _yaw := 0.0
var _pitch := 0.08
var _front := false
var _drag_mouse := false
var _last_status := -1
var _move_input := Vector2.ZERO
var _move_touch := -1
var _camera_touch := -1
var _sprint_held := false
var _move_speed := 0.0
var _travel_direction := Vector3(0.0, 0.0, -1.0)
var _camera_yaw := 0.0
var _camera_pitch := 0.18
var _camera_distance := 4.0
var _joystick_base: Panel
var _joystick_knob: Panel
var _sprint_button: Button

func _ready() -> void:
    # Apply corrections after imported animation evaluation.
    process_priority = 1000
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

    var grid_material := StandardMaterial3D.new()
    grid_material.albedo_color = Color("#526b82")
    grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for line in range(-15, 16):
        for axis in range(2):
            var guide := MeshInstance3D.new()
            var strip := BoxMesh.new()
            strip.size = Vector3(0.012, 0.008, 60.0) if axis == 0 else Vector3(60.0, 0.008, 0.012)
            guide.mesh = strip
            guide.position = Vector3(float(line) * 2.0, 0.006, 0.0) if axis == 0 else Vector3(0.0, 0.006, float(line) * 2.0)
            guide.material_override = grid_material
            add_child(guide)

func _round_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = radius
    style.corner_radius_top_right = radius
    style.corner_radius_bottom_left = radius
    style.corner_radius_bottom_right = radius
    return style

func _create_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root_control := Control.new()
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root_control)

    var back := ColorRect.new()
    back.position = Vector2(14, 12)
    back.size = Vector2(1030, 120)
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
    hint.position = Vector2(26, 82)
    hint.size = Vector2(990, 42)
    hint.text = "Left stick move • Hold SPRINT to run • Drag right side to look"
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color("#b5c8d9"))
    root_control.add_child(hint)

    _joystick_base = Panel.new()
    _joystick_base.anchor_top = 1.0
    _joystick_base.anchor_bottom = 1.0
    _joystick_base.offset_left = 38.0
    _joystick_base.offset_right = 206.0
    _joystick_base.offset_top = -210.0
    _joystick_base.offset_bottom = -42.0
    _joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_base.add_theme_stylebox_override("panel", _round_style(Color(0.12,0.17,0.24,0.70),84))
    root_control.add_child(_joystick_base)

    _joystick_knob = Panel.new()
    _joystick_knob.size = Vector2(70,70)
    _joystick_knob.position = Vector2(49,49)
    _joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _joystick_knob.add_theme_stylebox_override("panel", _round_style(Color(0.62,0.73,0.84,0.88),35))
    _joystick_base.add_child(_joystick_knob)

    _sprint_button = Button.new()
    _sprint_button.text = "SPRINT"
    _sprint_button.anchor_left = 1.0
    _sprint_button.anchor_right = 1.0
    _sprint_button.anchor_top = 1.0
    _sprint_button.anchor_bottom = 1.0
    _sprint_button.offset_left = -202.0
    _sprint_button.offset_right = -34.0
    _sprint_button.offset_top = -142.0
    _sprint_button.offset_bottom = -48.0
    _sprint_button.add_theme_font_size_override("font_size",21)
    _sprint_button.button_down.connect(func(): _sprint_held = true)
    _sprint_button.button_up.connect(func(): _sprint_held = false)
    root_control.add_child(_sprint_button)

    var pause_button := Button.new()
    pause_button.text = "PAUSE"
    pause_button.anchor_left = 1.0
    pause_button.anchor_right = 1.0
    pause_button.offset_left = -202.0
    pause_button.offset_right = -92.0
    pause_button.offset_top = 18.0
    pause_button.offset_bottom = 70.0
    pause_button.pressed.connect(_toggle_pause)
    root_control.add_child(pause_button)

    var reset_button := Button.new()
    reset_button.text = "RESET CAM"
    reset_button.anchor_left = 1.0
    reset_button.anchor_right = 1.0
    reset_button.offset_left = -326.0
    reset_button.offset_right = -210.0
    reset_button.offset_top = 18.0
    reset_button.offset_bottom = 70.0
    reset_button.pressed.connect(_reset_camera)
    root_control.add_child(reset_button)

func _find_rig(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for c in node.get_children():
        var s := _find_rig(c)
        if s != null:
            return s
    return null

func _find_bone_suffix(suffix: String) -> int:
    if _skeleton == null:
        return -1
    var needle := suffix.to_lower()
    for i in range(_skeleton.get_bone_count()):
        if String(_skeleton.get_bone_name(i)).to_lower().ends_with(needle):
            return i
    return -1

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
    if _hips_index < 0 or _left_foot_index < 0 or _right_foot_index < 0 or _left_toe_index < 0 or _right_toe_index < 0:
        push_error("TRIPO_TEST_FAIL: required Hips/Foot/ToeBase bones missing")
        return
    _neutral_hips_origin = _skeleton.get_bone_pose(_hips_index).origin
    _neutral_model_position = _model.position
    _build_relaxed_idle_pose()
    _align_neutral_feet_to_floor()
    _set_motion("IDLE")
    _update_status()

func _capture_transition_pose() -> void:
    _transition_from.clear()
    if _skeleton == null:
        return
    for i in range(_skeleton.get_bone_count()):
        _transition_from.append(_skeleton.get_bone_pose(i))
    _transition_elapsed = 0.0
    _transitioning = _transition_from.size() == _neutral_pose.size()

func _set_motion(mode: String) -> void:
    _motion = mode
    if _animation == null:
        return
    _capture_transition_pose()
    _paused = false
    if mode == "IDLE":
        _animation.stop(true)
        _idle_time = 0.0
    else:
        var clip_name := _clip_for(mode)
        if clip_name.is_empty():
            push_error("TRIPO_TEST_FAIL: missing motion clip: " + mode)
            return
        var clip := _animation.get_animation(clip_name)
        if clip != null:
            clip.loop_mode = Animation.LOOP_LINEAR
        var speed := 0.92 if mode == "WALK" else 1.06
        _animation.play(clip_name, 0.0, speed)
    _update_status()

func _toggle_pause() -> void:
    if _animation == null:
        return
    _paused = not _paused
    if _paused:
        if _animation.is_playing():
            _animation.pause()
    elif _motion in ["WALK", "RUN"]:
        _animation.play()
    _update_status()

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

func _update_status() -> void:
    if _status == null:
        return
    var joints := _skeleton.get_bone_count() if _skeleton != null else 0
    var state := "PAUSED" if _paused else _motion
    _status.text = "AETHERFALL  |  CHARACTER PASS 4\n%s  •  %.2f m/s  •  %d/65 joints  •  gameplay locomotion" % [state, _move_speed, joints]

func _build_relaxed_idle_pose() -> void:
    _idle_pose.clear()
    if _skeleton == null or _neutral_pose.size() != _skeleton.get_bone_count():
        return
    for i in range(_neutral_pose.size()):
        _skeleton.set_bone_pose(i, _neutral_pose[i])
    _apply_local_rotation(_left_arm_index, Vector3.RIGHT, -72.0)
    _apply_local_rotation(_right_arm_index, Vector3.RIGHT, 72.0)
    _apply_local_rotation(_left_forearm_index, Vector3.BACK, 12.0)
    _apply_local_rotation(_right_forearm_index, Vector3.BACK, -12.0)
    for i in range(_skeleton.get_bone_count()):
        _idle_pose.append(_skeleton.get_bone_pose(i))

func _reset_idle_target() -> void:
    if _skeleton == null or _idle_pose.size() != _skeleton.get_bone_count():
        return
    for i in range(_idle_pose.size()):
        _skeleton.set_bone_pose(i, _idle_pose[i])

func _apply_local_rotation(index: int, axis: Vector3, degrees: float) -> void:
    if index < 0 or index >= _neutral_pose.size():
        return
    var pose := _skeleton.get_bone_pose(index)
    var delta_basis := Basis(Quaternion(axis.normalized(), deg_to_rad(degrees)))
    _skeleton.set_bone_pose(index, pose * Transform3D(delta_basis, Vector3.ZERO))

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

func _apply_transition(delta: float) -> void:
    if not _transitioning or _skeleton == null:
        return
    _transition_elapsed += delta
    var t := clampf(_transition_elapsed / 0.24, 0.0, 1.0)
    var smooth_t := t * t * (3.0 - 2.0 * t)
    for i in range(_transition_from.size()):
        var target := _skeleton.get_bone_pose(i)
        _skeleton.set_bone_pose(i, _transition_from[i].interpolate_with(target, smooth_t))
    if t >= 1.0:
        _transitioning = false
        _transition_from.clear()

func _lock_root_motion() -> void:
    if _skeleton == null or _hips_index < 0:
        return
    var hips := _skeleton.get_bone_pose(_hips_index)
    hips.origin.x = _neutral_hips_origin.x
    hips.origin.z = _neutral_hips_origin.z
    _skeleton.set_bone_pose(_hips_index, hips)
    if _model != null:
        var pos := _model.position
        pos.x = _neutral_model_position.x
        pos.z = _neutral_model_position.z
        _model.position = pos

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
    var left_sole := minf(_bone_world_y(_left_foot_index) - foot_offset,
        _bone_world_y(_left_toe_index) - toe_offset)
    var right_sole := minf(_bone_world_y(_right_foot_index) - foot_offset,
        _bone_world_y(_right_toe_index) - toe_offset)
    return minf(left_sole, right_sole)

func _align_neutral_feet_to_floor() -> void:
    var sole_y := _sole_floor_y()
    _actor.position.y += SOLE_CLEARANCE_WORLD - sole_y
    _base_actor_y = _actor.position.y

func _correct_foot_ground(delta: float) -> void:
    if _paused:
        return
    var sole_y := _sole_floor_y()
    var desired := _actor.position.y
    if sole_y < SOLE_CLEARANCE_WORLD:
        desired += SOLE_CLEARANCE_WORLD - sole_y
    else:
        desired = lerpf(desired, _base_actor_y, clampf(delta * 2.5, 0.0, 1.0))
    desired = clampf(desired, _base_actor_y, _base_actor_y + 0.16)
    _actor.position.y = lerpf(_actor.position.y, desired, clampf(delta * 14.0, 0.0, 1.0))

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

func _update_gameplay_movement(delta: float) -> void:
    if _actor == null or _skeleton == null or _paused:
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
        var local_dir := Vector3(input_vec.x, 0.0, input_vec.y).normalized()
        _travel_direction = (Basis(Vector3.UP, _camera_yaw) * local_dir).normalized()
        var target_yaw := atan2(-_travel_direction.x, -_travel_direction.z)
        _actor.rotation.y = lerp_angle(_actor.rotation.y, target_yaw, clampf(delta * TURN_RATE, 0.0, 1.0))
    if _move_speed > 0.04:
        _actor.position += _travel_direction * _move_speed * delta

    var desired_motion := "IDLE"
    if _move_speed > 0.12:
        desired_motion = "RUN" if wants_run and _move_speed > WALK_WORLD_SPEED * 0.85 else "WALK"
    _ensure_motion(desired_motion)

    if _animation != null and _motion == "WALK":
        _animation.speed_scale = clampf(_move_speed / WALK_WORLD_SPEED, 0.72, 1.05)
    elif _animation != null and _motion == "RUN":
        _animation.speed_scale = clampf(_move_speed / RUN_WORLD_SPEED, 0.82, 1.08)
    elif _animation != null:
        _animation.speed_scale = 1.0

func _process(delta: float) -> void:
    _update_gameplay_movement(delta)
    if not _paused and _skeleton != null:
        if _motion == "IDLE":
            _reset_idle_target()
            _apply_idle_offsets(delta)
        _apply_transition(delta)
        _lock_root_motion()
        _correct_foot_ground(delta)
    _update_camera(delta)
    _update_status()

func _update_camera(delta: float) -> void:
    if _actor == null or _camera == null:
        return
    var horizontal := cos(_camera_pitch) * _camera_distance
    var vertical := sin(_camera_pitch) * _camera_distance
    var target := _actor.global_position + Vector3(0.0, 1.03, 0.0)
    var goal := target + Vector3(sin(_camera_yaw) * horizontal, 0.55 + vertical, cos(_camera_yaw) * horizontal)
    _camera.global_position = goal if delta >= 1.0 else _camera.global_position.lerp(goal, clampf(delta * 8.5, 0.0, 1.0))
    _camera.look_at(target, Vector3.UP)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var view := get_viewport().get_visible_rect().size
        if event.pressed:
            if event.position.x < view.x * 0.43 and event.position.y > view.y * 0.42 and _move_touch < 0:
                _move_touch = event.index
                _update_joystick(event.position)
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
