extends Node3D
## v0.3: imported, originally authored glTF 2.0 skinned humanoid.
## Real Skeleton3D skinning, authored animation tracks and distinct material meshes.
## No spheres/cylinders/boxes created by this script.
signal appearance_changed(summary: String)

const MODEL: PackedScene = preload("res://assets/characters/aetherfall_adventurer.gltf")
const SAVE_PATH := "user://aetherfall_appearance_v02.json"
const SKIN_COLORS := ["f1c6ad", "dba687", "b78269", "95644e", "65483b", "f5d9c8"]
const HAIR_COLORS := ["202338", "6e4b40", "d6a568", "a7b7ce", "ab627a", "e2ded0"]
const EYE_COLORS := ["3c93b3", "5b6e4b", "9c6b3d", "8270b5", "4e4e5c"]
const OUTFIT_COLORS := ["33486a", "704b66", "36645e", "9d6650", "54516f", "82794e"]
const STYLE_NAMES := ["Adventurer", "Spellweaver", "Vanguard"]
const HAIR_NAMES := ["Windswept", "Long", "Short", "Ponytail"]

var appearance: Dictionary = {
	"frame": 0, "skin": 0, "hair": 0, "hair_style": 0,
	"eyes": 0, "outfit": 0, "outfit_style": 0
}
var _model: Node3D
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _current_state := ""
var _wave_remaining := 0.0

func _ready() -> void:
	_load_profile()
	_model = MODEL.instantiate()
	_model.name = "AdventurerModel"
	add_child(_model)
	_collect_nodes(_model)
	_apply_appearance()
	_start_animation("Idle")

func _collect_nodes(root_node: Node) -> void:
	if root_node is Skeleton3D:
		_skeleton = root_node
	elif root_node is AnimationPlayer:
		_animation_player = root_node
	elif root_node is MeshInstance3D:
		_meshes.append(root_node)
	for child in root_node.get_children():
		_collect_nodes(child)

func _tint(hex_color: String, source: Material = null) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	if source is StandardMaterial3D:
		result = source.duplicate() as StandardMaterial3D
	result.albedo_color = Color(hex_color)
	result.roughness = 0.83
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _apply_appearance() -> void:
	var chosen_hair: String = HAIR_NAMES[int(appearance["hair_style"])]
	var chosen_style: String = STYLE_NAMES[int(appearance["outfit_style"])]
	for item in _meshes:
		var name_value := item.name
		# Imported node names keep their authored prefix; names may receive
		# a numeric suffix if a Godot importer resolves duplicates.
		if name_value.begins_with("Hair_"):
			item.visible = name_value.begins_with("Hair_" + chosen_hair)
		elif name_value.begins_with("Outfit_"):
			item.visible = name_value.begins_with("Outfit_" + chosen_style)
		else:
			item.visible = true
		if name_value.begins_with("Hair_"):
			var hair_hex: String = HAIR_COLORS[int(appearance["hair"])]
			if name_value.contains("Shine") or name_value.contains("Sweep"):
				hair_hex = Color(hair_hex).lightened(0.19).to_html(false)
			item.material_override = _tint(hair_hex)
		elif name_value.begins_with("Skin_"):
			item.material_override = _tint(SKIN_COLORS[int(appearance["skin"])])
		elif name_value.begins_with("Eyes_LeftIris") or name_value.begins_with("Eyes_RightIris"):
			item.material_override = _tint(EYE_COLORS[int(appearance["eyes"])])
		elif name_value.begins_with("Body_Torso") or name_value.begins_with("Body_HipCloth") or name_value.contains("Sleeve") or name_value.contains("Forearm") or name_value.begins_with("Outfit_Spellweaver"):
			item.material_override = _tint(OUTFIT_COLORS[int(appearance["outfit"])])
		else:
			item.material_override = null
	_model.scale.x = 1.065 if int(appearance["frame"]) == 0 else 0.945

func get_skeleton() -> Skeleton3D:
	return _skeleton

func get_model_stats() -> Dictionary:
	var animation_count := 0
	var bone_count := 0
	if _animation_player != null:
		animation_count = _animation_player.get_animation_list().size()
	if _skeleton != null:
		bone_count = _skeleton.get_bone_count()
	return {"model_meshes": _meshes.size(), "bones": bone_count,
		"animation_clips": animation_count, "skinned_model": _skeleton != null}

func set_motion_state(horizontal_speed: float, grounded: bool, delta: float) -> void:
	# Match gait playback to the actual horizontal velocity; avoid foot sliding.
	if _animation_player != null and _wave_remaining <= 0.0:
		if grounded and horizontal_speed > 5.05:
			_animation_player.speed_scale = clampf(horizontal_speed / 7.8, 0.88, 1.32)
		elif grounded and horizontal_speed > 0.12:
			_animation_player.speed_scale = clampf(horizontal_speed / 4.3, 0.72, 1.25)
		else:
			_animation_player.speed_scale = 1.0
	if _wave_remaining > 0.0:
		_wave_remaining -= delta
		_start_animation("Wave")
	elif not grounded:
		_start_animation("Jump")
	elif horizontal_speed > 5.05:
		_start_animation("Run")
	elif horizontal_speed > 0.12:
		_start_animation("Walk")
	else:
		_start_animation("Idle")

func _start_animation(name_value: String) -> void:
	if _current_state == name_value or _animation_player == null:
		return
	var full_name := name_value
	if not _animation_player.has_animation(full_name):
		for clip in _animation_player.get_animation_list():
			if str(clip).ends_with(name_value):
				full_name = str(clip)
				break
	if not _animation_player.has_animation(full_name):
		push_warning("Missing animation: %s" % name_value)
		return
	_current_state = name_value
	var animation := _animation_player.get_animation(full_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if name_value in ["Idle", "Walk", "Run"] else Animation.LOOP_NONE
	_animation_player.play(full_name, 0.18)

func wave() -> void:
	_wave_remaining = 2.0
	_current_state = ""
	_start_animation("Wave")

func get_animation_state() -> String:
	return _current_state

func appearance_description() -> String:
	return "%s / %s / %s" % [
		"Broad" if int(appearance["frame"]) == 0 else "Slender",
		HAIR_NAMES[int(appearance["hair_style"])],
		STYLE_NAMES[int(appearance["outfit_style"])]
	]

func cycle_option(key: String, direction: int = 1) -> void:
	var limits := {
		"frame": 2, "skin": SKIN_COLORS.size(),
		"hair": HAIR_COLORS.size(), "hair_style": HAIR_NAMES.size(),
		"eyes": EYE_COLORS.size(), "outfit": OUTFIT_COLORS.size(),
		"outfit_style": STYLE_NAMES.size()
	}
	if not limits.has(key):
		return
	appearance[key] = posmod(int(appearance[key]) + direction, int(limits[key]))
	_apply_appearance()
	_save_profile()
	appearance_changed.emit(appearance_description())

func cycle_hair() -> void:
	cycle_option("hair")

func cycle_outfit() -> void:
	cycle_option("outfit")

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var limits := {
		"frame": 2, "skin": SKIN_COLORS.size(), "hair": HAIR_COLORS.size(),
		"hair_style": HAIR_NAMES.size(), "eyes": EYE_COLORS.size(),
		"outfit": OUTFIT_COLORS.size(), "outfit_style": STYLE_NAMES.size()
	}
	for key in limits:
		if data.has(key) and (typeof(data[key]) == TYPE_INT or typeof(data[key]) == TYPE_FLOAT):
			appearance[key] = clampi(int(data[key]), 0, int(limits[key]) - 1)

func _save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(appearance, "\t"))
		file.close()
