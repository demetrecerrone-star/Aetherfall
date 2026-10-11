extends RefCounted
## Seamless medieval cobblestone network for GL Compatibility/mobile.
## Instead of overlapping roads, each paved area is unioned into a single
## row-merged surface with global UVs. A narrow dirt-to-grass verge follows
## every exposed path edge. Both surfaces remain non-colliding, and grounding
## samples the identical road footprint.
const GRID_STEP := 0.25
const MIN_X := -26.0
const MAX_X := 26.0
const MIN_Z := -24.0
const MAX_Z := 24.0
const COBBLE_HEIGHT := 0.066
const BORDER_HEIGHT := 0.020
const BORDER_WIDTH := 0.27
const COBBLE_METERS_PER_TILE := 2.40
const DIRT_METERS_PER_TILE := 2.25

static func plan(door_anchors: Array[Vector2]) -> Array[Rect2]:
    var regions: Array[Rect2] = []
    # One continuous route from the front gate to the square.
    regions.append(Rect2(Vector2(-2.95, -20.0), Vector2(5.90, 44.0)))
    # East-west spine, linked to the gate road and all village side lanes.
    regions.append(Rect2(Vector2(-21.0, -1.60), Vector2(42.0, 5.00)))
    # Broad market plaza: vendors remain inside, the middle stays walkable.
    regions.append(Rect2(Vector2(-8.0, -11.0), Vector2(16.0, 14.4)))
    for point in door_anchors:
        # Routes run along the FRONT of the facade, never through a house.
        # Gate-side homes share a high front lane across the south end of
        # town; blacksmith and other streets join the central entry road.
        # For back-of-town cottages, the lateral spur stays in front of the
        # guild so houses never block one another.
        var lane_z := point.y + 0.85
        if point.y > 13.0:
            lane_z = maxf(20.55, lane_z)
        lane_z = minf(lane_z, 22.5)
        var min_z := minf(point.y - 0.25, lane_z)
        var max_z := maxf(point.y + 0.55, lane_z)
        regions.append(Rect2(Vector2(point.x - 1.00, min_z),
            Vector2(2.00, maxf(max_z - min_z, 0.85))))
        # East-west connection to the central gate road, which already spans
        # the entire village. Its route remains beside, not under, homes.
        var min_x := minf(0.0, point.x)
        var max_x := maxf(0.0, point.x)
        regions.append(Rect2(Vector2(min_x, lane_z - 1.00),
            Vector2(maxf(max_x - min_x, 0.8), 2.00)))
        regions.append(Rect2(Vector2(point.x - 1.24, point.y - 0.30),
            Vector2(2.48, 0.80)))
    return regions

static func _contains(regions: Array[Rect2], point: Vector2) -> bool:
    for region in regions:
        if region.has_point(point):
            return true
    return false

static func surface_height(point: Vector2, regions: Array[Rect2]) -> float:
    if _contains(regions, point):
        return COBBLE_HEIGHT
    for region in regions:
        if region.grow(BORDER_WIDTH).has_point(point):
            return BORDER_HEIGHT
    return 0.0

static func _emit_quad(tool: SurfaceTool, start_x: float, end_x: float, start_z: float, end_z: float, height: float, tile_size: float) -> void:
    # Counterclockwise winding from above (visible top face, upward normal).
    var p0 := Vector3(start_x, height, start_z)
    var p1 := Vector3(start_x, height, end_z)
    var p2 := Vector3(end_x, height, start_z)
    var p3 := Vector3(end_x, height, end_z)
    # Godot's clockwise-front SurfaceTool convention is the reverse of
    # the old top-down order. The previous quads were back-face culled from
    # above on Android, so road collisions existed but the paving vanished.
    for vertex in [p0, p2, p1, p2, p3, p1]:
        tool.set_normal(Vector3.UP)
        tool.set_uv(Vector2(vertex.x / tile_size, vertex.z / tile_size))
        tool.add_vertex(vertex)

static func _surface(town: Node3D, name: String, regions: Array[Rect2], material: StandardMaterial3D, is_border: bool) -> int:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var expanded: Array[Rect2] = []
    if is_border:
        for region in regions:
            expanded.append(region.grow(BORDER_WIDTH))
    var cols := int(roundf((MAX_X - MIN_X) / GRID_STEP))
    var rows := int(roundf((MAX_Z - MIN_Z) / GRID_STEP))
    var quad_count := 0
    for zi in range(rows):
        var z0 := MIN_Z + float(zi) * GRID_STEP
        var z1 := z0 + GRID_STEP
        var center_z := (z0 + z1) * 0.5
        var run_start := -1
        for xi in range(cols + 1):
            var belongs := false
            if xi < cols:
                var x := MIN_X + (float(xi) + 0.5) * GRID_STEP
                var probe := Vector2(x, center_z)
                var paved := _contains(regions, probe)
                belongs = (not paved and _contains(expanded, probe)) if is_border else paved
            if belongs and run_start < 0:
                run_start = xi
            elif not belongs and run_start >= 0:
                var x0 := MIN_X + float(run_start) * GRID_STEP
                var x1 := MIN_X + float(xi) * GRID_STEP
                _emit_quad(tool, x0, x1, z0, z1,
                    BORDER_HEIGHT if is_border else COBBLE_HEIGHT,
                    DIRT_METERS_PER_TILE if is_border else COBBLE_METERS_PER_TILE)
                quad_count += 1
                run_start = -1
    if quad_count == 0:
        return 0
    var mesh := tool.commit()
    mesh.surface_set_material(0, material)
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    town.add_child(instance)
    return quad_count

static func build(town: Node3D, regions: Array[Rect2], cobble_material: StandardMaterial3D, dirt_material: StandardMaterial3D) -> void:
    # The UVs are defined in town/world coordinates so different road widths
    # share one continuous stone pattern, including every doorstep.
    cobble_material.uv1_scale = Vector3.ONE
    dirt_material.uv1_scale = Vector3.ONE
    # Safeguard against platform-specific winding/culling differences in
    # GL Compatibility so a future geometry refactor cannot erase the roads.
    cobble_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    dirt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var cobble_quads := _surface(town, "UnifiedCobblestoneRoad", regions, cobble_material, false)
    var verge_quads := _surface(town, "UnifiedDirtRoadVerge", regions, dirt_material, true)
    town.set_meta("road_style", "weathered_medieval_cobblestone")
    town.set_meta("road_network_segments", regions.size())
    town.set_meta("road_surface_height_m", COBBLE_HEIGHT)
    town.set_meta("road_paving_quad_count", cobble_quads)
    town.set_meta("road_border_quad_count", verge_quads)
