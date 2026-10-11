extends Control
## Native scene loader with Godot's actual threaded ResourceLoader progress.
const WORLD_PATH := "res://scenes/main.tscn"
const TITLE_PATH := "res://scenes/title_screen.tscn"
const BACKDROP_SCRIPT = preload("res://scripts/title_backdrop.gd")

var _entered_ms := 0
var _veil: ColorRect
var _transitioning := false
var _loading_done := false
var _failed := false
var _status: Label
var _details: Label
var _bar: ProgressBar
var _buttons: HBoxContainer

func _ready() -> void:
	_entered_ms = Time.get_ticks_msec()
	_install_backdrop()
	_build_ui()
	_install_veil()
	AetherfallAmbience.play_menu()
	var fade := create_tween()
	fade.tween_property(_veil, "modulate:a", 0.0, .45)
	var request := ResourceLoader.load_threaded_request(WORLD_PATH, "PackedScene")
	if request != OK:
		_fail("Unable to start the world loader (error %d)." % request)

func _process(_delta: float) -> void:
	if _failed or _loading_done:
		return
	var progress: Array = []
	var state := ResourceLoader.load_threaded_get_status(WORLD_PATH, progress)
	if progress.size() > 0:
		_bar.value = clampf(float(progress[0]) * 100.0, 0.0, 99.0)
	match state:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_status.text = "PREPARING THE STARTER TOWN"
			_details.text = "Loading world resources...  %d%%" % int(_bar.value)
		ResourceLoader.THREAD_LOAD_LOADED:
			_loading_done = true
			_bar.value = 100.0
			_status.text = "YOUR ADVENTURE AWAITS"
			_details.text = "World resources are ready. Entering Aetherfall..."
			_enter_world.call_deferred()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("The starter town could not be loaded.")

func _install_backdrop() -> void:
	var vista := Control.new()
	vista.name = "LoadingLandscape"
	vista.set_script(BACKDROP_SCRIPT)
	vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vista.set("dimmed", true)
	add_child(vista)

func _install_veil() -> void:
	_veil = ColorRect.new()
	_veil.name = "LoadingTransitionVeil"
	_veil.color = Color("081321")
	_veil.modulate.a = 1.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1829ed")
	sb.border_color = Color("baaa7e")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(25)
	return sb

func _label(message: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",tint)
	return label

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = .19
	panel.anchor_right = .81
	panel.anchor_top = .305
	panel.anchor_bottom = .71
	panel.add_theme_stylebox_override("panel",_panel_style())
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",15)
	panel.add_child(stack)
	stack.add_child(_label("A E T H E R F A L L",34,Color("f2dfac")))
	_status = _label("PREPARING YOUR ADVENTURE",18,Color("d6e8ed"))
	stack.add_child(_status)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0,25)
	stack.add_child(_bar)
	_details = _label("Loading world resources...",14,Color("a9c8d7"))
	stack.add_child(_details)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation",18)
	_buttons.visible = false
	stack.add_child(_buttons)
	var retry := Button.new()
	retry.text = "RETRY"
	retry.custom_minimum_size = Vector2(115,47)
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	_buttons.add_child(retry)
	var back := Button.new()
	back.text = "TITLE SCREEN"
	back.custom_minimum_size = Vector2(180,47)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(TITLE_PATH))
	_buttons.add_child(back)

func _enter_world() -> void:
	if _transitioning or _failed:
		return
	_transitioning = true
	var resource := ResourceLoader.load_threaded_get(WORLD_PATH)
	var world := resource as PackedScene
	if world == null:
		_fail("The loaded world is not a scene.")
		return
	# Show real resource completion before fading. This is a visual minimum,
	# not a fabricated progress percentage or a claim about procedural meshes.
	var elapsed := float(Time.get_ticks_msec() - _entered_ms) / 1000.0
	if elapsed < .65:
		await get_tree().create_timer(.65-elapsed).timeout
	if not is_inside_tree():
		return
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	AetherfallAmbience.fade_out()
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(_veil, "modulate:a", 1.0, .45)
	await fade.finished
	if not is_inside_tree():
		return
	var code := get_tree().change_scene_to_packed(world)
	if code != OK:
		_fail("Unable to enter the starter town (error %d)." % code)

func _fail(message: String) -> void:
	_failed = true
	_transitioning = false
	if is_instance_valid(_veil):
		_veil.modulate.a = 0.0
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_done = true
	_status.text = "THE GATE COULD NOT OPEN"
	_details.text = message
	_buttons.visible = true
	push_error("Aetherfall loader: " + message)
