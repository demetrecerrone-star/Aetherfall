extends Node3D
## Aetherfall v0.2: articulated Skeleton3D avatar with editable appearance.
## This is original procedural prototype art, not a finished artist-sculpted model.
## BoneAttachment3D allows all wearable pieces to follow animated bones.
signal appearance_changed(summary: String)

const SAVE_PATH := "user://aetherfall_appearance_v02.json"
const SKIN_COLORS := ["f1c6ad", "dba687", "b78269", "95644e", "65483b", "f5d9c8"]
const HAIR_COLORS := ["202338", "6e4b40", "d6a568", "a7b7ce", "ab627a", "e2ded0"]
const EYE_COLORS := ["3c93b3", "5b6e4b", "9c6b3d", "8270b5", "4e4e5c"]
const OUTFIT_COLORS := ["33486a", "704b66", "36645e", "9d6650", "54516f", "82794e"]
const STYLE_NAMES := ["Adventurer", "Spellweaver", "Vanguard"]
const HAIR_NAMES := ["Windswept", "Long", "Short", "High Ponytail"]

var appearance: Dictionary = {
	"frame": 0,
	"skin": 0,
	"hair": 0,
	"hair_style": 0,
	"eyes": 0,
	"outfit": 0,
	"outfit_style": 0
}
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _clock := 0.0
var _stride_clock := 0.0
var _blend := 0.0
var _wave_time := 0.0
var _pose_angles: Dictionary = {}
var _state := "IDLE"

func _ready() -> void:
	_load_profile()
	_build_avatar()

func _material(hex: String, metallic: float = 0.0, roughness: float = 0.67) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _add_bone(name: String, parent: String, offset: Vector3) -> void:
	var index := _skeleton.add_bone(name)
	_bones[name] = index
	if parent != "":
		_skeleton.set_bone_parent(index, int(_bones[parent]))
	_skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, offset))

