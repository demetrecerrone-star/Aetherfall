extends RefCounted
## Batches the staggered cut-ashlar skin of BOTH gate towers into one
## mobile-friendly draw surface; never adds a new collision or camera shape.
const RADIUS := 2.30
const STONE_RADIUS := 2.36
const COURSE_COUNT := 13
const BLOCKS_PER_COURSE := 18
const TOWER_HEIGHT := 5.85
const CENTER_Z := 24.6

static func _point(tower_x: float, angle: float, y: float, radius: float) -> Vector3:
    return Vector3(tower_x + cos(angle) * radius, y,
        CENTER_Z + sin(angle) * radius)

static func _face(tool: SurfaceTool, center_x: float, points: Array[Vector3],
        color: Color) -> void:
    # Vertex normals are radial, producing subtle natural shading along
    # chamfered stone edges while the darker underlying cylinder reads as
    # mortar in the narrow horizontal and vertical joints.
    for index in [0, 1, 2, 0, 2, 3]:
        var vertex: Vector3 = points[index]
        var normal := Vector3(vertex.x - center_x, 0.0,
            vertex.z - CENTER_Z).normalized()
        tool.set_normal(normal)
        tool.set_color(color)
        tool.add_vertex(vertex)

static func build(town: Node3D) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var shades := [
        Color("#999b98"), Color("#b0ada5"), Color("#a29f98"),
        Color("#888e8d"), Color("#a7a9a2"), Color("#969b98")
    ]
    var angle_step := TAU / float(BLOCKS_PER_COURSE)
    var course_height := TOWER_HEIGHT / float(COURSE_COUNT)
    var block_count := 0
    for tower_x in [-4.1, 4.1]:
        var center_x: float = float(tower_x)
        for course in range(COURSE_COUNT):
            var lower := float(course) * course_height + 0.018
            var upper := float(course + 1) * course_height - 0.018
            var shift := 0.5 * angle_step if course % 2 == 1 else 0.0
            for block in range(BLOCKS_PER_COURSE):
                var angle_start := float(block) * angle_step + shift + 0.014
                var angle_end := float(block + 1) * angle_step + shift - 0.014
                var face_start := angle_start + 0.019
                var face_end := angle_end - 0.019
                var body_bottom := lower + 0.025
                var body_top := upper - 0.025
                var shade_index := (course * 7 + block * 11 + int(absf(center_x))) % shades.size()
                var color: Color = shades[shade_index]
                # Main dressed face is flat-ish with chamfered margins.
                _face(tool, center_x, [
                    _point(center_x, face_start, body_bottom, STONE_RADIUS),
                    _point(center_x, face_end, body_bottom, STONE_RADIUS),
                    _point(center_x, face_end, body_top, STONE_RADIUS),
                    _point(center_x, face_start, body_top, STONE_RADIUS)
                ], color)
                var beveled := color.darkened(0.18)
                var lip_radius := RADIUS + 0.022
                _face(tool, center_x, [
                    _point(center_x, angle_start, lower, lip_radius),
                    _point(center_x, angle_end, lower, lip_radius),
                    _point(center_x, face_end, body_bottom, STONE_RADIUS),
                    _point(center_x, face_start, body_bottom, STONE_RADIUS)
                ], beveled)
                _face(tool, center_x, [
                    _point(center_x, face_start, body_top, STONE_RADIUS),
                    _point(center_x, face_end, body_top, STONE_RADIUS),
                    _point(center_x, angle_end, upper, lip_radius),
                    _point(center_x, angle_start, upper, lip_radius)
                ], color.lightened(0.12))
                _face(tool, center_x, [
                    _point(center_x, angle_start, lower, lip_radius),
                    _point(center_x, face_start, body_bottom, STONE_RADIUS),
                    _point(center_x, face_start, body_top, STONE_RADIUS),
                    _point(center_x, angle_start, upper, lip_radius)
                ], beveled)
                _face(tool, center_x, [
                    _point(center_x, face_end, body_bottom, STONE_RADIUS),
                    _point(center_x, angle_end, lower, lip_radius),
                    _point(center_x, angle_end, upper, lip_radius),
                    _point(center_x, face_end, body_top, STONE_RADIUS)
                ], beveled)
                block_count += 1
    var mesh := tool.commit()
    if mesh == null:
        push_error("Failed to build cut-stone gate courses")
        return
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.metallic = 0.0
    mesh.surface_set_material(0, mat)
    var render := MeshInstance3D.new()
    render.name = "GateChiseledAshlar"
    render.mesh = mesh
    render.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    town.add_child(render)
    town.set_meta("gate_ashlar_block_count", block_count)
    town.set_meta("gate_tower_material", "staggered_chiseled_ashlar")
