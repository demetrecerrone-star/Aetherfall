extends Node3D
## Stylized FULL 3D placeholder humanoid made entirely in Godot (no 2D billboards).
## Swap this node with a properly skinned GLB later; physics/camera remain untouched.

var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _body: Node3D
var _hair: Node3D
var _head: Node3D
var _elapsed := 0.0
var _jacket_color := 0
var _hair_color := 0
var _outfit_palette := [Color("233454"), Color("59416e"), Color("1f5957"), Color("784347")]
var _hair_palette := [Color("171c31"), Color("9d6f49"), Color("b1c5d5"), Color("6f375f")]

func _ready() -> void:
	build_character()

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _ball(label: String, parent: Node3D, position_3d: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material
	node.position = position_3d
	node.scale = size
	parent.add_child(node)
	return node

func _box(label: String, parent: Node3D, position_3d: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position_3d
	parent.add_child(node)
	return node

func _cylinder(label: String, parent: Node3D, position_3d: Vector3, height: float, top_radius: float, bottom_radius: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.radial_segments = 10
	node.mesh = mesh
	node.material_override = material
	node.position = position_3d
	parent.add_child(node)
	return node

func _joint(label: String, parent: Node3D, position_3d: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = position_3d
	parent.add_child(node)
	return node

func build_character() -> void:
	for child in get_children():
		child.queue_free()
	var skin := _mat(Color("e7ae90"))
	var shaded_skin := _mat(Color("b98372"))
	var coat := _mat(_outfit_palette[_jacket_color])
	var coat_trim := _mat(Color("d5b36f"), 0.38, 0.42)
	var clothing_dark := _mat(Color("20283b"))
	var boots := _mat(Color("232335"))
	var eye_white := _mat(Color("f8f0ea"))
	var iris := _mat(Color("36566e"), 0.05, 0.25)
	var pupil := _mat(Color("111421"))
	var hair_mat := _mat(_hair_palette[_hair_color])

	_body = _joint("BreathingBody", self, Vector3.ZERO)
	# Jacket and tunic form one visually overlapping silhouette.
	_cylinder("Tunic", _body, Vector3(0, 1.12, 0), 0.78, 0.35, 0.25, coat)
	_ball("UpperChest", _body, Vector3(0, 1.40, -0.01), Vector3(0.73, 0.40, 0.42), coat)
	_box("Belt", _body, Vector3(0, 0.87, -0.005), Vector3(0.57, 0.11, 0.4), clothing_dark)
	_box("BeltBuckle", _body, Vector3(0, 0.87, -0.213), Vector3(0.12, 0.09, 0.025), coat_trim)
	_cylinder("Neck", _body, Vector3(0, 1.67, 0), 0.24, 0.105, 0.105, skin)
	_box("LeftCollarEdge", _body, Vector3(-0.115, 1.515, -0.185), Vector3(0.075, 0.22, 0.05), coat_trim)
	_box("RightCollarEdge", _body, Vector3(0.115, 1.515, -0.185), Vector3(0.075, 0.22, 0.05), coat_trim)
	_box("CoatSeam", _body, Vector3(0, 1.19, -0.276), Vector3(0.032, 0.53, 0.02), coat_trim)

	_left_leg = _joint("LeftLegPivot", self, Vector3(-0.155, 0.88, 0))
	_right_leg = _joint("RightLegPivot", self, Vector3(0.155, 0.88, 0))
	for leg in [_left_leg, _right_leg]:
		_ball("Trouser", leg, Vector3(0, -0.30, 0), Vector3(0.31, 0.66, 0.33), clothing_dark)
		_ball("Boot", leg, Vector3(0, -0.69, -0.068), Vector3(0.32, 0.25, 0.47), boots)
		_box("BootTrim", leg, Vector3(0, -0.594, -0.068), Vector3(0.32, 0.075, 0.35), coat_trim)

	_left_arm = _joint("LeftArmPivot", _body, Vector3(-0.4, 1.46, 0))
	_right_arm = _joint("RightArmPivot", _body, Vector3(0.4, 1.46, 0))
	for arm in [_left_arm, _right_arm]:
		_ball("Sleeve", arm, Vector3(0, -0.24, 0), Vector3(0.29, 0.60, 0.32), coat)
		_ball("Glove", arm, Vector3(0, -0.55, 0), Vector3(0.22, 0.24, 0.22), boots)
		_box("Cuff", arm, Vector3(0, -0.46, 0), Vector3(0.24, 0.08, 0.255), coat_trim)

	_head = _joint("Head", _body, Vector3(0, 1.85, 0))
	_ball("Face", _head, Vector3(0, 0.02, -0.017), Vector3(0.51, 0.58, 0.49), skin)
	# Eye details are on front (-Z); large and expressive anime proportions.
	for side in [-1.0, 1.0]:
		_ball("EyeWhite", _head, Vector3(side * 0.118, 0.056, -0.231), Vector3(0.153, 0.098, 0.055), eye_white)
		_ball("Iris", _head, Vector3(side * 0.118, 0.054, -0.264), Vector3(0.083, 0.088, 0.018), iris)
		_ball("Pupil", _head, Vector3(side * 0.118, 0.051, -0.276), Vector3(0.038, 0.069, 0.015), pupil)
		_ball("Eyebrow", _head, Vector3(side * 0.119, 0.154, -0.23), Vector3(0.16, 0.031, 0.025), hair_mat)
	_ball("Nose", _head, Vector3(0, -0.025, -0.268), Vector3(0.058, 0.085, 0.058), shaded_skin)
	_ball("Mouth", _head, Vector3(0, -0.14, -0.23), Vector3(0.105, 0.014, 0.021), shaded_skin)
	for side in [-1.0, 1.0]:
		_ball("Ear", _head, Vector3(side * 0.25, -0.018, 0.005), Vector3(0.085, 0.154, 0.10), skin)
	_hair = _joint("Hair", _head, Vector3.ZERO)
	_ball("HairCap", _hair, Vector3(0, 0.24, 0.01), Vector3(0.53, 0.29, 0.50), hair_mat)
	# Chunky asymmetric anime hair tufts.
	for i in range(8):
		var spike := _cylinder("HairTuft%02d" % i, _hair, Vector3(-0.27 + i * 0.074, 0.315, -0.145 + 0.03 * float(i % 3)), 0.26 + float(i % 3) * 0.055, 0.0, 0.10, hair_mat)
		spike.rotation.z = -0.47 + i * 0.11
		spike.rotation.x = -0.18
	_ball("SideHairLeft", _hair, Vector3(-0.23, 0.12, 0.06), Vector3(0.13, 0.28, 0.29), hair_mat)
	_ball("SideHairRight", _hair, Vector3(0.23, 0.13, 0.075), Vector3(0.10, 0.25, 0.26), hair_mat)

func set_motion_state(horizontal_speed: float, grounded: bool, delta: float) -> void:
	_elapsed += delta
	var movement_weight := clampf(horizontal_speed / 5.0, 0.0, 1.0)
	var pace := 8.0 if horizontal_speed < 5.0 else 12.0
	var swing := sin(_elapsed * pace) * movement_weight
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, swing * 0.46, minf(1.0, delta * 12.0))
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -swing * 0.46, minf(1.0, delta * 12.0))
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -swing * 0.33, minf(1.0, delta * 10.0))
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, swing * 0.33, minf(1.0, delta * 10.0))
	if not grounded:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, -0.18, minf(1.0, delta * 9.0))
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.2, minf(1.0, delta * 9.0))
	_body.position.y = sin(_elapsed * 2.3) * 0.009 + absf(swing) * 0.022
	_head.rotation.z = sin(_elapsed * 1.8) * 0.016

func cycle_hair() -> void:
	_hair_color = (_hair_color + 1) % _hair_palette.size()
	build_character()

func cycle_outfit() -> void:
	_jacket_color = (_jacket_color + 1) % _outfit_palette.size()
	build_character()
