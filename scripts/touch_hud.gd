extends CanvasLayer
## Native Godot touch controls: no static 2D background, adaptable to 16:9 screens.

signal jump_tapped
signal camera_reset_tapped
signal hair_tapped
signal outfit_tapped

const JOYSTICK_SCRIPT = preload("res://scripts/virtual_joystick.gd")
var _joystick: Variant
var _run := false
var _run_button: Button
var _status_label: Label
var _last_status := ""
var _root_overlay: Control

func _style(base: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.content_margin_left = 11
	s.content_margin_right = 11
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _make_label(text_value: String, font_size: int, color_value: Color) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color_value)
	node.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.12, 0.75))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _make_button(text_value: String, width: float, height: float) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(width, height)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", Color("effbff"))
	btn.add_theme_stylebox_override("normal", _style(Color("132b51da"), Color("75bce8")))
	btn.add_theme_stylebox_override("hover", _style(Color("285c84ec"), Color("c0efff")))
	btn.add_theme_stylebox_override("pressed", _style(Color("235e7bf5"), Color("e9d294")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _ready() -> void:
	var root := Control.new()
	root.name = "Overlay"
	_root_overlay = root
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var header := PanelContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", _style(Color("0a1d38e4"), Color("3a83a8")))
	header.anchor_left = 0.015
	header.anchor_right = 0.355
	header.anchor_top = 0.02
	header.anchor_bottom = 0.02
	header.offset_bottom = 80
	root.add_child(header)
	var header_stack := VBoxContainer.new()
	header_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_stack)
	header_stack.add_child(_make_label("AETHERFALL  /  AVATAR 3D", 20, Color("d9c188")))
	header_stack.add_child(_make_label("Original rigged character  •  v0.3.0", 13, Color("acc6d9")))

	_status_label = _make_label("MOVE  0.0 m/s", 15, Color("d5f4ff"))
	_status_label.anchor_left = 0.015
	_status_label.anchor_right = 0.34
	_status_label.anchor_top = 0.145
	_status_label.anchor_bottom = 0.145
	_status_label.offset_bottom = 40
	root.add_child(_status_label)
	_status_label.visible = not OS.has_feature("mobile") and not OS.has_feature("android")

	var tip := _make_label("LEFT STICK  MOVE   •   RIGHT SWIPE  CAMERA", 13, Color("e5f1f8"))
	tip.anchor_left = 0.44
	tip.anchor_right = 0.97
	tip.anchor_top = 0.025
	tip.offset_bottom = 28
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(tip)
	tip.visible = not OS.has_feature("mobile") and not OS.has_feature("android")

	_joystick = Control.new()
	_joystick.name = "VirtualJoystick"
	_joystick.set_script(JOYSTICK_SCRIPT)
	_joystick.anchor_left = 0.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 21
	_joystick.offset_right = 246
	_joystick.offset_top = -247
	_joystick.offset_bottom = -22
	root.add_child(_joystick)

	var button_grid := GridContainer.new()
	button_grid.name = "ActionButtons"
	button_grid.columns = 2
	button_grid.add_theme_constant_override("h_separation", 12)
	button_grid.add_theme_constant_override("v_separation", 10)
	button_grid.anchor_left = 1.0
	button_grid.anchor_right = 1.0
	button_grid.anchor_top = 1.0
	button_grid.anchor_bottom = 1.0
	button_grid.offset_left = -276
	button_grid.offset_right = -22
	button_grid.offset_top = -199
	button_grid.offset_bottom = -16
	root.add_child(button_grid)

	var jump := _make_button("JUMP", 116, 74)
	jump.pressed.connect(func() -> void: jump_tapped.emit())
	button_grid.add_child(jump)
	_run_button = _make_button("RUN OFF", 116, 74)
	_run_button.pressed.connect(_on_run_pressed)
	button_grid.add_child(_run_button)
	var camera := _make_button("CENTER", 116, 70)
	camera.pressed.connect(func() -> void: camera_reset_tapped.emit())
	button_grid.add_child(camera)
	var hair := _make_button("HAIR", 116, 70)
	hair.pressed.connect(func() -> void: hair_tapped.emit())
	button_grid.add_child(hair)

	var outfit := _make_button("OUTFIT", 110, 46)
	outfit.anchor_left = 0.85
	outfit.anchor_right = 0.85
	outfit.anchor_top = 0.17
	outfit.offset_left = 0
	outfit.offset_right = 110
	outfit.offset_bottom = 46
	outfit.pressed.connect(func() -> void: outfit_tapped.emit())
	root.add_child(outfit)

	var desktop_help := _make_label("PC: WASD / arrows  ·  Right-drag camera  ·  Shift sprint  ·  Space jump  ·  R recenter", 13, Color("dbe0ef"))
	desktop_help.anchor_left = 0.30
	desktop_help.anchor_right = 0.80
	desktop_help.anchor_top = 1.0
	desktop_help.anchor_bottom = 1.0
	desktop_help.offset_top = -42
	desktop_help.offset_bottom = -10
	desktop_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(desktop_help)
	desktop_help.visible = not OS.has_feature("mobile") and not OS.has_feature("android")

func _on_run_pressed() -> void:
	_run = not _run
	_run_button.text = "RUN ON" if _run else "RUN OFF"

func is_sprinting() -> bool:
	return _run

func get_move_vector() -> Vector2:
	return _joystick.value if _joystick != null else Vector2.ZERO

func set_debug_state(speed: float, sprinting: bool) -> void:
	var state := "MOVE  %0.1f m/s    |    %s" % [speed, "RUN" if sprinting else "WALK"]
	if state != _last_status and _status_label != null:
		_last_status = state
		_status_label.text = state

func set_character_studio_active(enabled: bool) -> void:
	if _root_overlay != null:
		_root_overlay.visible = not enabled
