shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 resolution_px = vec2(1600.0,900.0);
uniform float grain : hint_range(0.0,0.03) = 0.008;
uniform float vignette : hint_range(0.0,0.4) = 0.105;
uniform float halation : hint_range(0.0,0.1) = 0.022;
uniform float chromatic_dispersion : hint_range(0.0,0.002) = 0.00015;
uniform float contrast : hint_range(0.8,1.25) = 1.02;
uniform float saturation : hint_range(0.8,1.2) = 0.975;
uniform float exposure_ev : hint_range(-1.5,1.5) = 0.0;
uniform float highlight_compression : hint_range(0.0,0.6) = 0.22;
uniform float halation_threshold : hint_range(0.4,2.0) = 0.92;
uniform bool cinematic_effects = true;
float noise2(vec2 p){
  vec3 a=fract(vec3(p.xyx)*.1031);
  a+=dot(a,a.yzx+33.33);
  return fract((a.x+a.y)*a.z);
}
void fragment(){
  vec2 uv=SCREEN_UV;
  vec3 c=texture(screen_texture,uv).rgb;
  if(!cinematic_effects){COLOR=vec4(c,1.0);return;}
  // Separate broad luminance bloom from primary detail; avoid hazing middle greys.
  vec3 low=textureLod(screen_texture,uv,4.0).rgb;
  c+=max(low-vec3(halation_threshold),vec3(0.0))*halation;
  vec2 center=uv-vec2(.5);
  vec2 offset=normalize(center+vec2(.00001))*dot(center,center)*chromatic_dispersion;
  c=vec3(texture(screen_texture,clamp(uv+offset,vec2(.001),vec2(.999))).r,
         c.g,texture(screen_texture,clamp(uv-offset,vec2(.001),vec2(.999))).b);
  c*=exp2(exposure_ev);
  // Soft shoulder for highlights, preserving contrast in the middle values.
  vec3 hi=max(c-vec3(.64),vec3(0.0));
  c-=highlight_compression*hi*hi/(vec3(1.0)+hi);
  float luminance=dot(c,vec3(.2126,.7152,.0722));
  c=mix(vec3(luminance),c,saturation);
  c=(c-.5)*contrast+.5;
  float aspect=resolution_px.x/max(resolution_px.y,1.0);
  float vignette_r=length(center*vec2(aspect,1.0));
  c*=1.0-smoothstep(.28,1.1,vignette_r)*vignette;
  vec2 pixel=floor(uv*resolution_px)+floor(TIME*24.0);
  float film=(noise2(pixel)-.5)*grain*(1.0-.4*smoothstep(.75,1.2,luminance));
  COLOR=vec4(clamp(c+vec3(film),vec3(0.0),vec3(1.0)),1.0);
}
