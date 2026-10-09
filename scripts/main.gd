extends Node3D
## Lightweight original fantasy environment designed for camera/movement QA.
## Offline for this milestone; no false multiplayer or save-system claims.

const MAP_SIZE := 160.0
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
@onready var world: Node3D = $World
@onready var player: Variant = $Player
@onready var hud: Variant = $HUD

func _ready() -> void:
	_rng.seed = 348921
	_build_lighting()
	_build_environment()
	player.attach_hud(hud)
	hud.hair_tapped.connect(func() -> void: player.get_node("Avatar").cycle_hair())
	hud.outfit_tapped.connect(func() -> void: player.get_node("Avatar").cycle_outfit())

func _mat(color_code: String, roughness: float = 0.90) -> StandardMaterial3D:
	if _materials.has(color_code):
		return _materials[color_code]
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color_code)
	result.roughness = roughness
	_materials[color_code] = result
	return result

func _mesh_box(label: String, loc: Vector3, dimensions: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	visual.material_override = material
	visual.position = loc
	(parent if parent != null else world).add_child(visual)
	return visual

func _mesh_cylinder(label: String, loc: Vector3, height: float, top_radius: float, bottom_radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.radial_segments = 9
	visual.mesh = mesh
	visual.material_override = material
	visual.position = loc
	(parent if parent != null else world).add_child(visual)
	return visual

func _mesh_ball(label: String, loc: Vector3, scale_3d: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 5
	visual.mesh = mesh
	visual.material_override = material
	visual.position = loc
	visual.scale = scale_3d
	(parent if parent != null else world).add_child(visual)
	return visual

func _obstacle(label: String, position_3d: Vector3, dimensions: Vector3) -> void:
	var collider := StaticBody3D.new()
	collider.name = label + "Collision"
	collider.position = position_3d
	world.add_child(collider)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	collider.add_child(shape_node)

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("ffecd4")
	sun.shadow_enabled = true
	add_child(sun)
	var env_root := WorldEnvironment.new()
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5f98c6")
	sky_mat.sky_horizon_color = Color("c3e0de")
	sky_mat.ground_bottom_color = Color("98ab8b")
	sky_mat.ground_horizon_color = Color("d4d4aa")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_root.environment = env
	add_child(env_root)

func _build_environment() -> void:
	_mesh_box("GrassMeadow", Vector3(0, -0.32, -16), Vector3(MAP_SIZE, 0.64, MAP_SIZE), _mat("709e67"))
	_obstacle("Ground", Vector3(0, -0.32, -16), Vector3(MAP_SIZE, 0.64, MAP_SIZE))
	# Stone footpath winds from spawn, through the village, to the northern field.
	for index in range(57):
		var z := 11.0 - index * 0.88
		var wiggle := sin(float(index) * 0.16) * 0.95
		_mesh_box("StonePath%02d" % index, Vector3(wiggle, 0.025, z), Vector3(5.2, 0.05, 0.79), _mat("c6baa0"))
		if index % 3 == 0:
			_mesh_box("PathMoss%02d" % index, Vector3(wiggle - 1.55, 0.06, z - 0.19), Vector3(0.65, 0.035, 0.12), _mat("879e79"))

	# A little arrival plaza; the path and nearby walls make camera collision easy to test.
	_mesh_box("VillagePlaza", Vector3(0, 0.045, -10.4), Vector3(15.5, 0.09, 11), _mat("afa994"))
	_build_fountain(Vector3(0, 0, -10.0))
	_build_house(Vector3(-11, 0, -4), "56778b", "6a4d52")
	_build_house(Vector3(11, 0, -5), "ae987b", "557b7b")
	_build_house(Vector3(-12, 0, -21), "c7b4a0", "685d7e")
	_build_house(Vector3(12, 0, -22), "b8a68a", "54606f")
	_build_gate(Vector3(0, 0, -39))
	_build_training_camp(Vector3(11, 0, -38))

	# The random areas stay open near the player spawn and between village structures.
	for i in range(86):
		var x := _rng.randf_range(-73.0, 73.0)
		var z := _rng.randf_range(-86.0, 53.0)
		if absf(x) < 21.0 and z > -47.0 and z < 20.0:
			continue
		if Vector2(x, z).length() < 14.0:
			continue
		_build_tree(Vector3(x, 0, z), _rng.randf_range(0.75, 1.55))

	for i in range(190):
		var x := _rng.randf_range(-72.0, 72.0)
		var z := _rng.randf_range(-79.0, 53.0)
		if absf(x) < 7.0 and z < 12.0 and z > -47.0:
			continue
		var shade := "d1d47d" if i % 3 == 0 else ("e6b7a7" if i % 3 == 1 else "c2dfd2")
		_mesh_ball("Wildflower%03d" % i, Vector3(x, 0.13, z), Vector3(0.12, 0.22, 0.12), _mat(shade))

func _build_fountain(at: Vector3) -> void:
	_mesh_cylinder("FountainBase", at + Vector3(0, 0.24, 0), 0.48, 2.0, 2.0, _mat("8a9da2"))
	_mesh_cylinder("FountainWater", at + Vector3(0, 0.52, 0), 0.075, 1.73, 1.73, _mat("68c8d8", 0.14))
	_mesh_cylinder("FountainColumn", at + Vector3(0, 1.03, 0), 1.18, 0.29, 0.39, _mat("d3d4c7"))
	_mesh_cylinder("FountainTop", at + Vector3(0, 1.70, 0), 0.19, 0.96, 0.72, _mat("a6bdc2"))
	_mesh_ball("WaterOrb", at + Vector3(0, 2.08, 0), Vector3(0.38, 0.48, 0.38), _mat("9ee8e9", 0.1))
	_obstacle("Fountain", at + Vector3(0, 0.28, 0), Vector3(3.7, 0.56, 3.7))

func _build_house(at: Vector3, stone_hex: String, roof_hex: String) -> void:
	var stone := _mat(stone_hex)
	var roof := _mat(roof_hex)
	_mesh_box("ShopWalls", at + Vector3(0, 1.65, 0), Vector3(5.0, 3.3, 4.3), stone)
	_obstacle("Shop", at + Vector3(0, 1.65, 0), Vector3(5.0, 3.3, 4.3))
	# Two diagonal panels create a pitched roof (no imported assets required).
	var left := _mesh_box("RoofSlopeLeft", at + Vector3(-1.25, 3.85, 0), Vector3(3.28, 0.32, 5.15), roof)
	left.rotation.z = -0.48
	var right := _mesh_box("RoofSlopeRight", at + Vector3(1.25, 3.85, 0), Vector3(3.28, 0.32, 5.15), roof)
	right.rotation.z = 0.48
	_mesh_box("FrontDoor", at + Vector3(0, 1.03, 2.16), Vector3(1.28, 2.05, 0.10), _mat("4e3e42"))
	_mesh_ball("DoorHandle", at + Vector3(0.41, 1.05, 2.25), Vector3(0.11, 0.11, 0.07), _mat("e2c287"))
	for sign_side in [-1.0, 1.0]:
		_mesh_box("GlowingWindow", at + Vector3(sign_side * 1.67, 1.85, 2.21), Vector3(0.87, 0.92, 0.10), _mat("f3db9d"))
		_mesh_box("WindowCrossVertical", at + Vector3(sign_side * 1.67, 1.85, 2.29), Vector3(0.08, 0.98, 0.09), _mat("725852"))
		_mesh_box("WindowCrossHorizontal", at + Vector3(sign_side * 1.67, 1.85, 2.29), Vector3(0.93, 0.08, 0.09), _mat("725852"))

func _build_tree(at: Vector3, amount: float) -> void:
	var trunk_height := 2.0 * amount
	_mesh_cylinder("TreeTrunk", at + Vector3(0, trunk_height * 0.5, 0), trunk_height, 0.25 * amount, 0.39 * amount, _mat("725c4a"))
	_mesh_cylinder("PineCrownLower", at + Vector3(0, trunk_height + 0.75 * amount, 0), 2.55 * amount, 0.0, 1.67 * amount, _mat("497c67"))
	_mesh_cylinder("PineCrownUpper", at + Vector3(0, trunk_height + 2.0 * amount, 0), 2.2 * amount, 0.0, 1.22 * amount, _mat("5f9678"))
	_obstacle("Tree", at + Vector3(0, trunk_height * 0.5, 0), Vector3(0.57 * amount, trunk_height, 0.57 * amount))

func _build_gate(at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		_mesh_box("GatePillar", at + Vector3(side * 3.15, 2.1, 0), Vector3(1.1, 4.2, 1.2), _mat("8d9b9c"))
		_obstacle("GatePillar", at + Vector3(side * 3.15, 2.1, 0), Vector3(1.1, 4.2, 1.2))
		_mesh_cylinder("GateLantern", at + Vector3(side * 3.15, 4.35, 0), 0.45, 0.35, 0.35, _mat("f1d58a"))
	_mesh_box("GateLintel", at + Vector3(0, 4.4, 0), Vector3(7.1, 0.9, 1.4), _mat("485e7b"))
	_mesh_box("GateBanner", at + Vector3(0, 4.15, 0.78), Vector3(3.3, 0.62, 0.06), _mat("d0ae76"))

func _build_training_camp(at: Vector3) -> void:
	_mesh_cylinder("CampPlatform", at + Vector3(0, 0.13, 0), 0.26, 4.9, 4.9, _mat("a2a38d"))
	for index in range(3):
		var pos := at + Vector3(-2.5 + index * 2.5, 0, 0)
		_mesh_cylinder("TrainingPost", pos + Vector3(0, 1.0, 0), 1.9, 0.21, 0.29, _mat("90674b"))
		_mesh_box("TrainingTarget", pos + Vector3(0, 1.3, 0), Vector3(0.95, 0.96, 0.22), _mat("d0ae7d"))
		_mesh_ball("TargetCenter", pos + Vector3(0, 1.3, -0.15), Vector3(0.43, 0.43, 0.075), _mat("bb6b65"))
