// analog_horror.gdshader
// Full-screen post-process: animated film grain, vignette, scanlines, micro chromatic aberration.
// Applied via PostProcessLayer on a full-screen ColorRect (CanvasLayer 128).
// Art bible §2.3: grain + vignette + scanlines are NOT baked into sprites; runtime only.

shader_type canvas_item;

uniform float grain_amount      : hint_range(0.0, 0.15) = 0.055;
uniform float vignette_power    : hint_range(0.1, 2.0)  = 0.55;
uniform float scanline_strength : hint_range(0.0, 0.3)  = 0.030;
uniform float chroma_offset     : hint_range(0.0, 0.006) = 0.0012;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Subtle chromatic aberration — stronger at screen edges
	float edge = length(uv - 0.5) * 2.0;
	vec4 col;
	col.r = texture(screen_texture, uv + vec2( chroma_offset, 0.0) * edge).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv + vec2(-chroma_offset, 0.0) * edge).b;
	col.a = 1.0;

	// Animated film grain
	float t      = TIME * 1.8;
	vec2  noise  = uv * vec2(213.7 + t * 0.63, 391.3 + t * 0.41);
	float grain  = fract(sin(dot(noise, vec2(127.1, 311.7))) * 43758.545);
	col.rgb     += (grain - 0.5) * grain_amount;

	// Radial vignette
	vec2  v   = uv * (1.0 - uv.yx);
	float vig = pow(clamp(v.x * v.y * 12.0, 0.0, 1.0), vignette_power);
	col.rgb  *= vig;

	// Horizontal scanlines (every 2 screen pixels — faint)
	float scan  = step(0.5, fract(FRAGCOORD.y * 0.5));
	col.rgb    -= scan * scanline_strength;

	// Enforce art-bible brightness limits (no pure black/white)
	col.rgb = clamp(col.rgb, vec3(0.04), vec3(0.94));

	COLOR = col;
}
