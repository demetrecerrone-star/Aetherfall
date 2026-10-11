extends RefCounted
## Lightweight Quaternius Nature MegaKit Standard GLB helper.
## No new collision bodies: existing camera/player blockers are retained.
const NATURE_PATH := "res://models/nature/"

static func available(name: String) -> bool:
    return ResourceLoader.exists(NATURE_PATH + name + ".glb")

static func _mesh_nodes(model: Node) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D] = []
    if model is MeshInstance3D:
        result.append(model as MeshInstance3D)
    for item in model.find_children("*", "MeshInstance3D", true, false):
        result.append(item as MeshInstance3D)
    return result

static func _bounds(model: Node3D) -> AABB:
    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    for visual in _mesh_nodes(model):
        if visual.mesh == null:
            continue
        var mesh_box := visual.get_aabb()
        var local_xf := model.global_transform.affine_inverse() * visual.global_transform
        for x in [0.0, 1.0]:
            for y in [0.0, 1.0]:
                for z in [0.0, 1.0]:
                    var point := local_xf * (mesh_box.position + mesh_box.size * Vector3(x, y, z))
                    minimum = minimum.min(point)
                    maximum = maximum.max(point)
    if minimum.x == INF:
        return AABB(Vector3.ZERO, Vector3.ZERO)
    return AABB(minimum, maximum - minimum)

static func _polish_foliage(node: Node) -> void:
    for visual in _mesh_nodes(node):
        if visual.mesh == null:
            continue
        for surface in range(visual.mesh.get_surface_count()):
            var original := visual.get_active_material(surface)
            if not (original is StandardMaterial3D):
                continue
            var label := (String(original.resource_name) + " " + visual.name).to_lower()
            var leaves := label.contains("leave") or label.contains("leaf") or label.contains("grass") or label.contains("flower")
            if not leaves:
                continue
            var polished := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
            polished.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            polished.alpha_scissor_threshold = 0.56
            polished.cull_mode = BaseMaterial3D.CULL_DISABLED
            polished.roughness = 0.94
            # Genuine leafy textures already provide shape and definition.
            # Darken just the foliage, never the trunk/bark or visible flowers.
            var tint: Color = polished.albedo_color
            if label.contains("leave") or label.contains("leaf"):
                polished.albedo_color = Color(tint.r * 0.78, tint.g * 0.81,
                    tint.b * 0.75, tint.a)
            visual.set_surface_override_material(surface, polished)

static func place(parent: Node3D, asset: String, target_size: Vector3, ground_sink: float = 0.06) -> bool:
    if not available(asset):
        return false
    var scene := load(NATURE_PATH + asset + ".glb") as PackedScene
    if scene == null:
        return false
    var model := scene.instantiate() as Node3D
    if model == null:
        return false
    parent.add_child(model)
    var bounds := _bounds(model)
    if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
        model.queue_free()
        return false
    model.name = "QuaterniusNature_" + asset
    model.scale = Vector3(target_size.x / bounds.size.x, target_size.y / bounds.size.y, target_size.z / bounds.size.z)
    model.position = Vector3(
        -(bounds.position.x + bounds.size.x * 0.5) * model.scale.x,
        -bounds.position.y * model.scale.y - ground_sink,
        -(bounds.position.z + bounds.size.z * 0.5) * model.scale.z
    )
    _polish_foliage(model)
    parent.set_meta("nature_asset", asset)
    parent.set_meta("nature_ground_sink", ground_sink)
    parent.set_meta("tree_leaf_cutout_fixed", asset.begins_with("Pine_") or asset.begins_with("CommonTree_"))
    return true

static func grass_mesh(asset_name: String = "Grass_Common_Short") -> ArrayMesh:
    if not available(asset_name):
        return null
    var scene := load(NATURE_PATH + asset_name + ".glb") as PackedScene
    if scene == null:
        return null
    var model := scene.instantiate() as Node3D
    if model == null:
        return null
    var result: ArrayMesh = null
    for visual in _mesh_nodes(model):
        if visual.mesh is ArrayMesh:
            result = (visual.mesh as ArrayMesh).duplicate(true) as ArrayMesh
            for surface in range(result.get_surface_count()):
                var original := visual.get_active_material(surface)
                if original is StandardMaterial3D:
                    var mat := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
                    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                    mat.alpha_scissor_threshold = 0.5
                    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
                    mat.roughness = 1.0
                    mat.albedo_color = mat.albedo_color * (Color(0.70, 0.86, 0.73, 1.0) if asset_name == "Fern_1" else Color(0.78, 0.88, 0.77, 1.0))
                    result.surface_set_material(surface, mat)
            break
    model.free()
    return result