func _part(bone_name: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = bone_name + "Attachment%02d" % _skeleton.get_child_count()
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	return attachment

func _orb(parent: Node3D, label: String, pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var primitive := SphereMesh.new()
	primitive.radius = 0.5
	primitive.height = 1.0
	primitive.radial_segments = 18
	primitive.rings = 10
	node.mesh = primitive
	node.material_override = material
	node.position = pos
	node.scale = scale_value
	parent.add_child(node)
	return node

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var primitive := BoxMesh.new()
	primitive.size = size
	node.mesh = primitive
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func _cone(parent: Node3D, label: String, pos: Vector3, height: float, width_top: float, width_bottom: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var primitive := CylinderMesh.new()
	primitive.height = height
	primitive.top_radius = width_top
	primitive.bottom_radius = width_bottom
	primitive.radial_segments = 12
	node.mesh = primitive
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func _build_avatar() -> void:
	if is_instance_valid(_skeleton):
		remove_child(_skeleton)
		_skeleton.queue_free()
	_bones.clear()
	_pose_angles.clear()
	_skeleton = Skeleton3D.new()
	_skeleton.name = "HumanoidSkeleton"
	add_child(_skeleton)
	# Parent-relative rest offsets, in meters, establish a reusable humanoid rig.
	_add_bone("Hips", "", Vector3(0, 0.88, 0))
	_add_bone("Spine", "Hips", Vector3(0, 0.25, 0))
	_add_bone("Chest", "Spine", Vector3(0, 0.30, 0))
	_add_bone("Neck", "Chest", Vector3(0, 0.29, 0))
	_add_bone("Head", "Neck", Vector3(0, 0.19, 0))
	_add_bone("LeftUpperArm", "Chest", Vector3(-0.38, 0.13, 0))
	_add_bone("LeftForearm", "LeftUpperArm", Vector3(-0.015, -0.35, 0))
	_add_bone("RightUpperArm", "Chest", Vector3(0.38, 0.13, 0))
	_add_bone("RightForearm", "RightUpperArm", Vector3(0.015, -0.35, 0))
	_add_bone("LeftThigh", "Hips", Vector3(-0.16, -0.055, 0))
	_add_bone("LeftShin", "LeftThigh", Vector3(0, -0.43, 0))
	_add_bone("RightThigh", "Hips", Vector3(0.16, -0.055, 0))
	_add_bone("RightShin", "RightThigh", Vector3(0, -0.43, 0))

	# CRITICAL: Skeleton3D's initial pose does not automatically inherit the
	# rest translations assigned to bones created at runtime. Without resetting
	# pose to rest, every BoneAttachment3D piles up at (0,0,0). This produced
	# the tiny pile of heads/limbs visible in the v0.2 phone screenshot.
	_skeleton.reset_bone_poses()

	var body_frame := int(appearance["frame"])
	var broad := body_frame == 0
	var shoulders := 1.06 if broad else 0.91
	var hips := 0.93 if broad else 1.09
	var skin := _material(SKIN_COLORS[int(appearance["skin"])])
	var skin_shadow := _material(Color(SKIN_COLORS[int(appearance["skin"])]).darkened(0.18).to_html(false))
	var hair := _material(HAIR_COLORS[int(appearance["hair"])], 0.02, 0.52)
	var eyes := _material(EYE_COLORS[int(appearance["eyes"])], 0.10, 0.28)
	var white := _material("fff8f1")
	var ink := _material("191c32")
	var fabric := _material(OUTFIT_COLORS[int(appearance["outfit"])])
	var dark := _material("26263b")
	var trim := _material("dfc38c", 0.25, 0.42)
	var pants := _material("323346")
	var armor := _material("91a1aa", 0.38, 0.42)

	var hip_attach := _part("Hips")
	_orb(hip_attach, "HipsCloth", Vector3(0, -0.025, 0), Vector3(0.59 * hips, 0.35, 0.43), fabric)
	_box(hip_attach, "Belt", Vector3(0, 0.05, -0.207), Vector3(0.61 * hips, 0.10, 0.08), dark)
	_box(hip_attach, "Buckle", Vector3(0, 0.05, -0.25), Vector3(0.13, 0.09, 0.05), trim)

	var spine_attach := _part("Spine")
	_orb(spine_attach, "Waist", Vector3(0, 0.065, 0), Vector3(0.56 * hips, 0.54, 0.43), fabric)
	var chest_attach := _part("Chest")
	_orb(chest_attach, "ChestCoat", Vector3(0, -0.015, 0), Vector3(0.76 * shoulders, 0.59, 0.49), fabric)
	_box(chest_attach, "CoatCentralSeam", Vector3(0, -0.08, -0.242), Vector3(0.038, 0.39, 0.024), trim)
	_orb(chest_attach, "CollarLeft", Vector3(-0.10, 0.24, -0.14), Vector3(0.19, 0.20, 0.22), dark)
	_orb(chest_attach, "CollarRight", Vector3(0.10, 0.24, -0.14), Vector3(0.19, 0.20, 0.22), dark)
	_cone(_part("Neck"), "NeckSkin", Vector3.ZERO, 0.21, 0.11, 0.12, skin)

	for side_name in ["Left", "Right"]:
		var upper := _part(side_name + "UpperArm")
		_orb(upper, side_name + "Sleeve", Vector3(0, -0.16, 0), Vector3(0.265, 0.52, 0.30), fabric)
		var forearm := _part(side_name + "Forearm")
		_orb(forearm, side_name + "LowerSleeve", Vector3(0, -0.13, 0), Vector3(0.226, 0.40, 0.26), fabric)
		_orb(forearm, side_name + "Glove", Vector3(0, -0.33, 0), Vector3(0.205, 0.24, 0.23), dark)
		_box(forearm, side_name + "Cuff", Vector3(0, -0.25, 0), Vector3(0.24, 0.065, 0.28), trim)
		var thigh := _part(side_name + "Thigh")
		_orb(thigh, side_name + "TrouserUpper", Vector3(0, -0.21, 0), Vector3(0.30 * hips, 0.55, 0.34), pants)
		var shin := _part(side_name + "Shin")
		_orb(shin, side_name + "TrouserLower", Vector3(0, -0.17, 0), Vector3(0.24, 0.48, 0.29), pants)
		_orb(shin, side_name + "Boot", Vector3(0, -0.36, -0.07), Vector3(0.28, 0.30, 0.43), dark)
		_box(shin, side_name + "BootBand", Vector3(0, -0.25, 0), Vector3(0.28, 0.08, 0.30), trim)

		if int(appearance["outfit_style"]) == 2:
			_orb(upper, side_name + "Pauldron", Vector3(0, 0.04, 0), Vector3(0.42, 0.21, 0.42), armor)

	# Anime-proportioned face, eyes, and original procedural hair designs.
	var head := _part("Head")
	_orb(head, "Face", Vector3(0, 0, 0), Vector3(0.47, 0.54, 0.44), skin)
	for side in [-1.0, 1.0]:
		_orb(head, "Ear", Vector3(side * 0.237, -0.04, 0.015), Vector3(0.10, 0.17, 0.13), skin)
		_orb(head, "EyeWhite", Vector3(side * 0.112, 0.024, -0.205), Vector3(0.133, 0.095, 0.070), white)
		_orb(head, "EyeIris", Vector3(side * 0.112, 0.018, -0.244), Vector3(0.082, 0.087, 0.021), eyes)
		_orb(head, "EyePupil", Vector3(side * 0.112, 0.014, -0.259), Vector3(0.035, 0.066, 0.016), ink)
		_orb(head, "UpperLash", Vector3(side * 0.112, 0.089, -0.214), Vector3(0.150, 0.021, 0.026), ink)
	_orb(head, "Nose", Vector3(0, -0.060, -0.235), Vector3(0.055, 0.083, 0.058), skin_shadow)
	_orb(head, "Mouth", Vector3(0, -0.154, -0.207), Vector3(0.09, 0.012, 0.025), skin_shadow)
	_build_hair(head, hair)

	match int(appearance["outfit_style"]):
		1:
			# Spellweaver mantle and layered coat tail.
			_orb(chest_attach, "MageMantle", Vector3(0, 0.10, 0.08), Vector3(0.88 * shoulders, 0.26, 0.63), dark)
			_box(hip_attach, "MageCoatTail", Vector3(0, -0.28, 0.22), Vector3(0.51, 0.51, 0.10), fabric)
		2:
			_box(chest_attach, "ArmorPlate", Vector3(0, 0.005, -0.27), Vector3(0.41, 0.31, 0.055), armor)
			_box(chest_attach, "ArmorInsignia", Vector3(0, 0.035, -0.30), Vector3(0.095, 0.16, 0.025), trim)
		_:
			_box(hip_attach, "AdventureSatchel", Vector3(0.25, -0.16, -0.18), Vector3(0.22, 0.24, 0.19), dark)

func _build_hair(head: Node3D, material: Material) -> void:
	var style := int(appearance["hair_style"])
	_orb(head, "HairCap", Vector3(0, 0.20, 0.02), Vector3(0.50, 0.26, 0.47), material)
	if style == 2:
		for i in range(5):
			var tuft := _cone(head, "ShortTuft", Vector3(-0.19 + i * 0.095, 0.30, -0.11), 0.18, 0.0, 0.075, material)
			tuft.rotation.z = -0.35 + i * 0.20
	else:
		for i in range(7):
			var tuft := _cone(head, "Bangs", Vector3(-0.235 + i * 0.078, 0.245, -0.19), 0.22 + float(i % 2) * 0.04, 0.0, 0.063, material)
			tuft.rotation.z = -0.4 + i * 0.135
			tuft.rotation.x = -0.18
	if style == 1:
		_orb(head, "LongBackHair", Vector3(0, -0.17, 0.17), Vector3(0.49, 0.78, 0.32), material)
		for side in [-1.0, 1.0]:
			_orb(head, "LongSideHair", Vector3(side * 0.22, -0.25, -0.09), Vector3(0.13, 0.64, 0.23), material)
	elif style == 3:
		_orb(head, "PonytailAnchor", Vector3(0, 0.21, 0.21), Vector3(0.19, 0.20, 0.20), material)
		_orb(head, "Ponytail", Vector3(0, -0.10, 0.32), Vector3(0.30, 0.63, 0.29), material)
	elif style == 0:
		_orb(head, "SweptBackHair", Vector3(0, -0.02, 0.17), Vector3(0.43, 0.30, 0.26), material)
		_orb(head, "SideBang", Vector3(-0.19, 0.045, -0.185), Vector3(0.17, 0.30, 0.13), material)

func set_motion_state(horizontal_speed: float, grounded: bool, delta: float) -> void:
	if not is_instance_valid(_skeleton):
		return
	_clock += delta
	var target_weight := clampf(horizontal_speed / 4.1, 0.0, 1.0)
	_blend = move_toward(_blend, target_weight, delta * 5.0)
	var running := horizontal_speed > 5.1
	var rate := 12.0 if running else 8.0
	_stride_clock += delta * rate
	_state = "JUMP" if not grounded else ("RUN" if running and _blend > 0.2 else ("WALK" if _blend > 0.08 else "IDLE"))
	var stride := sin(_stride_clock) * _blend
	var bob := absf(stride) * (0.035 if running else 0.020)
	var sway := sin(_stride_clock) * _blend * 0.032

	_rotate_bone("Hips", Vector3(0, sway, 0), delta)
	_rotate_bone("Spine", Vector3(0.018 * sin(_clock * 2.1), 0, -sway), delta)
	_rotate_bone("Chest", Vector3(0, -sway * 0.5, 0), delta)
	_rotate_bone("Neck", Vector3(0, 0, sin(_clock * 1.7) * 0.014), delta)
	_rotate_bone("Head", Vector3(0, 0, -sin(_clock * 1.7) * 0.012), delta)
	_rotate_bone("LeftThigh", Vector3(stride * 0.60, 0, 0), delta)
	_rotate_bone("RightThigh", Vector3(-stride * 0.60, 0, 0), delta)
	_rotate_bone("LeftShin", Vector3(maxf(0.0, -stride) * 0.55, 0, 0), delta)
	_rotate_bone("RightShin", Vector3(maxf(0.0, stride) * 0.55, 0, 0), delta)
	_rotate_bone("LeftUpperArm", Vector3(-stride * 0.39, 0, -0.12), delta)
	_rotate_bone("RightUpperArm", Vector3(stride * 0.39, 0, 0.12), delta)
	_rotate_bone("LeftForearm", Vector3(-0.11 - absf(stride) * 0.10, 0, 0), delta)
	_rotate_bone("RightForearm", Vector3(-0.11 - absf(stride) * 0.10, 0, 0), delta)

	if not grounded:
		_rotate_bone("LeftThigh", Vector3(-0.27, 0, 0), delta)
		_rotate_bone("RightThigh", Vector3(0.23, 0, 0), delta)
		_rotate_bone("LeftShin", Vector3(0.28, 0, 0), delta)
		_rotate_bone("RightShin", Vector3(0.15, 0, 0), delta)
	if _wave_time > 0:
		_wave_time -= delta
		_state = "WAVE"
		_rotate_bone("RightUpperArm", Vector3(-0.19, 0, 2.02), delta)
		_rotate_bone("RightForearm", Vector3(0, 0, 0.38 + sin(_clock * 9.0) * 0.28), delta)
	# Modest root bob adds life without changing collision geometry.
	_skeleton.position.y = lerpf(_skeleton.position.y, sin(_clock * 2.1) * 0.008 + bob, minf(1.0, delta * 8.0))

func _rotate_bone(name: String, target: Vector3, delta: float) -> void:
	var current: Vector3 = _pose_angles.get(name, Vector3.ZERO)
	var next: Vector3 = current.lerp(target, minf(1.0, delta * 10.0))
	_pose_angles[name] = next
	var quat := Quaternion.from_euler(next)
	_skeleton.set_bone_pose_rotation(int(_bones[name]), quat)

func wave() -> void:
	_wave_time = 2.2

func get_animation_state() -> String:
	return _state

func appearance_description() -> String:
	var frame_name := "Broad" if int(appearance["frame"]) == 0 else "Slender"
	return "%s  /  %s  /  %s" % [frame_name, HAIR_NAMES[int(appearance["hair_style"])], STYLE_NAMES[int(appearance["outfit_style"])]]

func cycle_option(key: String, direction: int = 1) -> void:
	var limits := {"frame": 2, "skin": SKIN_COLORS.size(), "hair": HAIR_COLORS.size(), "hair_style": HAIR_NAMES.size(), "eyes": EYE_COLORS.size(), "outfit": OUTFIT_COLORS.size(), "outfit_style": STYLE_NAMES.size()}
	if not limits.has(key):
		return
	var count: int = limits[key]
	appearance[key] = posmod(int(appearance[key]) + direction, count)
	_build_avatar()
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
	var counts := {"frame": 2, "skin": SKIN_COLORS.size(), "hair": HAIR_COLORS.size(), "hair_style": HAIR_NAMES.size(), "eyes": EYE_COLORS.size(), "outfit": OUTFIT_COLORS.size(), "outfit_style": STYLE_NAMES.size()}
	for key in counts:
		if data.has(key) and (typeof(data[key]) == TYPE_INT or typeof(data[key]) == TYPE_FLOAT):
			appearance[key] = clampi(int(data[key]), 0, int(counts[key]) - 1)

func _save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(appearance, "\t"))
		file.close()
