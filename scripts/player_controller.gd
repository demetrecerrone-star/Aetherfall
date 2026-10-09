extends CharacterBody3D
## Offline movement test. This controller is intentionally decoupled from future
## online position reconciliation and server-authoritative state.

@export var walk_speed := 4.3
@export var sprint_speed := 7.8
@export var jump_velocity := 7.8
@export var acceleration := 20.0
@export var turn_rate := 12.0
@export var touch_sensitivity := 0.0050
@export var mouse_sensitivity := 0.0034

@onready var avatar: Variant = $Avatar
@onready var yaw_pivot: Node3D = $CameraYaw
@onready var pitch_pivot: Node3D = $CameraYaw/CameraPitch
@onready var camera_arm: SpringArm3D = $CameraYaw/CameraPitch/CameraArm

var hud: Variant
var _camera_touch := -1
var _right_mouse_dragging := false
var _jump_requested := false
var _camera_pitch := -0.22
var _studio_open := false
var _saved_yaw := 0.0
var _saved_pitch := -0.22
var _saved_distance := 4.7
var _saved_pivot_position := Vector3(0, 1.5, 0)

func _ready() -> void:
	_camera_pitch = pitch_pivot.rotation.x

func attach_hud(hud_node: CanvasLayer) -> void:
	hud = hud_node
	if hud.has_signal("jump_tapped"):
		hud.jump_tapped.connect(request_jump)
	if hud.has_signal("camera_reset_tapped"):
		hud.camera_reset_tapped.connect(reset_camera)

func adjust_camera_distance(delta_distance: float) -> void:
	camera_arm.spring_length = clampf(camera_arm.spring_length + delta_distance, 2.0, 7.5)

func set_studio_open(value: bool) -> void:
	if _studio_open == value:
		return
	_studio_open = value
	_jump_requested = false
	if value:
		_saved_yaw = yaw_pivot.rotation.y
		_saved_pitch = _camera_pitch
		_saved_distance = camera_arm.spring_length
		_saved_pivot_position = yaw_pivot.position
		# Rotate around to FACE the player. Offset the pivot so the character
		# stays in the LEFT half, unobstructed by the right-docked controls.
		yaw_pivot.rotation.y = avatar.rotation.y + PI
		yaw_pivot.position = Vector3(0, 1.42, 0) + yaw_pivot.basis.x * 0.58
		_camera_pitch = -0.09
		pitch_pivot.rotation.x = _camera_pitch
		camera_arm.spring_length = 3.35
	else:
		yaw_pivot.rotation.y = _saved_yaw
		yaw_pivot.position = _saved_pivot_position
		_camera_pitch = _saved_pitch
		pitch_pivot.rotation.x = _camera_pitch
		camera_arm.spring_length = _saved_distance

func request_jump() -> void:
	if not _studio_open:
		_jump_requested = true

func reset_camera() -> void:
	# Smoothly recenter horizontally behind the character.
	yaw_pivot.rotation.y = avatar.rotation.y
	_camera_pitch = -0.22
	pitch_pivot.rotation.x = _camera_pitch

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if hud != null and hud.has_method("get_move_vector"):
		var touch_axis: Vector2 = hud.get_move_vector()
		if touch_axis.length_squared() > 0.001:
			axis = touch_axis

	if _studio_open:
		axis = Vector2.ZERO

	var forward := yaw_pivot.global_basis.z
	var right := yaw_pivot.global_basis.x
	var direction := (right * axis.x + forward * axis.y)
	direction.y = 0.0
	direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint")
	if hud != null and hud.has_method("is_sprinting"):
		sprinting = sprinting or hud.is_sprinting()
	var speed := sprint_speed if sprinting else walk_speed
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.2
	else:
		velocity.y -= 22.0 * delta

	if not _studio_open and (Input.is_action_just_pressed("jump") or _jump_requested) and is_on_floor():
		velocity.y = jump_velocity
	_jump_requested = false
	move_and_slide()

	if direction.length_squared() > 0.02:
		var desired_yaw := atan2(-direction.x, -direction.z)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, desired_yaw, minf(1.0, delta * turn_rate))
	if avatar.has_method("set_motion_state"):
		avatar.set_motion_state(Vector2(velocity.x, velocity.z).length(), is_on_floor(), delta)
	if hud != null and hud.has_method("set_debug_state"):
		hud.set_debug_state(Vector2(velocity.x, velocity.z).length(), sprinting)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.44:
			if _camera_touch == -1:
				_camera_touch = event.index
		elif not event.pressed and event.index == _camera_touch:
			_camera_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == _camera_touch:
			_rotate_camera(event.relative, touch_sensitivity)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_right_mouse_dragging = event.pressed
	elif event is InputEventMouseMotion and _right_mouse_dragging:
		_rotate_camera(event.relative, mouse_sensitivity)
	if not _studio_open and event.is_action_pressed("camera_reset") and not event.is_echo():
		reset_camera()

func _rotate_camera(delta_pixels: Vector2, sensitivity: float) -> void:
	yaw_pivot.rotation.y -= delta_pixels.x * sensitivity
	_camera_pitch = clampf(_camera_pitch - delta_pixels.y * sensitivity, -0.85, 0.30)
	pitch_pivot.rotation.x = _camera_pitch
