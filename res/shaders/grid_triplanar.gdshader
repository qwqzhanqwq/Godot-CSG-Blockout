shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms GridColors;
uniform vec4 color_a : source_color = vec4(0.85, 0.85, 0.85, 1.0);
uniform vec4 color_b : source_color = vec4(0.72, 0.72, 0.72, 1.0);
uniform vec4 grid_color : source_color = vec4(0.2, 0.2, 0.2, 0.9);
uniform vec4 sub_grid_color : source_color = vec4(0.45, 0.45, 0.45, 0.5);

group_uniforms GridSettings;
uniform float grid_scale : hint_range(0.1, 10.0, 0.1) = 1.0;
uniform float sub_grid_divisions : hint_range(1.0, 10.0, 1.0) = 2.0;
uniform float line_thickness : hint_range(0.001, 0.1, 0.001) = 0.02;
uniform float sub_line_thickness : hint_range(0.001, 0.05, 0.001) = 0.01;
uniform float triplanar_sharpness : hint_range(1.0, 32.0, 0.5) = 8.0;
uniform bool use_checker = true;
uniform bool world_aligned = true;

group_uniforms MaterialProperties;
uniform float roughness : hint_range(0.0, 1.0, 0.05) = 0.75;
uniform float metallic : hint_range(0.0, 1.0, 0.05) = 0.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_local_pos;
varying vec3 v_local_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_local_pos = VERTEX;
	v_local_normal = NORMAL;
}

float get_grid_line(vec2 uv_pos, float thickness) {
	vec2 grid_uv = abs(fract(uv_pos - 0.5) - 0.5);
	vec2 fw = fwidth(uv_pos);
	vec2 line = 1.0 - smoothstep(vec2(thickness * 0.5), vec2(thickness * 0.5) + fw * 1.5, grid_uv);
	return clamp(max(line.x, line.y), 0.0, 1.0);
}

float get_checker(vec2 uv_pos) {
	vec2 c = floor(uv_pos);
	return mod(c.x + c.y, 2.0);
}

vec3 sample_plane(vec2 uv) {
	float checker = get_checker(uv);
	vec3 base = use_checker ? mix(color_a.rgb, color_b.rgb, checker) : color_a.rgb;
	
	// Sub-grid lines (0.5m)
	if (sub_grid_divisions > 1.0 && sub_line_thickness > 0.0) {
		float sub_line = get_grid_line(uv * sub_grid_divisions, sub_line_thickness * sub_grid_divisions);
		base = mix(base, sub_grid_color.rgb, sub_line * sub_grid_color.a);
	}
	
	// Major grid lines (1.0m)
	if (line_thickness > 0.0) {
		float main_line = get_grid_line(uv, line_thickness);
		base = mix(base, grid_color.rgb, main_line * grid_color.a);
	}
	
	return base;
}

void fragment() {
	vec3 pos = (world_aligned ? v_world_pos : v_local_pos) / max(grid_scale, 0.001);
	vec3 norm = normalize(world_aligned ? v_world_normal : v_local_normal);
	
	vec3 weights = abs(norm);
	weights = pow(weights, vec3(triplanar_sharpness));
	weights /= (weights.x + weights.y + weights.z + 0.00001);
	
	vec2 uv_x = pos.zy;
	vec2 uv_y = pos.xz;
	vec2 uv_z = pos.xy;
	
	vec3 col_x = sample_plane(uv_x);
	vec3 col_y = sample_plane(uv_y);
	vec3 col_z = sample_plane(uv_z);
	
	vec3 final_color = col_x * weights.x + col_y * weights.y + col_z * weights.z;
	
	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
