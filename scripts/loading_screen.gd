extends Control
## Native scene loader with Godot's actual threaded ResourceLoader progress.
const WORLD_PATH := "res://scenes/main.tscn"
const TITLE_PATH := "res://scenes/title_screen.tscn"

var _elapsed := 0.0
var _loading_done := false
var _failed := false
var _status: Label
var _details: Label
var _bar: ProgressBar
var _buttons: HBoxContainer

func _ready() -> void:
	_build_ui()
	var request := ResourceLoader.load_threaded_request(WORLD_PATH, "PackedScene")
	if request != OK:
		_fail("Unable to start the world loader (error %d)." % request)

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
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

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1 or h <= 1:
		return
	draw_rect(Rect2(Vector2.ZERO,size),Color("071426"))
	for i in range(20):
		var t := float(i) / 20.0
		draw_rect(Rect2(0,h*t,w,h/20.0+1),Color("0b223c").lerp(Color("254c67"),t*.7))
	var point := Vector2(w*.50,h*.47)
	for i in range(5,0,-1):
		draw_circle(point,float(i)*h*.085,Color(.2,.66,.88,.02))
	for i in range(3):
		var radius := h*(.22 + float(i)*.037)
		draw_arc(point,radius,_elapsed*.1+i,_elapsed*.1+i+TAU*.79,100,Color(.54,.88,.95,.36),2.0,true)
	for i in range(28):
		var x := fposmod(float(i*877+21),w)
		var y := fposmod(float(i*239+41),h*.78)
		draw_circle(Vector2(x,y),1.3,Color(.8,.94,1,.24+.2*sin(_elapsed+i)))

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
	var resource := ResourceLoader.load_threaded_get(WORLD_PATH)
	var world := resource as PackedScene
	if world == null:
		_fail("The loaded world is not a scene.")
		return
	# Leave one rendered frame for the actual 100% state before swapping scenes.
	await get_tree().process_frame
	var code := get_tree().change_scene_to_packed(world)
	if code != OK:
		_fail("Unable to enter the starter town (error %d)." % code)

func _fail(message: String) -> void:
	_failed = true
	_loading_done = true
	_status.text = "THE GATE COULD NOT OPEN"
	_details.text = message
	_buttons.visible = true
	push_error("Aetherfall loader: " + message)
