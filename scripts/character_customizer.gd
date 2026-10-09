extends CanvasLayer
## Aetherfall v0.2.2: unobstructed, right-docked character studio.
## The real-time 3D player remains visible on the left while edits persist.

const FIELDS := [
	["frame", "BUILD"],
	["skin", "SKIN"],
	["hair_style", "HAIRSTYLE"],
	["hair", "HAIR COLOR"],
	["eyes", "EYE COLOR"],
	["outfit_style", "OUTFIT"],
	["outfit", "FABRIC"]
]
const VALUES := {
	"frame": ["Broad", "Slender"],
	"skin": ["Light warm", "Honey", "Tan", "Bronze", "Deep brown", "Fair"],
	"hair_style": ["Windswept", "Long", "Short", "Ponytail"],
	"hair": ["Midnight", "Chestnut", "Blonde", "Silver", "Rose", "White"],
	"eyes": ["Azure", "Emerald", "Amber", "Violet", "Slate"],
	"outfit_style": ["Adventurer", "Spellweaver", "Vanguard"],
	"outfit": ["Navy", "Plum", "Jade", "Copper", "Indigo", "Olive"]
}
const COLOR_PALETTES := {
	"skin": ["f1c6ad", "dba687", "b78269", "95644e", "65483b", "f5d9c8"],
	"hair": ["202338", "6e4b40", "d6a568", "a7b7ce", "ab627a", "e2ded0"],
	"eyes": ["3c93b3", "5b6e4b", "9c6b3d", "8270b5", "4e4e5c"],
	"outfit": ["33486a", "704b66", "36645e", "9d6650", "54516f", "82794e"]
}

var avatar: Node3D
var player: CharacterBody3D
var _panel: PanelContainer
var _entry_labels: Dictionary = {}
var _swatches: Dictionary = {}
var _toggle_button: Button
var _description: Label
var _open := false

func attach(avatar_node: Node3D, player_node: CharacterBody3D) -> void:
	avatar = avatar_node
	player = player_node
	if avatar.has_signal("appearance_changed"):
		avatar.appearance_changed.connect(_on_changed)
	_refresh_values()

func _box_style(bg: String, line_color: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg)
	style.border_color = Color(line_color)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	return style

func _button(title: String, min_width: float, min_height: float, font_size: int = 16) -> Button:
	var item := Button.new()
	item.text = title
	item.custom_minimum_size = Vector2(min_width, min_height)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", Color("f4f4ea"))
	item.add_theme_stylebox_override("normal", _box_style("193353ee", "6dabc4"))
	item.add_theme_stylebox_override("hover", _box_style("265678f2", "c1edfa"))
	item.add_theme_stylebox_override("pressed", _box_style("397291f2", "f3d58c"))
	item.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return item

func _label(text_value: String, size_value: int, color_value: Color) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color_value)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _ready() -> void:
	var root := Control.new()
	root.name = "StudioOverlay"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_toggle_button = _button("✦ LOOKS", 130, 48)
	_toggle_button.anchor_left = 0.825
	_toggle_button.anchor_right = 0.825
	_toggle_button.anchor_top = 0.068
	_toggle_button.anchor_bottom = 0.068
	_toggle_button.offset_right = 130
	_toggle_button.offset_bottom = 48
	_toggle_button.pressed.connect(_toggle)
	root.add_child(_toggle_button)

	_panel = PanelContainer.new()
	_panel.name = "RightDockedCreator"
	_panel.anchor_left = 0.615
	_panel.anchor_right = 0.98
	_panel.anchor_top = 0.07
	_panel.anchor_bottom = 0.975
	_panel.add_theme_stylebox_override("panel", _box_style("101d32f2", "b6a777"))
	_panel.visible = false
	root.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_panel.add_child(stack)

	var banner := HBoxContainer.new()
	banner.add_theme_constant_override("separation", 8)
	stack.add_child(banner)
	banner.add_child(_label("CHARACTER STUDIO", 23, Color("f4d695")))
	var close := _button("✕", 43, 39, 21)
	close.pressed.connect(_toggle)
	banner.add_spacer(false)
	banner.add_child(close)

	_description = _label("Choose your adventurer's appearance", 14, Color("b9d8e9"))
	stack.add_child(_description)
	stack.add_child(_label("LIVE PREVIEW  •  CHANGES SAVE AUTOMATICALLY", 12, Color("b2bcbf")))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 9)
	stack.add_child(grid)

	for item in FIELDS:
		var key: String = item[0]
		var caption: String = item[1]
		grid.add_child(_label(caption, 14, Color("e1dbc7")))
		var previous := _button("‹", 38, 40, 22)
		previous.pressed.connect(_cycle.bind(key, -1))
		grid.add_child(previous)

		var value_container := HBoxContainer.new()
		value_container.custom_minimum_size = Vector2(154, 40)
		value_container.add_theme_constant_override("separation", 5)
		grid.add_child(value_container)
		if COLOR_PALETTES.has(key):
			var chip := ColorRect.new()
			chip.custom_minimum_size = Vector2(17, 17)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			value_container.add_child(chip)
			_swatches[key] = chip
		var value := _label("", 14, Color("f1f4f1"))
		value_container.add_child(value)
		_entry_labels[key] = value

		var next := _button("›", 38, 40, 22)
		next.pressed.connect(_cycle.bind(key, 1))
		grid.add_child(next)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	stack.add_child(actions)
	var wave := _button("WAVE", 87, 43, 15)
	wave.pressed.connect(_wave)
	actions.add_child(wave)
	var zoom_in := _button("ZOOM +", 99, 43, 14)
	zoom_in.pressed.connect(_zoom.bind(-0.5))
	actions.add_child(zoom_in)
	var zoom_out := _button("ZOOM −", 99, 43, 14)
	zoom_out.pressed.connect(_zoom.bind(0.5))
	actions.add_child(zoom_out)
	var done := _button("DONE", 82, 43, 15)
	done.pressed.connect(_toggle)
	actions.add_child(done)

	var hint := _label("Your adventurer is shown on the left. Tap the arrows to preview options.", 12, Color("bbd3df"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)
	_refresh_values()

func _toggle() -> void:
	_set_open(not _open)

func _set_open(value: bool) -> void:
	_open = value
	_panel.visible = _open
	_toggle_button.visible = not _open
	if player != null and player.has_method("set_studio_open"):
		player.set_studio_open(_open)
	var hud := get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("set_character_studio_active"):
		hud.set_character_studio_active(_open)
	_refresh_values()

func _cycle(key: String, amount: int) -> void:
	if avatar != null and avatar.has_method("cycle_option"):
		avatar.cycle_option(key, amount)
	_refresh_values()

func _on_changed(_summary: String) -> void:
	_refresh_values()

func _refresh_values() -> void:
	if avatar == null or _description == null:
		return
	if avatar.has_method("appearance_description"):
		_description.text = avatar.appearance_description()
	var chosen: Dictionary = avatar.get("appearance")
	for key in _entry_labels.keys():
		var options: Array = VALUES.get(key, [])
		var idx := clampi(int(chosen.get(key, 0)), 0, options.size() - 1)
		var label: Label = _entry_labels[key]
		label.text = str(options[idx])
		if _swatches.has(key):
			var swatch: ColorRect = _swatches[key]
			var palette: Array = COLOR_PALETTES.get(key, [])
			swatch.color = Color(str(palette[idx]))

func _wave() -> void:
	if avatar != null and avatar.has_method("wave"):
		avatar.wave()

func _zoom(change: float) -> void:
	if player != null and player.has_method("adjust_camera_distance"):
		player.adjust_camera_distance(change)
