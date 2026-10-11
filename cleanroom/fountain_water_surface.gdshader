// Fountain adaptation of Binbun "Water with Caustics" (CC0).
// https://godotshaders.com/shader/water-with-caustics/
// Android Compatibility renderer: small basins don't need screen refraction
// or caustics. Keep dual scrolling wave layers, colour depth and foam.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D wave_texture : repeat_enable, filter_linear;
uniform vec4 shallow_color : source_color = vec4(0.27, 0.65, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.10, 0.31, 0.44, 1.0);
uniform vec4 foam_color : source_color = vec4(0.82, 0.95, 0.94, 1.0);
uniform float wave_scale = 1.55;
uniform float animation_speed = 0.17;
uniform float displacement = 0.013;
uniform float transparency : hint_range(0.0, 1.0) = 0.86;

varying vec2 water_uv;
void vertex() {
    water_uv = UV * wave_scale;
    float wave_a = textureLod(wave_texture, water_uv + vec2(TIME * animation_speed, -TIME * animation_speed * 0.53), 0.0).r;
    float wave_b = textureLod(wave_texture, water_uv * 1.43 - vec2(TIME * animation_speed * 0.54, TIME * animation_speed * 0.41), 0.0).r;
    VERTEX.y += ((wave_a + wave_b) - 1.0) * displacement;
}
void fragment() {
    float a = texture(wave_texture, water_uv + vec2(TIME * animation_speed, 0.0)).r;
    float b = texture(wave_texture, water_uv * 1.43 - vec2(TIME * animation_speed * 0.56, TIME * animation_speed * 0.33)).r;
    float wave = mix(a, b, 0.48);
    float highlight = smoothstep(0.63, 0.87, wave);
    vec3 colour = mix(deep_color.rgb, shallow_color.rgb, 0.54 + wave * 0.34);
    colour = mix(colour, foam_color.rgb, highlight * 0.27);
    // A soft rim / thin foam line, never an opaque white disc.
    float edge = max(abs(UV.x - 0.5), abs(UV.y - 0.5));
    colour = mix(colour, foam_color.rgb, smoothstep(0.40, 0.50, edge) * 0.06);
    ALBEDO = colour;
    METALLIC = 0.02;
    ROUGHNESS = 0.16;
    SPECULAR = 0.70;
    ALPHA = transparency;
}
