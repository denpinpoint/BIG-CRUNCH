extends Node
## Day/night cycle with a custom sky shader: gradient day/night sky, visible
## sun disc with sunrise/sunset glow, a moon, and a twinkling star field at
## night. Lighting follows: warm low sun, white noon sun, cool dim moonlight
## after dark, with ambient light and fog blending along.
##
## time_of_day: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.

var time_of_day: float = Constants.START_TIME_OF_DAY

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ShaderMaterial

const _DAY_SKY_TOP := Color(0.24, 0.48, 0.85)
const _DAY_SKY_HORIZON := Color(0.63, 0.77, 0.92)
const _NIGHT_SKY_TOP := Color(0.012, 0.018, 0.05)
const _NIGHT_SKY_HORIZON := Color(0.04, 0.055, 0.11)
const _SUNSET := Color(0.98, 0.48, 0.18)

const _SUN_WARM := Color(1.0, 0.62, 0.32)   # low sun
const _SUN_WHITE := Color(1.0, 0.985, 0.94)  # noon
const _MOON_COLOR := Color(0.55, 0.65, 0.9)

# Sky shader: analytic gradient + sun/moon discs + hash-based star field.
# EYEDIR is the per-pixel view direction; every uniform is fed from _apply().
const _SKY_SHADER := """
shader_type sky;

uniform vec3 top_color;
uniform vec3 horizon_color;
uniform vec3 sunset_color;
uniform float sunset_amount;   // 0..1, peaks at dawn/dusk
uniform float night_amount;    // 0 day .. 1 night
uniform vec3 sun_dir;
uniform vec3 moon_dir;

float star_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	float up = clamp(EYEDIR.y, -1.0, 1.0);

	// Vertical gradient, horizon widened near the ground.
	float grad = pow(1.0 - clamp(up, 0.0, 1.0), 2.2);
	vec3 col = mix(top_color, horizon_color, grad);

	// Sunset/sunrise: tint the horizon strongest toward the sun's azimuth.
	vec2 flat_eye = normalize(EYEDIR.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sun_dir.xz + vec2(1e-5));
	float facing = clamp(dot(flat_eye, flat_sun) * 0.5 + 0.5, 0.0, 1.0);
	float horizon_band = exp(-abs(up) * 4.0);
	col = mix(col, sunset_color, sunset_amount * horizon_band * facing * 0.85);

	// Sun: hard disc + soft bloom.
	float sun_d = dot(EYEDIR, sun_dir);
	col += vec3(1.0, 0.9, 0.7) * smoothstep(0.9993, 0.9997, sun_d);
	col += vec3(1.0, 0.62, 0.3) * pow(clamp(sun_d, 0.0, 1.0), 48.0) * 0.35 * (1.0 - night_amount * 0.7);

	// Moon: smaller, cooler disc with a faint halo.
	float moon_d = dot(EYEDIR, moon_dir);
	col += vec3(0.9, 0.93, 1.0) * smoothstep(0.99965, 0.99985, moon_d) * night_amount;
	col += vec3(0.4, 0.45, 0.6) * pow(clamp(moon_d, 0.0, 1.0), 90.0) * 0.25 * night_amount;

	// Stars: stable hash grid over the upper hemisphere, gently twinkling.
	if (night_amount > 0.01 && up > 0.0) {
		vec2 grid = vec2(atan(EYEDIR.z, EYEDIR.x), asin(up)) * vec2(60.0, 45.0);
		vec2 cell = floor(grid);
		float h = star_hash(cell);
		if (h > 0.92) {
			vec2 center = cell + 0.5 + (vec2(star_hash(cell + 7.0), star_hash(cell + 13.0)) - 0.5) * 0.6;
			float d = length(grid - center);
			float twinkle = 0.75 + 0.25 * sin(TIME * (1.0 + h * 4.0) + h * 40.0);
			float star = smoothstep(0.16, 0.0, d) * twinkle;
			col += vec3(star) * night_amount * up;
		}
	}

	COLOR = col;
}
"""


