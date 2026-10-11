extends RefCounted
## Short, overlapping lawn grass batched into 8m chunks for mobile rendering.
## Dense instances cover the turf continuously; hard paving stays clear.
const CELL_SIZE := 8.0
const TUFT_SPACING := 0.235
const SAMPLES_PER_CELL := 34

static func _blade_mesh() -> ArrayMesh:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(4):
        var angle := TAU * float(i) / 4.0 + 0.24
        var side := Vector3(cos(angle), 0, sin(angle))
        # Broader but MUCH shorter leaves resemble maintained yard grass,
        # not the tall triangular spikes of the original test lawn.
        var width := 0.097 if i % 2 == 0 else 0.087
        var height := 0.205 if i % 2 == 0 else 0.162
        var lean := Vector3(sin(angle), 0, -cos(angle)) * 0.032
        tool.set_color(Color("#345f2e"))
        tool.add_vertex(-side * width)
        tool.set_color(Color("#46743a"))
        tool.add_vertex(side * width)
        tool.set_color(Color("#75a362"))
        tool.add_vertex(Vector3(0, height, 0) + lean)
    tool.generate_normals()
    var mesh := tool.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    mesh.surface_set_material(0, material)
    return mesh

static func populate(town: Node3D, blocked: Callable, ground_y: Callable) -> int:
    var mesh := _blade_mesh()
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261011
    var total := 0
    var tile_index := 0
    for tx in range(-26, 26, 8):
        for tz in range(-26, 26, 8):
            var transforms: Array[Transform3D] = []
            var colors: Array[Color] = []
            for gx in range(SAMPLES_PER_CELL):
                for gz in range(SAMPLES_PER_CELL):
                    # High-coverage, softly jittered lawn; reduce the empty
                    # gaps from 13% to 2% and halve the grid spacing.
                    if rng.randf() < 0.02:
                        continue
                    var x := float(tx) + (float(gx) + 0.5) * TUFT_SPACING + rng.randf_range(-0.060, 0.060)
                    var z := float(tz) + (float(gz) + 0.5) * TUFT_SPACING + rng.randf_range(-0.060, 0.060)
                    if absf(x) > 25.7 or absf(z) > 23.5:
                        continue
                    # Only lawn. Never put grass on a road, market paving,
                    # dirt shoulder, house, stall, bench or solid prop.
                    if float(ground_y.call(Vector3(x, 0.0, z))) > 0.012:
                        continue
                    if bool(blocked.call(Vector2(x, z))):
                        continue
                    var scale_factor := rng.randf_range(0.92, 1.15)
                    var blade_height := rng.randf_range(0.85, 1.20)
                    var angle := rng.randf_range(0.0, TAU)
                    var basis := Basis(Vector3.UP, angle).scaled(Vector3(scale_factor, blade_height, scale_factor))
                    transforms.append(Transform3D(basis, Vector3(x - float(tx), 0.008, z - float(tz))))
                    colors.append(Color(
                        rng.randf_range(0.90, 1.06),
                        rng.randf_range(0.94, 1.08),
                        rng.randf_range(0.89, 1.03),
                        1.0
                    ))
            if transforms.is_empty():
                continue
            var batch := MultiMesh.new()
            batch.transform_format = MultiMesh.TRANSFORM_3D
            batch.use_colors = true
            batch.mesh = mesh
            batch.instance_count = transforms.size()
            for j in range(transforms.size()):
                batch.set_instance_transform(j, transforms[j])
                batch.set_instance_color(j, colors[j])
            var render := MultiMeshInstance3D.new()
            render.name = "GrassField_%02d" % tile_index
            render.position = Vector3(float(tx), 0, float(tz))
            render.multimesh = batch
            render.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            town.add_child(render)
            tile_index += 1
            total += transforms.size()
    town.set_meta("grass_instance_count", total)
    town.set_meta("grass_chunk_count", tile_index)
    town.set_meta("grass_style", "dense_short_yard_grass")
    town.set_meta("grass_spacing_m", TUFT_SPACING)
    town.set_meta("grass_blade_nominal_height_m", 0.205)
    return total
