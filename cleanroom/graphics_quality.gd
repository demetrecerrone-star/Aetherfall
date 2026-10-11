extends RefCounted
## Runtime 3D quality options for Android/GL Compatibility.
## Assets, terrain, collisions and near-player doubled foliage stay intact.
## Far grass is sampled at lower detail by changing the MultiMesh draw count,
## never by deleting meshes or changing the stored instance_count.
const QUALITY := "QUALITY"
const BALANCED := "BALANCED"
const PERFORMANCE := "PERFORMANCE"
const SAVE_PATH := "user://aetherfall_graphics.cfg"

static func valid(name: String) -> bool:
    return name in [PERFORMANCE, BALANCED, QUALITY]


static func restored() -> String:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return BALANCED
    var saved: String = str(config.get_value("graphics", "preset", BALANCED))
    return saved if valid(saved) else BALANCED


static func save(name: String) -> void:
    if not valid(name):
        return
    var config := ConfigFile.new()
    config.set_value("graphics", "preset", name)
    var result := config.save(SAVE_PATH)
    if result != OK:
        push_warning("Could not persist graphics preset: %d" % result)


static func resolution_scale(name: String) -> float:
    match name:
        PERFORMANCE:
            return 0.72
        BALANCED:
            return 0.87
        _:
            return 1.0


static func shadow_atlas_size(name: String) -> int:
    match name:
        PERFORMANCE:
            return 1024
        BALANCED:
            return 2048
        _:
            return 4096


# Godot's directional shadow filter quality is global. The old starter town
# forced SOFT_HIGH even when 3D rendering was scaled down to PERFORMANCE.
# Retain pleasantly blurred shadows, but cut filtering samples on mobile.
static func shadow_filter_quality(name: String) -> RenderingServer.ShadowQuality:
    match name:
        PERFORMANCE:
            return RenderingServer.SHADOW_QUALITY_SOFT_LOW
        BALANCED:
            return RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
        _:
            return RenderingServer.SHADOW_QUALITY_SOFT_HIGH


static func apply(name: String, viewport: Viewport, sun: DirectionalLight3D) -> void:
    if not valid(name):
        return
    # Bilinear is supported in GL Compatibility. Only the 3D buffer is scaled:
    # landscape-mode joystick, labels and graphics buttons remain full-res.
    viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
    viewport.scaling_3d_scale = resolution_scale(name)
    RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size(name), true)
    RenderingServer.directional_soft_shadow_filter_set_quality(shadow_filter_quality(name))
    if sun != null:
        sun.shadow_enabled = true
        sun.directional_shadow_mode = (
            DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if name == QUALITY
            else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
        sun.directional_shadow_max_distance = (
            38.0 if name == QUALITY else (32.0 if name == BALANCED else 24.0))
        sun.shadow_blur = 2.0 if name == QUALITY else (1.5 if name == BALANCED else 1.0)


static func target_visible_fraction(name: String, distance: float) -> float:
    # Full native density around the character on ALL settings.
    # Gradually simplify only grass farther away (not flowers, trees, bushes,
    # ground materials or scene geometry).
    if name == QUALITY:
        return 1.0
    if name == BALANCED:
        if distance < 14.0:
            return 1.0
        if distance < 23.0:
            return 0.72
        if distance < 34.0:
            return 0.48
        return 0.32
    if distance < 12.0:
        return 1.0
    if distance < 20.0:
        return 0.62
    if distance < 30.0:
        return 0.38
    return 0.23


static func apply_meadow_lod(batches: Array[Dictionary], position: Vector3,
        name: String) -> Dictionary:
    var total := 0
    var drawn := 0
    for entry in batches:
        var node := entry["node"] as MultiMeshInstance3D
        if not is_instance_valid(node) or node.multimesh == null:
            continue
        var count: int = entry["full_count"]
        var tile_center: Vector3 = entry["center"]
        var horizontal_distance := Vector2(
            position.x - tile_center.x, position.z - tile_center.z).length()
        var wanted := count if name == QUALITY else (
            maxi(1, roundi(float(count) * target_visible_fraction(name, horizontal_distance))))
        if node.multimesh.visible_instance_count != wanted:
            node.multimesh.visible_instance_count = wanted
        total += count
        drawn += wanted
    return {"total": total, "drawn": drawn}
