extends CanvasLayer
## In-world character creation panel for v0.2; touch and mouse compatible.
## Appearance is saved automatically on every change in the avatar script.

const FIELDS := [
	["frame", "BODY FRAME"],
	["skin", "SKIN TONE"],
	["hair_style", "HAIRSTYLE"],
	["hair", "HAIR COLOR"],
	["eyes", "EYE COLOR"],
	["outfit_style", "OUTFIT TYPE"],
	["outfit", "OUTFIT COLOR"]
]
const FIELD_COUNTS := {"frame": 2, "skin": 6, "hair_style": 4, "hair": 6, "eyes": 5, "outfit_style": 3, "outfit": 6}
var avatar: Node3D
var player: CharacterBody3D
var _panel: PanelContainer
var _description: Label
var _choice_buttons: Dictionary = {}
var _start_button: Button

func attach(avatar_node: Node3D, player_node: CharacterBody3D) -> void:
	avatar = avatar_node
	player = player_node
	if avatar.has_signal("appearance_changed"):
		avatar.appearance_changed.connect(_on_changed)
	if _description != null:
		_update_labels()

func _style(base: String, edge: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(base)
	style.border_color = Color(edge)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.set_content_margin_all(9)
	return style

func _btn(label: String, w: float, h: float, font_size: int = 18) -> Button:
	var node := Button.new()
	node.text = label
	node.custom_minimum_size = Vector2(w, h)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_stylebox_override("normal", _style("172b49ed", "739dbd"))
	node.add_theme_stylebox_override("pressed", _style("44658dee", "e6c781"))
	node.add_theme_stylebox_override("hover", _style("27446bdd", "9bdcf2"))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	node.add_theme_color_override("font_color", Color("f3f1df"))
	return node

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_value
	lbl.add_theme_font_size_override("font_size", size_value)
	lbl.add_theme_color_override("font_color", color_value)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _ready() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	_start_button = _btn("✦ LOOKS", 130, 50)
	_start_button.anchor_left = 0.82
	_start_button.anchor_right = 0.82
	_start_button.anchor_top = 0.065
	_start_button.anchor_bottom = 0.065
	_start_button.offset_right = 130
	_start_button.offset_bottom = 50
	_start_button.pressed.connect(_toggle)
	canvas.add_child(_start_button)

	_panel = PanelContainer.new()
	_panel.name = "CharacterCreator"
	_panel.anchor_left = 0.32
	_panel.anchor_right = 0.79
	_panel.anchor_top = 0.075
	_panel.anchor_bottom = 0.94
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	_panel.add_theme_stylebox_override("panel", _style("101c35f6", "cbb783"))
	_panel.visible = false
	canvas.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	_panel.add_child(stack)
	stack.add_child(_label("AETHERFALL   /   CHARACTER STUDIO", 20, Color("f6d795")))
	_description = _label("Preparing appearance...", 15, Color("bfe1f2"))
	stack.add_child(_description)
	stack.add_child(_label("Changes save automatically on this device.", 13, Color("b4b6bd")))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(grid)
	for field in FIELDS:
		var key: String = field[0]
		var caption: String = field[1]
		grid.add_child(_label(caption, 15, Color("e2d9c5")))
		var change_button := _btn("CHANGE", 184, 39, 15)
		change_button.pressed.connect(_cycle.bind(key))
		grid.add_child(change_button)
		_choice_buttons[key] = change_button

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	stack.add_child(actions)
	var wave := _btn("WAVE 👋", 130, 48, 16)
	wave.pressed.connect(_wave)
	actions.add_child(wave)
	var zoom_near := _btn("ZOOM +", 100, 48, 15)
	zoom_near.pressed.connect(func() -> void: _zoom(-0.6))
	actions.add_child(zoom_near)
	var zoom_far := _btn("ZOOM −", 100, 48, 15)
	zoom_far.pressed.connect(func() -> void: _zoom(0.6))
	actions.add_child(zoom_far)
	var closer := _btn("DONE", 105, 48, 16)
	closer.pressed.connect(_toggle)
	actions.add_child(closer)

	var hint := _label("Move with the left stick • Swipe right half to orbit the camera", 12, Color("c1d5e2"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	_update_labels()

func _toggle() -> void:
	_panel.visible = not _panel.visible
	_start_button.text = "CLOSE LOOKS" if _panel.visible else "✦ LOOKS"
	_update_labels()

func _cycle(key: String) -> void:
	if avatar != null and avatar.has_method("cycle_option"):
		avatar.cycle_option(key)
	_update_labels()

func _on_changed(_summary: String) -> void:
	_update_labels()

func _update_labels() -> void:
	if avatar == null or _description == null:
		return
	if avatar.has_method("appearance_description"):
		_description.text = avatar.appearance_description()
	for key in _choice_buttons.keys():
		var number: int = int(avatar.appearance.get(key, 0)) + 1
		_choice_buttons[key].text = "%d / %d    ↻" % [number, int(FIELD_COUNTS[key])]

func _wave() -> void:
	if avatar != null and avatar.has_method("wave"):
		avatar.wave()
	_panel.visible = false
	_start_button.text = "✦ LOOKS"

func _zoom(change: float) -> void:
	if player != null and player.has_method("adjust_camera_distance"):
		player.adjust_camera_distance(change)
