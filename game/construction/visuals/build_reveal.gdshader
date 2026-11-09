shader_type spatial;
render_mode cull_back;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float base_y = 0.0;
uniform float height = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color;
uniform bool textured = false;
uniform bool vertex_colored = false;
uniform float material_roughness = 1.0;
uniform float material_metallic = 0.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
	float frontier = base_y + height * progress;
	if (progress <= 0.0 || world_y > frontier) { discard; }
	vec4 color = tint;
	if (textured) { color *= texture(albedo_map,UV); }
	if (vertex_colored) { color *= COLOR; }
	ALBEDO = color.rgb;
	ROUGHNESS = material_roughness;
	METALLIC = material_metallic;
	if (progress < 1.0 && abs(world_y-frontier) < 0.045) {
		ALBEDO = vec3(1.0,0.32,0.035);
		EMISSION = ALBEDO * 0.7;
	}
}
