shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 0.7) = 0.22;
void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 color = texture(screen_tex, uv).rgb;
    float d = length((uv - vec2(0.5)) * vec2(1.35, 1.0));
    float vignette = 1.0 - strength * smoothstep(0.18, 0.74, d);
    COLOR = vec4(color * vignette, 1.0);
}
