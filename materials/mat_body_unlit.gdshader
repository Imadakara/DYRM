// Unlit-шейдер тел слоя Deep: базовый цвет + мягкий терминатор в сторону Солнца.
// ART-04, ART-05. Не участвует в освещении сцены — угол терминатора считается
// вручную по направлению на Солнце, переданному извне на каждое тело.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 base_color : source_color = vec3(1.0);
uniform vec3 light_direction = vec3(0.0, 0.0, 1.0);
uniform bool emissive = false;

void fragment() {
	if (emissive) {
		ALBEDO = base_color;
		EMISSION = base_color;
	} else {
		vec3 n = normalize(NORMAL);
		float ndotl = dot(n, normalize(light_direction));
		float terminator = smoothstep(-0.15, 0.15, ndotl);
		float shade = mix(0.08, 1.0, terminator);
		ALBEDO = base_color * shade;
	}
}