func _ready() -> void:
	add_to_group("daynight")
	_sun = get_node("../Sun")

	# Moonlight: a second, dim directional light opposite the sun so nights
	# are readable instead of pitch black.
	_moon = DirectionalLight3D.new()
	_moon.light_color = _MOON_COLOR
	_moon.light_energy = 0.0
	_moon.shadow_enabled = true
	add_child(_moon)

	var shader := Shader.new()
	shader.code = _SKY_SHADER
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.0012
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)
	_apply(0.0)


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / Constants.DAY_LENGTH_SEC, 1.0)

	# Sun elevation: -1 (midnight) .. +1 (noon).
	var sun_angle := (time_of_day - 0.25) * TAU
	var elevation := sin(sun_angle)

	# Rotate the sun across the sky (slight yaw so shadows aren't axis-locked);
	# the moon rides exactly opposite.
	_sun.rotation_degrees = Vector3(-(time_of_day - 0.25) * 360.0, 30.0, 0.0)
	_moon.rotation_degrees = _sun.rotation_degrees + Vector3(180.0, 0.0, 0.0)

	# 0 = night, 1 = day, smooth through dawn/dusk.
	var day_frac := smoothstep(-0.15, 0.25, elevation)
	var night_frac := 1.0 - day_frac
	# Sunset glow peaks when the sun crosses the horizon.
	var sunset := clampf(1.0 - absf(elevation) / 0.28, 0.0, 1.0)

	# User-toggleable shadows (settings menu).
	_sun.shadow_enabled = Settings.shadows
	_moon.shadow_enabled = Settings.shadows

	# Sun: warm and weak at the horizon, bright white at noon.
	_sun.light_energy = clampf(elevation * 1.5, 0.0, 1.25)
	_sun.light_color = _SUN_WARM.lerp(_SUN_WHITE, clampf(elevation * 1.6, 0.0, 1.0))
	_sun.visible = _sun.light_energy > 0.01
	# Moon: gentle blue fill, only after dark.
	_moon.light_energy = 0.14 * clampf(-elevation * 3.0, 0.0, 1.0)
	_moon.visible = _moon.light_energy > 0.005

	# Sky shader uniforms. Light nodes point along -Z, so forward = -basis.z;
	# the shader wants the direction TOWARD the celestial body.
	var sun_dir := -_sun.global_transform.basis.z
	_sky_mat.set_shader_parameter("top_color", _NIGHT_SKY_TOP.lerp(_DAY_SKY_TOP, day_frac))
	_sky_mat.set_shader_parameter("horizon_color", _NIGHT_SKY_HORIZON.lerp(_DAY_SKY_HORIZON, day_frac))
	_sky_mat.set_shader_parameter("sunset_color", _SUNSET)
	_sky_mat.set_shader_parameter("sunset_amount", sunset)
	_sky_mat.set_shader_parameter("night_amount", night_frac)
	_sky_mat.set_shader_parameter("sun_dir", sun_dir)
	_sky_mat.set_shader_parameter("moon_dir", -sun_dir)

	# Ambient + fog track the sky.
	_env.ambient_light_color = Color(1, 1, 1).lerp(Color(0.55, 0.62, 0.85), night_frac)
	_env.ambient_light_energy = lerpf(0.22, 0.9, day_frac)
	_env.fog_light_color = _NIGHT_SKY_HORIZON.lerp(_DAY_SKY_HORIZON, day_frac)


func is_night() -> bool:
	return sin((time_of_day - 0.25) * TAU) < 0.05


## Approximate light model for mob spawning: dark if it's night on the
## surface, or if the spot is buried well below the terrain surface (caves).
## TODO: replace with real per-block light propagation.
func is_dark_at(bp: Vector3i, surface_h: int) -> bool:
	if bp.y < surface_h - Constants.HOSTILE_CAVE_DEPTH:
		return true
	return is_night()


func clock_string() -> String:
	var hours := int(time_of_day * 24.0)
	var minutes := int(fmod(time_of_day * 24.0, 1.0) * 60.0)
	return "%02d:%02d" % [hours, minutes]
