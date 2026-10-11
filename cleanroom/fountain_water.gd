extends Node3D
## Quiet, three-tier water for the user's original medieval fountain.
## Actual bowl elevations were measured from the supplied GLB at x3.55:
## lower basin ~0.44m, middle basin ~1.60m, top bowl rim ~2.40m.
## Binbun-inspired animated water surfaces and lightweight small ripples
## are GPU shader-driven. No hanging water streams or particle systems.
## Never changes camera, fountain position/size or player collision.
const WATER_SURFACE_SHADER = preload("res://fountain_water_surface.gdshader")
const WATER_RIPPLE_SHADER = preload("res://fountain_water_ripple.gdshader")

const LOWER_WATER_Y := 0.435
const MIDDLE_WATER_Y := 1.602
const TOP_WATER_Y := 2.345
const LOWER_BASIN_RADIUS := 1.20
const MIDDLE_BOWL_RADIUS := 0.555
const TOP_BOWL_RADIUS := 0.30

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

    # Each pool uses its own material settings but shares one small generated
    # noise texture. Strong flow/jet effects are intentionally absent.
    var lower := _add_water_disc("LowerBasinWater", LOWER_WATER_Y,
        LOWER_BASIN_RADIUS, _surface_material(1.35, 0.08))
    var middle := _add_water_disc("UpperBowlWater", MIDDLE_WATER_Y,
        MIDDLE_BOWL_RADIUS, _surface_material(1.65, 0.09))
    var top := _add_water_disc("TopBowlWater", TOP_WATER_Y,
        TOP_BOWL_RADIUS, _surface_material(2.10, 0.06))
    for water in [lower, middle, top]:
        water.set_meta("water_pack_source", "Binbun_CC0_mobile_compatible")
        water.set_meta("water_motion", "calm")
        water.set_meta("water_surface_displacement_m", 0.004)

    # Three gentle rings in the lower basin, two in the middle and one
    # in the tiny top bowl. No splashes implying a falling water stream.
    _add_ripple("Lower", 0, LOWER_WATER_Y, Vector2(-0.43, 0.38), 0.38, 0.04)
    _add_ripple("Lower", 1, LOWER_WATER_Y, Vector2(0.50, -0.23), 0.32, 0.44)
    _add_ripple("Lower", 2, LOWER_WATER_Y, Vector2(0.11, 0.70), 0.28, 0.74)
    _add_ripple("Middle", 0, MIDDLE_WATER_Y, Vector2(0.21, 0.12), 0.22, 0.20)
    _add_ripple("Middle", 1, MIDDLE_WATER_Y, Vector2(-0.22, -0.14), 0.20, 0.67)
    _add_ripple("Top", 0, TOP_WATER_Y, Vector2(0.12, -0.04), 0.12, 0.48)

    set_meta("water_realistic_animating", true)
    set_meta("water_mobile_compatible", true)
    set_meta("fountain_water_shader_author", "Binbun-inspired mobile adaptation")
    set_meta("upper_and_lower_water_surfaces", 3)
    set_meta("filled_tier_count", 3)
    set_meta("cascade_count", 0)
    set_meta("ripple_impact_count", 0)
    set_meta("gentle_ripple_count", 6)
    set_meta("three_tier_water_layout", "lower_middle_top")
    set_meta("water_effect_lod", "calm_shader_only_no_streams")
    set_meta("water_measured_from_glb", true)


func _surface_material(wave_scale: float, speed: float) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = WATER_SURFACE_SHADER
    material.set_shader_parameter("wave_texture", _water_texture)
    material.set_shader_parameter("wave_scale", wave_scale)
    material.set_shader_parameter("animation_speed", speed)
    material.set_shader_parameter("displacement", 0.004)
    material.set_shader_parameter("transparency", 0.90)
    return material


func _add_water_disc(label: String, height_y: float, radius: float,
        material: ShaderMaterial) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Flat, circular water plane tucked inside stone rims (not squares).
    # Fine triangulation is unnecessary with calmer shader displacement.
    var segments := 48
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
    surface.set_meta("water_level_m", height_y)
    surface.set_meta("water_radius_m", radius)
    add_child(surface)
    return surface


func _add_ripple(tier: String, index: int, height_y: float,
        offset: Vector2, size: float, phase_offset: float) -> void:
    var mat := ShaderMaterial.new()
    mat.shader = WATER_RIPPLE_SHADER
    mat.set_shader_parameter("cycle_offset", phase_offset)
    mat.set_shader_parameter("foam_tint", Color(0.73, 0.92, 0.96, 0.23))
    var ripple := MeshInstance3D.new()
    ripple.name = "FountainCalmRipple_%s_%02d" % [tier, index]
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(size, size)
    ripple.mesh = mesh
    ripple.position = Vector3(offset.x, height_y + 0.012, offset.y)
    ripple.material_override = mat
    ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ripple.set_meta("tier", tier)
    ripple.set_meta("ripple_style", "subtle_nonimpact")
    add_child(ripple)
