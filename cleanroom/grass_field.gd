extends RefCounted
const NatureReplacement = preload("res://nature_replacements.gd")
## Low, soft, curved meadow grass batched into 8m chunks for mobile rendering.
## Five-leaf tuft ribbons replace spike-like triangles. Roads stay clear.
const CELL_SIZE := 8.0
const TUFT_SPACING := 0.235
const SAMPLES_PER_CELL := 34

static func _blade_mesh() -> ArrayMesh:
    # Five slightly curved, tapered leaf blades per tuft instead of the old
    # four straight triangular spikes. These low-poly ribbons carry a soft
    # gradient from mossy base to desaturated sage-green tips. They are still
    # lightweight enough for Android MultiMesh batching.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var base_color := Color("#3c5133")
    var middle_color := Color("#58724c")
    var tip_color := Color("#879b71")
    for i in range(5):
        var angle := TAU * float(i) / 5.0 + 0.28
        var outward := Vector3(cos(angle), 0.0, sin(angle))
        var sideways := Vector3(-outward.z, 0.0, outward.x)
        var height := 0.184 if i % 3 == 0 else (0.158 if i % 3 == 1 else 0.172)
        var width := 0.048 if i % 2 == 0 else 0.042
        var base := outward * 0.013
        var mid := outward * 0.066 + Vector3(0.0, height * 0.50, 0.0)
        var tip := outward * 0.116 + Vector3(0.0, height, 0.0)
        var left_bottom := base - sideways * (width * 0.55)
        var right_bottom := base + sideways * (width * 0.55)
        var left_mid := mid - sideways * width
        var right_mid := mid + sideways * width
        for vertex in [left_bottom, right_bottom, left_mid]:
            tool.set_color(base_color)
            tool.add_vertex(vertex)
        for vertex in [left_mid, right_bottom, right_mid]:
            tool.set_color(middle_color)
            tool.add_vertex(vertex)
        for vertex in [left_mid, right_mid, tip]:
            tool.set_color(tip_color)
            tool.add_vertex(vertex)
    tool.generate_normals()
    var mesh := tool.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    material.metallic = 0.0
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mesh.surface_set_material(0, material)
    return mesh

static func populate(town: Node3D, blocked: Callable, ground_y: Callable) -> int:
    # Import the genuine Quaternius short grass, preserving native leaf shapes
    # and textures. Fall back to the previous soft procedural grass if the
    # optional CC0 bundle has not been uploaded to this branch.
    var native_mesh := NatureReplacement.grass_mesh()
    var native_enabled := native_mesh != null
    var mesh: ArrayMesh = native_mesh if native_enabled else _blade_mesh()
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
                    # The imported glTF grass is ~1.31m tall. Scale its
                    # geometry down to maintained village-lawn height ~0.19m.
                    var planted_size := Vector3(
                        scale_factor * (0.29 if native_enabled else 1.0),
                        blade_height * (0.145 if native_enabled else 1.0),
                        scale_factor * (0.29 if native_enabled else 1.0))
                    var basis := Basis(Vector3.UP, angle).scaled(planted_size)
                    transforms.append(Transform3D(basis, Vector3(x - float(tx), 0.008, z - float(tz))))
                    colors.append(Color(
                        rng.randf_range(0.86, 1.04),
                        rng.randf_range(0.90, 1.04),
                        rng.randf_range(0.87, 1.02),
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
    town.set_meta("grass_style", "quaternius_textured_short_grass" if native_enabled else "soft_curved_meadow_grass")
    town.set_meta("grass_nature_model_loaded", native_enabled)
    town.set_meta("grass_spacing_m", TUFT_SPACING)
    town.set_meta("grass_blade_nominal_height_m", 0.184)
    return total
