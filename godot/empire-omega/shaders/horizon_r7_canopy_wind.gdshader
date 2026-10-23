shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// R7: small continuous branch-scale breeze on GPU-instanced leaf clusters.
// Instance vertex COLOR from MultiMesh encodes local foliage tone.
uniform float wind_strength : hint_range(0.0, 1.0) = 0.5;
uniform float wind_speed : hint_range(0.1, 3.5) = 0.64;
void vertex() {
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float wave = sin(TIME*wind_speed + p.x*.33 + p.z*.22);
    float gust = sin(TIME*.37 + p.x*.071 - p.z*.055);
    float head = clamp(UV.y*.7+.3,0.2,1.0);
    VERTEX.x += (wave*.045 + gust*.074)*wind_strength*head;
    VERTEX.z += (gust*.036 - wave*.024)*wind_strength*head;
}
void fragment() {
    ALBEDO = max(COLOR.rgb,vec3(.02)) * vec3(.78,.89,.80);
    ROUGHNESS = .92;
    SPECULAR = .18;
    METALLIC = 0.0;
}