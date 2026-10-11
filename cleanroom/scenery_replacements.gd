extends RefCounted
## Replace placeholder meshes with compact CC0 Quaternius glTF scenes when present.
## Missing resources safely retain the original visual mesh and gameplay collision.

const MODEL_DIR := "res://models/scenery/"

static func place(owner: Node3D, asset: String, desired_size: Vector3, keep_visible: PackedStringArray = PackedStringArray(), yaw_degrees: float = 0.0) -> bool:
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
    var pending: Array[Node] = [model]
    while not pending.is_empty():
        var part := pending.pop_back()
        if part is MeshInstance3D:
            var mesh_part := part as MeshInstance3D
            if mesh_part.mesh != null:
                var box := mesh_part.get_aabb()
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
        for child in part.get_children():
            pending.append(child)
    if not found_mesh:
        model.queue_free()
        return false

    var fit_x := desired_size.x / maxf(bounds.size.x, 0.01)
    var fit_y := desired_size.y / maxf(bounds.size.y, 0.01)
    var fit_z := desired_size.z / maxf(bounds.size.z, 0.01)
    var uniform_scale := minf(fit_x, minf(fit_y, fit_z))
    model.scale = Vector3.ONE * uniform_scale
    model.position = Vector3(
        -(bounds.position.x + bounds.size.x * 0.5) * uniform_scale,
        -bounds.position.y * uniform_scale,
        -(bounds.position.z + bounds.size.z * 0.5) * uniform_scale
    )

    # Preserve original mesh nodes for QA and safe fallback. Physics blockers
    # belong to the town controller and are deliberately never removed.
    for child in owner.get_children():
        if child is MeshInstance3D and child != model and not keep_visible.has(child.name):
            (child as MeshInstance3D).visible = false
    return true
