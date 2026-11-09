shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float base_y = 0.0;
uniform float height = 1.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
	if (progress >= 1.0 || world_y < base_y+height*progress) { discard; }
	float edge = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	float scan = step(0.75,fract(world_y*6.0));
	ALBEDO = vec3(0.06,0.72,1.0);
	EMISSION = ALBEDO*0.4;
	ALPHA = 0.12+edge*0.38+scan*0.12;
}
