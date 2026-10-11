extends Node3D
## Mobile-friendly two-tier fountain water. Binbun's CC0 dual-layer scrolling
## water approach supplies the surface; each jet has a stable impact location
## where TomAzod's Splash VFX scenes can be substituted when source is present.
## Water visuals do NOT alter physics or third-person camera collision.
const WATER_SURFACE_SHADER = preload("res://fountain_water_surface.gdshader")
const WATER_JET_SHADER = preload("res://fountain_water_jet.gdshader")
const WATER_RIPPLE_SHADER = preload("res://fountain_water_ripple.gdshader")

const LOWER_WATER_Y := 0.435
const UPPER_WATER_Y := 1.602
const UPPER_RIM_Y := 1.62
const LOWER_BASIN_RADIUS := 1.20
const UPPER_BOWL_RADIUS := 0.555
const FLOW_START_RADIUS := 0.67
const FLOW_LANDING_RADIUS := 1.075
const JET_COUNT := 8
var _water_texture: NoiseTexture2D

func _ready() -> void:
    name = "FountainWaterEffects"
    _water_texture = NoiseTexture2D.new()
    _water_texture.width = 128
    _water_texture.height = 128
    _water_texture.seamless = true
    var noise := FastNoiseLite.new()
    noise.seed = 67028
    noise.frequency = 0.12
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _water_texture.noise = noise
    var surface_mat := ShaderMaterial.new()
    surface_mat.shader = WATER_SURFACE_SHADER
    surface_mat.set_shader_parameter("wave_texture", _water_texture)
    var lower := _add_water_disc("LowerBasinWater", LOWER_WATER_Y,
        LOWER_BASIN_RADIUS, surface_mat)
    lower.set_meta("water_pack_source", "Binbun_CC0_mobile_compatible")
    var upper := _add_water_disc("UpperBowlWater", UPPER_WATER_Y,
        UPPER_BOWL_RADIUS, surface_mat)
    upper.set_meta("water_pack_source", "Binbun_CC0_mobile_compatible")

    var jet_material := ShaderMaterial.new()
    jet_material.shader = WATER_JET_SHADER
    var impact_count := 0
    for jet_id in range(JET_COUNT):
        var angle := TAU * float(jet_id) / float(JET_COUNT)
        _add_cascade(jet_id, angle, jet_material)
        _add_ripple(jet_id, angle)
        impact_count += 1
    set_meta("water_realistic_animating", true)
    set_meta("water_mobile_compatible", true)
    set_meta("fountain_water_shader_author", "Binbun (CC0), mobile adaptation")
    set_meta("upper_and_lower_water_surfaces", 2)
    set_meta("cascade_count", JET_COUNT)
    set_meta("ripple_impact_count", impact_count)
    set_meta("splash_pack_hook", "TomAzod original ripple/pillar scene replacement")
    set_meta("water_effect_lod", "shader_only_low_draw_calls")


func _add_water_disc(label: String, height_y: float, radius: float,
        material: ShaderMaterial) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segments := 64
    # Radial tessellation supports small Binbun-style moving wave highlights.
    for sector in range(segments):
        var a0 := TAU * float(sector) / float(segments)
        var a1 := TAU * float(sector + 1) / float(segments)
        for point in [
            Vector2.ZERO, Vector2(cos(a1), sin(a1)), Vector2(cos(a0), sin(a0))
        ]:
            var p: Vector2 = point
            st.set_normal(Vector3.UP)
            st.set_uv(p * 0.5 + Vector2.ONE * 0.5)
            st.add_vertex(Vector3(p.x * radius, height_y, p.y * radius))
    var surface := MeshInstance3D.new()
    surface.name = label
    surface.mesh = st.commit()
    surface.material_override = material
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(surface)
    return surface


func _add_cascade(jet_id: int, angle: float, material: ShaderMaterial) -> void:
    # Eight flexible arc ribbons spill over the upper stone lip into the
    # main basin. The geometry is modest (12 strips per jet) and GPU animated.
    var outward := Vector3(cos(angle), 0.0, sin(angle))
    var sideways := Vector3(-sin(angle), 0.0, cos(angle))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segments := 12
    for segment in range(segments):
        var t0 := float(segment) / float(segments)
        var t1 := float(segment + 1) / float(segments)
        for pair in [[t0, -1.0], [t1, -1.0], [t1, 1.0],
            [t0, -1.0], [t1, 1.0], [t0, 1.0]]:
            var progress := float(pair[0])
            var across := float(pair[1])
            var radius := lerpf(FLOW_START_RADIUS, FLOW_LANDING_RADIUS,
                progress * progress)
            var arc_y := lerpf(UPPER_RIM_Y, LOWER_WATER_Y + 0.04,
                progress) + 0.035 * sin(progress * PI)
            var width := 0.047 + progress * 0.024
            var wobble := 0.008 * sin(progress * 8.0 + float(jet_id) * 1.7)
            var local := outward * (radius + wobble) + sideways * (across * width)
            local.y = arc_y
            st.set_uv(Vector2((across + 1.0) * 0.5, progress))
            st.add_vertex(local)
    var flow := MeshInstance3D.new()
    flow.name = "FountainCascade_%02d" % jet_id
    flow.mesh = st.commit()
    flow.material_override = material
    flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    flow.set_meta("impact_angle", angle)
    flow.set_meta("flow_from_upper_bowl", true)
    add_child(flow)


func _add_ripple(jet_id: int, angle: float) -> void:
    var mat := ShaderMaterial.new()
    mat.shader = WATER_RIPPLE_SHADER
    mat.set_shader_parameter("cycle_offset", float(jet_id % 3) / 3.0)
    var ripple := MeshInstance3D.new()
    ripple.name = "FountainImpactRipple_%02d" % jet_id
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(0.39, 0.39)
    ripple.mesh = mesh
    ripple.position = Vector3(cos(angle) * FLOW_LANDING_RADIUS,
        LOWER_WATER_Y + 0.018, sin(angle) * FLOW_LANDING_RADIUS)
    ripple.material_override = mat
    ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ripple.set_meta("splash_replacement_point", true)
    add_child(ripple)
