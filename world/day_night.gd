extends Node
## Day/night cycle: rotates the sun, fades light energy, and blends sky and
## ambient colors. Also the authority mobs ask about darkness
## (is_night / is_dark_at).
##
## time_of_day: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.

var time_of_day: float = Constants.START_TIME_OF_DAY

var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

const _DAY_SKY_TOP := Color(0.35, 0.55, 0.85)
const _DAY_SKY_HORIZON := Color(0.7, 0.8, 0.9)
const _NIGHT_SKY_TOP := Color(0.02, 0.03, 0.08)
const _NIGHT_SKY_HORIZON := Color(0.06, 0.08, 0.15)


func _ready() -> void:
	add_to_group("daynight")
	_sun = get_node("../Sun")

	# Build the WorldEnvironment in code so it can be animated freely.
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1, 1, 1)
	_env.fog_enabled = true
	_env.fog_density = 0.001
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

	# Rotate the sun across the sky (slight yaw so shadows aren't axis-locked).
	_sun.rotation_degrees = Vector3(-(time_of_day - 0.25) * 360.0, 30.0, 0.0)
	_sun.light_energy = clampf(elevation * 1.4, 0.0, 1.2)
	_sun.visible = _sun.light_energy > 0.01

	# 0 = night, 1 = day, smooth through dawn/dusk.
	var day_frac := smoothstep(-0.15, 0.25, elevation)
	_sky_mat.sky_top_color = _NIGHT_SKY_TOP.lerp(_DAY_SKY_TOP, day_frac)
	_sky_mat.sky_horizon_color = _NIGHT_SKY_HORIZON.lerp(_DAY_SKY_HORIZON, day_frac)
	_sky_mat.ground_bottom_color = _sky_mat.sky_horizon_color.darkened(0.5)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_env.ambient_light_energy = lerpf(0.25, 0.9, day_frac)


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
