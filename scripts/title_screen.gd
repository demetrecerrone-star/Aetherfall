extends Control
## Aetherfall's native, landscape-safe title screen. No external art or plugins required.
const LOADING_SCENE := "res://scenes/loading_screen.tscn"
const SETTINGS_PATH := "user://aetherfall_frontend.cfg"

var _seconds := 0.0
var _reduced_motion := false
var _master_volume := 0.85
var _modal: Control
var _prefs := ConfigFile.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_settings()
	_build_menu()
	queue_redraw()

func _process(delta: float) -> void:
	if not _reduced_motion:
		_seconds += delta
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var sky_top := Color("08162c")
	var sky_bottom := Color("315476")
	for i in range(26):
		var t := float(i) / 26.0
		draw_rect(Rect2(0, h * t, w, h / 26.0 + 2), sky_top.lerp(sky_bottom, t * 0.85))
	# Distant valley silhouettes, castle spires and a luminous aether gate.
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*.75),Vector2(w*.20,h*.40),Vector2(w*.34,h*.70),Vector2(w*.52,h*.45),Vector2(w*.70,h*.72),Vector2(w,h*.43),Vector2(w,h),Vector2(0,h)]), Color("233b59"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*.89),Vector2(w*.20,h*.68),Vector2(w*.34,h*.82),Vector2(w*.62,h*.66),Vector2(w*.82,h*.84),Vector2(w,h*.64),Vector2(w,h),Vector2(0,h)]), Color("11253f"))
	for i in range(48):
		var x := fposmod(float(i * 673 + 59), w)
		var y := fposmod(float(i * 293 + 31), h * .67)
		var twinkle := .5 if _reduced_motion else (.45 + .4 * sin(_seconds * 1.7 + float(i)))
		draw_circle(Vector2(x,y), 1.2 if i % 3 else 2.1, Color(0.81,0.92,1,twinkle))
	var center := Vector2(w * .765, h * .50)
	var r := minf(w,h) * .225
	for i in range(6, 0, -1):
		draw_circle(center, r * (1.1 + i * .14), Color(.11,.70,.92,.014))
	draw_circle(center, r*.91, Color(.23,.77,.94,.075))
	for ring in range(3):
		var a := _seconds * (.08 if ring % 2 == 0 else -.10)
		draw_arc(center, r * (.74 + ring * .14), a, a + TAU*.84, 90, Color(.46,.91,1,.48 - ring*.09), 2.5, true)
	for i in range(12):
		var theta := float(i)/12.0 * TAU + _seconds * .07
		var p1 := center + Vector2(cos(theta),sin(theta))*r*.72
		var p2 := center + Vector2(cos(theta),sin(theta))*r*.79
		draw_line(p1,p2,Color(.84,.92,.70,.75),2.0,true)
	# Foreground battlements anchor the composition.
	draw_rect(Rect2(w*.63,h*.83,w*.37,h*.17),Color("091525"))
	for i in range(8):
		draw_rect(Rect2(w*(.65+i*.048),h*.793,w*.025,h*.052),Color("091525"))
	draw_rect(Rect2(0,0,w*.49,h),Color(0.025,0.047,0.10,.45))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b172bdf")
	style.border_color = Color("baaa7e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(22)
	return style

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.set_content_margin_all(9)
	return style

func _label(message: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_shadow_color", Color("050916"))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _button(message: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = message
	btn.custom_minimum_size = Vector2(220, 51)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color("f6eedb"))
	btn.add_theme_stylebox_override("normal", _button_style(Color("182f49ee"), Color("688ca0")))
	btn.add_theme_stylebox_override("hover", _button_style(Color("315775"), Color("e0cb8f")))
	btn.add_theme_stylebox_override("pressed", _button_style(Color("46657c"), Color("f2dd9a")))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(handler)
	return btn

func _build_menu() -> void:
	var card := PanelContainer.new()
	card.anchor_left = .055
	card.anchor_right = .475
	card.anchor_top = .075
	card.anchor_bottom = .93
	card.add_theme_stylebox_override("panel", _panel_style())
	add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 11)
	card.add_child(stack)
	var kicker := _label("✦  A  N E W  W O R L D  A W A I T S", 13, Color("e8d49d"))
	stack.add_child(kicker)
	var heading := _label("AETHERFALL", 48, Color("f3e3bf"))
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(heading)
	stack.add_child(_label("Beyond the veil, your legend begins.", 17, Color("bad7e6")))
	var gap := Control.new()
	gap.custom_minimum_size.y = 13
	stack.add_child(gap)
	stack.add_child(_button("BEGIN ADVENTURE", func() -> void: _start("play")))
	stack.add_child(_button("CHARACTER STUDIO", func() -> void: _start("studio")))
	stack.add_child(_button("OPTIONS", func() -> void: _open_modal("options")))
	stack.add_child(_button("CREDITS", func() -> void: _open_modal("credits")))
	stack.add_child(_button("EXIT GAME", func() -> void: get_tree().quit()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	var edition := _label("PRE-ALPHA   •   OFFLINE STARTER TOWN", 13, Color("a9bfcc"))
	edition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(edition)

func _start(mode: String) -> void:
	get_tree().set_meta("aetherfall_open_studio", mode == "studio")
	var code := get_tree().change_scene_to_file(LOADING_SCENE)
	if code != OK:
		push_error("Aetherfall: unable to open loading scene (%d)" % code)

func _load_settings() -> void:
	_prefs.load(SETTINGS_PATH)
	_master_volume = clampf(float(_prefs.get_value("audio", "master", .85)), 0.0, 1.0)
	_reduced_motion = bool(_prefs.get_value("accessibility", "reduced_motion", false))
	_apply_volume(_master_volume)

func _apply_volume(level: float) -> void:
	var index := AudioServer.get_bus_index("Master")
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= .001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, .001)))

