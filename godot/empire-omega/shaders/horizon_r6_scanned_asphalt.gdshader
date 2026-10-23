shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// R6 desktop original photogrammetry from CC0 Poly Haven. Not procedural noise.
// Wetness is updated by existing R5 weather; measured per 2 m surface span.
uniform sampler2D aggregate_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D aggregate_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float rain_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float micro_strength : hint_range(0.0, 1.0) = 0.7;
uniform float tile_meters = 2.0;
uniform float puddle_strength : hint_range(0.0, 1.0) = 0.45;
varying vec3 world_position;

float hash21(vec2 x) {
    vec3 p = fract(vec3(x.xyx) * .1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise21(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1.,0.)),f.x),
               mix(hash21(i+vec2(0.,1.)),hash21(i+vec2(1.)),f.x),f.y);
}
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec2 uv_world = world_position.xz / max(tile_meters,0.2);
    float moisture = rain_wetness;
    float macro_pool = smoothstep(.43,.67,noise21(world_position.xz*.031 + vec2(13.1,7.2)));
    float pool = moisture*puddle_strength*macro_pool;
    float stone = noise21(world_position.xz*3.0);
    vec3 photographic = texture(aggregate_albedo,uv_world).rgb;
    float gravel = noise21(world_position.xz*.052);
    photographic *= 0.93 + .09*stone + .09*(gravel-.5);
    photographic = mix(photographic,photographic*vec3(.52,.60,.69),clamp(.23*moisture + pool*.52,0.0,.7));
    ALBEDO = photographic;
    NORMAL_MAP = texture(aggregate_normal,uv_world).rgb;
    NORMAL_MAP_DEPTH = micro_strength*(1.0-.76*pool);
    float scanned_rough = texture(roughness_map,uv_world).r;
    ROUGHNESS = clamp(scanned_rough*.94+.035-.12*moisture-.69*pool,.09,.98);
    SPECULAR = mix(.44,.72,pool);
    METALLIC = 0.0;
}