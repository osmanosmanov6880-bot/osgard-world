shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// HORIZON R5 - world-scale original synthetic asphalt, no external licensed assets.
// High-end desktop and Compatibility share this shader; expensive SSR is gated by runtime.
uniform sampler2D aggregate_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D aggregate_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float rain_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float micro_strength : hint_range(0.0, 1.0) = 0.62;
varying vec3 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float smooth_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f*f*(3.0 - 2.0*f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)), u.x),
               mix(hash21(i + vec2(0.0,1.0)), hash21(i + vec2(1.0,1.0)), u.x), u.y);
}
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 tiled = world_position.xz * 0.38;
    float fine = smooth_noise(world_position.xz * 4.8);
    float body = smooth_noise(world_position.xz * 0.051);
    float fissure = smoothstep(0.915, 0.998, smooth_noise(world_position.xz * 0.17 + vec2(5.13,7.41)));
    float pool = rain_wetness * smoothstep(0.57,0.82,body);
    vec3 stone = texture(aggregate_albedo,tiled).rgb;
    stone *= (0.83 + 0.16*fine - 0.22*fissure);
    stone = mix(stone, stone * vec3(0.57,0.65,0.73), rain_wetness * (0.37 + 0.37*pool));
    ALBEDO = clamp(stone,vec3(0.014),vec3(0.93));
    NORMAL_MAP = texture(aggregate_normal,tiled).rgb;
    NORMAL_MAP_DEPTH = micro_strength * (1.0 - 0.74*pool);
    ROUGHNESS = clamp(0.79 + 0.10*fine - 0.58*pool - 0.09*rain_wetness, 0.12, 0.96);
    SPECULAR = mix(0.42,0.69,pool);
    METALLIC = 0.0;
}