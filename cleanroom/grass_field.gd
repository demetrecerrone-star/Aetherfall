extends RefCounted
const NatureReplacement = preload("res://nature_replacements.gd")
## Low, soft, curved meadow grass batched into 8m chunks for mobile rendering.
## Five-leaf tuft ribbons replace spike-like triangles. Roads stay clear.
const CELL_SIZE := 8.0
# 56x56 rather than 40x40 per 8m cell: 3,136 vs 1,600 candidates,
# 1.96x the previous lawn sampling density. Preserve mobile MultiMesh
# batching, and restrain clover/ferns to avoid doubling decoration.
const SAMPLES_PER_CELL := 56
const TUFT_SPACING := CELL_SIZE / float(SAMPLES_PER_CELL)
const GRASS_DENSITY_MULTIPLIER := 1.96

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
    # Mix real Quaternius models. Most grass remains short; wispy blades and
    # clover form patches, while larger ferns are rare and grow at soft edges.
    # One MultiMesh per type/tile prevents thousands of individual draw calls.
    var model_names := ["Grass_Common_Short", "Grass_Wispy_Short", "Clover_1", "Fern_1"]
    var meshes: Array[ArrayMesh] = []
    var native_enabled := true
    for name in model_names:
        var imported := NatureReplacement.grass_mesh(name)
        if imported == null:
            native_enabled = false
            break
        meshes.append(imported)
    if not native_enabled:
        meshes.clear()
        meshes.append(_blade_mesh())
        model_names = ["ProceduralMeadowFallback"]

    var rng := RandomNumberGenerator.new()
    rng.seed = 20261011
    var totals := [0, 0, 0, 0]
    var tile_index := 0
    var all_batches := 0
    for tx in range(-26, 26, 8):
        for tz in range(-26, 26, 8):
            var transforms_by_type: Array = [[], [], [], []]
            var colors_by_type: Array = [[], [], [], []]
            for gx in range(SAMPLES_PER_CELL):
                for gz in range(SAMPLES_PER_CELL):
                    if rng.randf() < 0.012:
                        continue
                    var x := float(tx) + (float(gx) + 0.5) * TUFT_SPACING + rng.randf_range(-0.066, 0.066)
                    var z := float(tz) + (float(gz) + 0.5) * TUFT_SPACING + rng.randf_range(-0.066, 0.066)
                    if absf(x) > 25.7 or absf(z) > 23.5:
                        continue
                    # All four plants require *actual bare lawn* rather than
                    # roads, dirt shoulders or paved door approaches.
                    if float(ground_y.call(Vector3(x, 0.0, z))) > 0.012:
                        continue
                    if bool(blocked.call(Vector2(x, z))):
                        continue

                    var cluster := sin(x * 0.69 + cos(z * 0.31) * 1.2) * 0.42
                    cluster += cos(z * 0.57 - x * 0.19) * 0.38
                    cluster += sin((x + z) * 0.25) * 0.20
                    var is_edge := false
                    if native_enabled:
                        # Near foundations/hedges, choose occasional wilder
                        # vegetation rather than uniformly grooming the lawn.
                        is_edge = bool(blocked.call(Vector2(x + 0.38, z))) or bool(blocked.call(Vector2(x - 0.38, z)))
                    var roll := rng.randf()
                    var type_id := 0
                    if native_enabled:
                        if is_edge and roll < 0.0065 and cluster > -0.25:
                            type_id = 3
                        elif roll < (0.025 if cluster < 0.15 else 0.040):
                            type_id = 2
                        elif roll < (0.175 if cluster > 0.22 else 0.140):
                            type_id = 1
                        # Bigger fern footprint must also remain completely
                        # inside the grass and outside solid scenery.
                        if type_id == 3:
                            var fern_safe := true
                            for check in [Vector2(0.30, 0), Vector2(-0.30, 0), Vector2(0, 0.30), Vector2(0, -0.30)]:
                                var check_pos: Vector2 = Vector2(x, z) + (check as Vector2)
                                if bool(blocked.call(check_pos)) or float(ground_y.call(Vector3(check_pos.x, 0.0, check_pos.y))) > 0.012:
                                    fern_safe = false
                                    break
                            if not fern_safe:
                                type_id = 0

                    var jitter := rng.randf_range(0.84, 1.19)
                    var blade_height := rng.randf_range(0.83, 1.18)
                    var basis_scale := Vector3(jitter, blade_height, jitter)
                    if native_enabled:
                        match type_id:
                            0:
                                basis_scale *= Vector3(0.29, 0.145, 0.29)
                            1:
                                basis_scale *= Vector3(0.17, 0.177, 0.17)
                            2:
                                basis_scale *= Vector3(0.28, 0.118, 0.28)
                            3:
                                basis_scale *= Vector3(0.19, 0.56, 0.19)
                    var angle := rng.randf_range(0.0, TAU)
                    var basis := Basis(Vector3.UP, angle).scaled(basis_scale)
                    (transforms_by_type[type_id] as Array).append(
                        Transform3D(basis, Vector3(x - float(tx), 0.012, z - float(tz))))
                    var rich := 0.93 if cluster < -0.34 else (1.03 if cluster > 0.35 else 0.98)
                    (colors_by_type[type_id] as Array).append(Color(
                        rich * rng.randf_range(0.87, 1.02),
                        rng.randf_range(0.88, 1.05),
                        rng.randf_range(0.87, 1.02),
                        1.0
                    ))
            for kind in range(meshes.size()):
                var transforms: Array = transforms_by_type[kind]
                if transforms.is_empty():
                    continue
                var colors: Array = colors_by_type[kind]
                # Keep a random but deterministic order so lowering
                # visible_instance_count at a distance thins the WHOLE patch,
                # rather than cutting one side of the tile into a bare rectangle.
                for k in range(transforms.size() - 1, 0, -1):
                    var swap_index := rng.randi_range(0, k)
                    var previous_transform: Transform3D = transforms[k]
                    transforms[k] = transforms[swap_index]
                    transforms[swap_index] = previous_transform
                    var previous_color: Color = colors[k]
                    colors[k] = colors[swap_index]
                    colors[swap_index] = previous_color
                var batch := MultiMesh.new()
                batch.transform_format = MultiMesh.TRANSFORM_3D
                batch.use_colors = true
                batch.mesh = meshes[kind]
                batch.instance_count = transforms.size()
                for j in range(transforms.size()):
                    batch.set_instance_transform(j, transforms[j])
                    batch.set_instance_color(j, colors[j])
                var render := MultiMeshInstance3D.new()
                render.name = ("GrassField_" if kind == 0 else "MeadowAccent_%d_" % kind) + "%02d" % tile_index
                render.position = Vector3(float(tx), 0, float(tz))
                # Exact 8m tile centres for cheap runtime distance-based LOD.
                render.set_meta("meadow_center", Vector3(
                    float(tx) + CELL_SIZE * 0.5, 0.0, float(tz) + CELL_SIZE * 0.5))
                render.multimesh = batch
                render.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                town.add_child(render)
                all_batches += 1
                totals[kind] += transforms.size()
            tile_index += 1
    town.set_meta("grass_instance_count", totals[0] + totals[1] + totals[2] + totals[3])
    town.set_meta("grass_chunk_count", tile_index)
    town.set_meta("grass_draw_batches", all_batches)
    town.set_meta("grass_species_counts", totals)
    town.set_meta("grass_style", "quaternius_mixed_fantasy_meadow" if native_enabled else "soft_curved_meadow_grass")
    town.set_meta("grass_nature_model_loaded", native_enabled)
    town.set_meta("grass_spacing_m", TUFT_SPACING)
    town.set_meta("grass_sampling_per_cell", SAMPLES_PER_CELL)
    town.set_meta("grass_density_multiplier", GRASS_DENSITY_MULTIPLIER)
    town.set_meta("grass_density_goal", "approximately_double_common_and_wispy")
    town.set_meta("grass_coverage_pass", "dense_foundation_edges")
    town.set_meta("grass_source_tile_size_m", CELL_SIZE)
    town.set_meta("grass_blade_nominal_height_m", 0.184)
    return totals[0] + totals[1] + totals[2] + totals[3]
