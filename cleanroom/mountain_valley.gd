extends RefCounted
## Pass 3: mobile-conscious valley cliffs and a fully opaque timber palisade.
## Landscape is only rendered immediately beyond the town's playable walls.
## No exterior world needs to exist until its zone is authored.
const VALLEY_TOWN_LIMIT := 26.85
const LOG_RADIUS := 0.29
const LOG_SPACING := 0.49
const LOG_HEIGHT := 3.55
const TIP_HEIGHT := 0.55

static func _side_point(edge: String, t: float, band: int) -> Vector3:
    var distances := [0.0, 2.0, 4.8, 9.4, 16.2]
    var elevation := [0.0, 3.2, 9.8, 19.0, 11.0]
    var d := float(distances[band])
    var ripple := sin(t * 14.2 + float(band) * 1.8) * 1.12
    ripple += cos(t * 31.0 + float(band) * 2.9) * 0.57
    var summit := (sin(t * 9.3 + 1.20) + cos(t * 22.5 - 0.45)) * 3.3
    var y := float(elevation[band]) + ripple * float(band) * 0.48 + summit * float(band) * 0.18
    y = maxf(0.0, y)
    if edge == "north":
        return Vector3(lerpf(-34.0, 34.0, t), y, -25.0 - d)
    if edge == "west":
        return Vector3(-27.0 - d, y, lerpf(-27.0, 27.0, t))
    return Vector3(27.0 + d, y, lerpf(-27.0, 27.0, t))

static func _cliff(town: Node3D, side: String, rock_texture: Texture2D) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#aba99f")
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    if rock_texture != null:
        material.albedo_texture = rock_texture
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segment_count := 30 if side == "north" else 24
    var tones := [
        Color("#888d7f"), Color("#969a8b"), Color("#8b8d86"),
        Color("#b8b1a2"), Color("#939b98")
    ]
    for seg in range(segment_count):
        var t0 := float(seg) / float(segment_count)
        var t1 := float(seg + 1) / float(segment_count)
        for band in range(4):
            var a := _side_point(side, t0, band)
            var b := _side_point(side, t1, band)
            var c := _side_point(side, t0, band + 1)
            var d := _side_point(side, t1, band + 1)
            var tint: Color = tones[band] * (0.95 + 0.06 * sin(float(seg) * 2.30 + float(band)))
            tint.a = 1.0
            for corner in [a, c, b, b, c, d]:
                builder.set_color(tint)
                builder.set_uv(Vector2(
                    corner.x * 0.14 + corner.z * 0.04,
                    corner.y * 0.13 + corner.z * 0.035
                ))
                builder.add_vertex(corner)
    builder.generate_normals()
    var mesh := builder.commit()
    mesh.surface_set_material(0, material)
    var geometry := MeshInstance3D.new()
    geometry.name = "ValleyCliffs_" + side
    geometry.mesh = mesh
    geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    town.add_child(geometry)

static func _log_material(wood_texture: Texture2D, tint: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.98
    if wood_texture != null:
        material.albedo_texture = wood_texture
        material.uv1_scale = Vector3(1.0, 1.0, 1.0)
    return material

static func _palisade_positions() -> Array[Vector3]:
    var positions: Array[Vector3] = []
    for side in [-1, 1]:
        var x := float(side) * 26.67
        var z := -24.65
        while z <= 24.65:
            positions.append(Vector3(x, 0.0, z))
            z += LOG_SPACING
    var x_back := -26.65
    while x_back <= 26.65:
        positions.append(Vector3(x_back, 0, -24.67))
        x_back += LOG_SPACING
    # Front palisade ends flush against the solid wooden gate/watch towers.
    for left in [true, false]:
        var x_front := -26.65 if left else 6.42
        var x_end := -6.42 if left else 26.65
        while x_front <= x_end:
            positions.append(Vector3(x_front, 0.0, 24.64))
            x_front += LOG_SPACING
    return positions

static func _palisades(town: Node3D, wood_texture: Texture2D) -> int:
    var posts := _palisade_positions()
    var log := CylinderMesh.new()
    log.top_radius = LOG_RADIUS
    log.bottom_radius = LOG_RADIUS * 1.04
    log.height = LOG_HEIGHT
    log.radial_segments = 7
    var pointed := CylinderMesh.new()
    pointed.top_radius = 0.0
    pointed.bottom_radius = LOG_RADIUS
    pointed.height = TIP_HEIGHT
    pointed.radial_segments = 7
    for shape in ["post", "point"]:
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = log if shape == "post" else pointed
        multi.instance_count = posts.size()
        for i in range(posts.size()):
            var pos := posts[i]
            var center_y := LOG_HEIGHT * 0.5 if shape == "post" else LOG_HEIGHT + TIP_HEIGHT * 0.5
            var transform := Transform3D(Basis.IDENTITY,
                pos + Vector3(0, center_y, 0))
            multi.set_instance_transform(i, transform)
        var display := MultiMeshInstance3D.new()
        display.name = "ValleyTimberPalisade" if shape == "post" else "ValleyTimberPointedTips"
        display.multimesh = multi
        display.material_override = _log_material(wood_texture, Color("#92704e") if shape == "post" else Color("#765437"))
        display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        town.add_child(display)
    return posts.size()

static func _beam(town: Node3D, center: Vector3, size: Vector3, wood_texture: Texture2D) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var board := MeshInstance3D.new()
    board.name = "ValleyTimberCrossbrace"
    board.mesh = mesh
    board.position = center
    board.material_override = _log_material(wood_texture, Color("#715238"))
    board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    town.add_child(board)

static func _supports(town: Node3D, wood_texture: Texture2D) -> void:
    # Strong horizontal crossbeams, visible from town interior.
    for side in [-1, 1]:
        var x := float(side) * 26.15
        for h in [1.06, 2.65]:
            _beam(town, Vector3(x, float(h), 0.0),
                Vector3(0.16, 0.22, 48.8), wood_texture)
        for z in range(-21, 23, 7):
            _beam(town, Vector3(x + float(side) * 0.05, 1.94, float(z)),
                Vector3(0.47, 3.85, 0.50), wood_texture)
    for h in [1.06, 2.65]:
        _beam(town, Vector3(0.0, float(h), -24.10), Vector3(52.8, 0.22, 0.16), wood_texture)
    for x in range(-22, 23, 7):
        _beam(town, Vector3(float(x), 1.94, -24.12),
            Vector3(0.50, 3.85, 0.47), wood_texture)
    for x in [-16.0, 16.0]:
        for h in [1.06, 2.65]:
            _beam(town, Vector3(x, float(h), 24.10),
                Vector3(19.6, 0.22, 0.16), wood_texture)

static func build(town: Node3D, rock_texture: Texture2D, timber_texture: Texture2D) -> void:
    for side in ["north", "west", "east"]:
        _cliff(town, side, rock_texture)
    var count := _palisades(town, timber_texture)
    _supports(town, timber_texture)
    town.set_meta("perimeter_style", "mountain_valley_timber_palisade")
    town.set_meta("valley_cliff_count", 3)
    town.set_meta("valley_palisade_posts", count)
    town.set_meta("valley_external_zone_rendered", false)
