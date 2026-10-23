extends CanvasLayer
## R11 Compatibility/WebGL-screen postprocessing.
## One screen read + 4-tap subtle adaptive sharpening, filmic contrast,
## cool-neutral color balance, fine grain and lens vignette.
## F3 can disable the fullscreen pass on slower browsers.

var viewport_filter: ColorRect
var post_material: ShaderMaterial
var quality_mode: int = 0
var requested_enabled: bool = true
var shader_compiled: bool = false

func _ready() -> void:
    layer = 3
    viewport_filter = ColorRect.new()
    viewport_filter.name = "R11_FullscreenFilmGrade"
    viewport_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
    viewport_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    viewport_filter.color = Color.WHITE
    add_child(viewport_filter)
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float sharpening : hint_range(0.0, 0.5) = 0.18;
uniform float vignette : hint_range(0.0, 0.5) = 0.15;
uniform float film_grain : hint_range(0.0, 0.04) = 0.008;
uniform float color_grade : hint_range(0.0, 1.0) = 0.50;
void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 px = SCREEN_PIXEL_SIZE;
    vec3 center = texture(scene_color, uv).rgb;
    // The four neighboring taps enhance true geometric edges;
    // a clamp prevents artificial glowing outlines.
    vec3 neighbors = (
        texture(scene_color, clamp(uv + vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb +
        texture(scene_color, clamp(uv - vec2(px.x, 0.0), vec2(0.0), vec2(1.0))).rgb +
        texture(scene_color, clamp(uv + vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb +
        texture(scene_color, clamp(uv - vec2(0.0, px.y), vec2(0.0), vec2(1.0))).rgb
    ) * 0.25;
    vec3 sharpened = center + clamp(center - neighbors, vec3(-0.20), vec3(0.20)) * sharpening;
    float luminance = dot(sharpened, vec3(0.2126, 0.7152, 0.0722));
    vec3 cool_shadows = vec3(0.965, 0.982, 1.035);
    vec3 warm_highlights = vec3(1.035, 1.010, 0.96);
    vec3 balanced = sharpened * mix(cool_shadows, warm_highlights, smoothstep(0.20, 0.80, luminance));
    balanced = mix(sharpened, balanced, color_grade);
    balanced = (balanced - 0.5) * 1.022 + 0.5;
    float radial = length((uv - 0.5) * vec2(1.15, 1.0));
    float optical_falloff = 1.0 - vignette * smoothstep(0.24, 0.90, radial);
    float noise = fract(sin(dot(floor(uv / max(px, vec2(0.0001))) +
                        vec2(TIME * 23.17, TIME * 7.33),
                        vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    vec3 out_color = balanced * optical_falloff + noise * film_grain;
    COLOR = vec4(clamp(out_color, vec3(0.0), vec3(1.0)), 1.0);
}
"""
    post_material = ShaderMaterial.new()
    post_material.shader = shader
    viewport_filter.material = post_material
    shader_compiled = true
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    if post_material == null:
        return
    post_material.set_shader_parameter("sharpening", [0.18, 0.09, 0.0][quality_mode])
    post_material.set_shader_parameter("film_grain", [0.008, 0.004, 0.0][quality_mode])
    post_material.set_shader_parameter("vignette", [0.15, 0.11, 0.0][quality_mode])
    post_material.set_shader_parameter("color_grade", [0.56, 0.36, 0.0][quality_mode])
    viewport_filter.visible = requested_enabled and quality_mode != 2

func toggle() -> void:
    requested_enabled = not requested_enabled
    set_quality(quality_mode)

func is_active() -> bool:
    return is_instance_valid(viewport_filter) and viewport_filter.visible
