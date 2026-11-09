shader_type spatial;
render_mode unshaded, cull_front;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float base_y = 0.0;
uniform float height = 1.0;
varying float world_y;
void vertex() {
	VERTEX += NORMAL*0.018;
	world_y = (MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment() {
	if (progress <= 0.0 || progress >= 1.0 || world_y > base_y+height*progress) { discard; }
	ALBEDO = vec3(1.0,0.32,0.035);
	EMISSION = ALBEDO*0.5;
}
