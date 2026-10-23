shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Vertex displacement is procedural and bounded; no skeletal/CPU animation overhead.
uniform float wind_speed : hint_range(0.1,4.0) = 1.0;
uniform float wind_strength : hint_range(0.0,1.0) = 0.45;
varying float blade_height;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    blade_height = clamp(UV.y,0.0,1.0);
    float gust = sin(TIME*wind_speed+p.x*0.21+p.z*0.33) * 0.7
               + sin(TIME*0.43+p.x*0.09-p.z*0.14) * 0.3;
    VERTEX.x += gust * wind_strength * 0.19 * blade_height;
    VERTEX.z += gust * wind_strength * 0.11 * blade_height;
}
void fragment() {
    ALBEDO = mix(vec3(0.08,0.17,0.10),vec3(0.21,0.33,0.17),blade_height);
    ROUGHNESS = 0.91;
    SPECULAR = 0.19;
    METALLIC = 0.0;
}