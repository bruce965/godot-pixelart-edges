shader_type spatial;
render_mode depth_draw_never, depth_test_disabled, cull_disabled, unshaded, skip_vertex_transform;

// Ported from: https://github.com/KodyJKing/hello-threejs/blob/08a3696ed1d9f93e9d3dc6a6a3fb17ffcd70d453/src/RenderPixelatedPass.ts

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

const float normalEdgeCoefficient = .3;
const float depthEdgeCoefficient = .4;

void vertex() {
	POSITION = vec4(VERTEX, 1.);
}

float gedepth_texture(vec2 uv, vec2 pixelSize, int x, int y) {
	return textureLod(depth_texture, uv + vec2(ivec2(x, y)) * pixelSize, 0).r;
}

vec3 genormal_roughness_texture(vec2 uv, vec2 pixelSize, int x, int y) {
	return textureLod(normal_roughness_texture, uv + vec2(ivec2(x, y)) * pixelSize, 0).rgb * 2. - 1.;
}

float depthEdgeIndicator(vec2 uv, vec2 pixelSize) {
	float depth = gedepth_texture(uv, pixelSize, 0, 0);
	vec3 normal = genormal_roughness_texture(uv, pixelSize, 0, 0);
	float diff = 0.0;
	diff += clamp(gedepth_texture(uv, pixelSize, 1, 0) - depth, 0.0, 1.0);
	diff += clamp(gedepth_texture(uv, pixelSize, -1, 0) - depth, 0.0, 1.0);
	diff += clamp(gedepth_texture(uv, pixelSize, 0, 1) - depth, 0.0, 1.0);
	diff += clamp(gedepth_texture(uv, pixelSize, 0, -1) - depth, 0.0, 1.0);
	return floor(smoothstep(0.01, 0.02, diff) * 2.) / 2.;
}

float neighborNormalEdgeIndicator(vec2 uv, vec2 pixelSize, int x, int y, float depth, vec3 normal) {
	float depthDiff = gedepth_texture(uv, pixelSize, x, y) - depth;

	// Edge pixels should yield to faces who's normals are closer to the bias normal.
	vec3 normalEdgeBias = vec3(1., 1., 1.); // This should probably be a parameter.
	float normalDiff = dot(normal - genormal_roughness_texture(uv, pixelSize, x, y), normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);

	// Only the shallower pixel should detect the normal edge.
	float depthIndicator = clamp(sign(depthDiff * .25 + .0025), 0.0, 1.0);

	return distance(normal, genormal_roughness_texture(uv, pixelSize, x, y)) * depthIndicator * normalIndicator;
}

float normalEdgeIndicator(vec2 uv, vec2 pixelSize) {
	float depth = gedepth_texture(uv, pixelSize, 0, 0);
	vec3 normal = genormal_roughness_texture(uv, pixelSize, 0, 0);

	float indicator = 0.0;

	indicator += neighborNormalEdgeIndicator(uv, pixelSize, 0, -1, depth, normal);
	indicator += neighborNormalEdgeIndicator(uv, pixelSize, 0, 1, depth, normal);
	indicator += neighborNormalEdgeIndicator(uv, pixelSize, -1, 0, depth, normal);
	indicator += neighborNormalEdgeIndicator(uv, pixelSize, 1, 0, depth, normal);

	return step(0.1, indicator);
}

void fragment() {
	vec4 texel = textureLod(screen_texture, SCREEN_UV, 0);

	vec2 SCREEN_PIXEL_SIZE = vec2(1.) / vec2(textureSize(screen_texture, 0));

	float dei = depthEdgeIndicator(SCREEN_UV, SCREEN_PIXEL_SIZE);
	float nei = normalEdgeIndicator(SCREEN_UV, SCREEN_PIXEL_SIZE);

	float coefficient = dei > 0.0 ? (1.0 - depthEdgeCoefficient * dei) : (1.0 + normalEdgeCoefficient * nei);

	ALBEDO = texel.rgb * coefficient;
}
