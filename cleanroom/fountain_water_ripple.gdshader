// Lightweight fallback impact ripples. Original TomAzod splash scene
// can replace these nodes without changing the fountain's coordinates.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform vec4 foam_tint : source_color = vec4(0.80, 0.96, 0.98, 0.50);
uniform float cycle_offset = 0.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float radius = length(p);
    float phase = fract(TIME * 0.53 + cycle_offset);
    float outer = phase * 0.88 + 0.08;
    float ring = 1.0 - smoothstep(0.010, 0.045, abs(radius - outer));
    float inner = 1.0 - smoothstep(0.010, 0.040, abs(radius - (outer * 0.67)));
    ALBEDO = foam_tint.rgb;
    ALPHA = max(ring * (1.0 - phase), inner * (1.0 - phase) * 0.30) * foam_tint.a;
}
