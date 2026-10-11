extends RefCounted
## Replace placeholder meshes with compact CC0 Quaternius glTF scenes when present.
## Missing resources safely retain the original visual mesh and gameplay collision.

const MODEL_DIR := "res://models/scenery/"

static func place(owner: Node3D, asset: String, desired_size: Vector3, keep_visible: PackedStringArray = PackedStringArray(), yaw_degrees: float = 0.0, ground_sink: float = 0.0) -> bool:
    var path := MODEL_DIR + asset + ".glb"
    if not ResourceLoader.exists(path):
        return false
    var scene := load(path) as PackedScene
    if scene == null:
        push_warning("Could not load scenery scene: " + path)
        return false
    var model := scene.instantiate() as Node3D
    if model == null:
        push_warning("Scenery resource is not Node3D: " + path)
        return false
    model.name = "Quaternius_" + asset
    owner.add_child(model)
    model.rotation_degrees.y = yaw_degrees

    # Compute bounds relative to the original object, including all child meshes.
    var bounds := AABB()
    var found_mesh := false
    var solid_found := false
    var solid_bounds := AABB()
    var pending: Array[Node] = [model]
    while not pending.is_empty():
        var part: Node = pending.pop_back()
        if part is MeshInstance3D:
            var mesh_part := part as MeshInstance3D
            if mesh_part.mesh != null:
                var box := mesh_part.get_aabb()
                # Stone/dark plaster defines solid ground-floor masonry; never
                # use roof eaves, awnings or decorative timber as wall collision.
                var surface_label := mesh_part.name.to_lower()
                for material_idx in range(mesh_part.mesh.get_surface_count()):
                    var material := mesh_part.get_active_material(material_idx)
                    if material != null:
                        surface_label += " " + material.resource_name.to_lower()
                var wall_mesh := surface_label.contains("stone_dark") or surface_label.contains("plaster")
                for x in [0.0, 1.0]:
                    for y in [0.0, 1.0]:
                        for z in [0.0, 1.0]:
                            var corner := box.position + box.size * Vector3(x, y, z)
                            var point := owner.to_local(mesh_part.to_global(corner))
                            if not found_mesh:
                                bounds = AABB(point, Vector3.ZERO)
                                found_mesh = true
                            else:
                                bounds = bounds.expand(point)
                            if wall_mesh:
                                if not solid_found:
                                    solid_bounds = AABB(point, Vector3.ZERO)
                                    solid_found = true
                                else:
                                    solid_bounds = solid_bounds.expand(point)
        for child in part.get_children():
            pending.append(child)
    if not found_mesh:
        model.queue_free()
        return false

    var fit_x := desired_size.x / maxf(bounds.size.x, 0.01)
    var fit_y := desired_size.y / maxf(bounds.size.y, 0.01)
    var fit_z := desired_size.z / maxf(bounds.size.z, 0.01)
    var uniform_scale := minf(fit_x, minf(fit_y, fit_z))
    var fitted_scale := Vector3.ONE * uniform_scale
    # Larger medieval structures must fill their existing collision footprint.
    # Preserve exact vertical target and horizontal width/depth so doors and
    # corners do not appear metres behind invisible primitive blockers.
    if asset.begins_with("House_") or asset == "Inn" or asset == "Blacksmith":
        fitted_scale = Vector3(fit_x, fit_y, fit_z)
    model.scale = fitted_scale
    model.position = Vector3(
        -(bounds.position.x + bounds.size.x * 0.5) * fitted_scale.x,
        -bounds.position.y * fitted_scale.y - ground_sink,
        -(bounds.position.z + bounds.size.z * 0.5) * fitted_scale.z
    )

    # Collision and QA can read the rendered model's actual fitted dimensions,
    # rather than retaining the old procedural building/counter footprint.
    owner.set_meta("scenery_model_size", Vector3(
        bounds.size.x * fitted_scale.x,
        bounds.size.y * fitted_scale.y,
        bounds.size.z * fitted_scale.z
    ))
    owner.set_meta("scenery_ground_sink", ground_sink)
    if solid_found and (asset.begins_with("House_") or asset == "Inn" or asset == "Blacksmith"):
        var solid_low := Vector2(
            solid_bounds.position.x * fitted_scale.x + model.position.x,
            solid_bounds.position.z * fitted_scale.z + model.position.z
        )
        var solid_size := Vector2(
            solid_bounds.size.x * fitted_scale.x,
            solid_bounds.size.z * fitted_scale.z
        )
        owner.set_meta("scenery_wall_footprint", Rect2(solid_low, solid_size))
    # The Quaternius leaves have alpha-cutout planes. Transparent alpha blending
    # exposed the flowers and leaves behind the bush as ghostly overlays.
    # Two-sided alpha SCISSOR keeps depth writes while preserving leaf edges.
    if asset.begins_with("Bush"):
        _opaque_cutout_foliage(model)
    # Preserve original mesh nodes for QA and safe fallback. Physics blockers
    # belong to the town controller and are deliberately never removed.
    for child in owner.get_children():
        if child is MeshInstance3D and child != model and not keep_visible.has(child.name):
            (child as MeshInstance3D).visible = false
    return true

static func _opaque_cutout_foliage(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for index in range(mesh_instance.mesh.get_surface_count()):
                var source := mesh_instance.get_active_material(index)
                if source is StandardMaterial3D:
                    var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
                    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                    mat.alpha_scissor_threshold = 0.50
                    mesh_instance.set_surface_override_material(index, mat)
    for child in node.get_children():
        _opaque_cutout_foliage(child)
