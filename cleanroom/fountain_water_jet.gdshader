// Lightweight water-sheet pass. The Splash VFX pack's impact emitters
// can be attached to each jet endpoint independently.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
uniform vec4 water_color : source_color = vec4(0.42, 0.79, 0.88, 0.55);
uniform float flow_speed = 1.50;
varying vec2 water_uv;
void vertex() {
    water_uv = UV;
    float flow = sin(UV.y * 14.0 - TIME * flow_speed * 5.0 + UV.x * 7.0);
    VERTEX.x += flow * 0.007 * sin(UV.y * 3.14159);
}
void fragment() {
    float striation = sin(water_uv.x * 21.0 + sin(water_uv.y * 24.0 - TIME * flow_speed * 3.0) * 0.7);
    float highlight = pow(0.5 + 0.5 * striation, 3.0);
    float side_fade = smoothstep(0.0, 0.16, water_uv.x) * (1.0 - smoothstep(0.84, 1.0, water_uv.x));
    ALBEDO = mix(water_color.rgb, vec3(0.89, 0.96, 0.98), highlight * 0.40);
    ALPHA = water_color.a * side_fade * (0.68 + 0.32 * highlight);
}