func _save_settings() -> void:
	_prefs.set_value("audio", "master", _master_volume)
	_prefs.set_value("accessibility", "reduced_motion", _reduced_motion)
	var error := _prefs.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Aetherfall: frontend preferences could not be saved")

func _open_modal(which: String) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var shade := ColorRect.new()
	shade.color = Color(0, .02, .06, .55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = .51
	panel.anchor_right = .955
	panel.anchor_top = .195
	panel.anchor_bottom = .825
	panel.add_theme_stylebox_override("panel", _panel_style())
	_modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	stack.add_child(_label("OPTIONS" if which == "options" else "CREDITS", 29, Color("f2dca8")))
	if which == "options":
		stack.add_child(_label("MASTER VOLUME", 16, Color("d6e7f0")))
		var volume := HSlider.new()
		volume.min_value = 0.0
		volume.max_value = 1.0
		volume.step = .05
		volume.value = _master_volume
		volume.custom_minimum_size.y = 44
		volume.value_changed.connect(func(value: float) -> void:
			_master_volume = value
			_apply_volume(value)
			_save_settings()
		)
		stack.add_child(volume)
		var motion := CheckBox.new()
		motion.text = "Reduce background animation"
		motion.button_pressed = _reduced_motion
		motion.add_theme_font_size_override("font_size", 16)
		motion.toggled.connect(func(value: bool) -> void:
			_reduced_motion = value
			_save_settings()
			queue_redraw()
		)
		stack.add_child(motion)
		stack.add_child(_label("Settings are saved on this device.", 14, Color("a9bfcc")))
	else:
		var lines := _label("AETHERFALL  •  AN ORIGINAL FANTASY RPG\nCreated for the Aetherfall project\n\nMade with Godot Engine\n\nPrototype build — more credits to come.", 17, Color("d8e7ea"))
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(lines)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	stack.add_child(_button("BACK", _close_modal))

func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(_modal):
		_close_modal()
		get_viewport().set_input_as_handled()
