extends Node
## Autoloaded as "Settings" — user options, persisted to user://settings.cfg.
##
## Engine-side options (window mode, vsync, audio bus) are applied here the
## moment they change. Gameplay-side options are read by their consumers:
##   render_distance  -> world.gd chunk streaming
##   fov              -> player.gd camera
##   mouse_sensitivity / invert_y -> player.gd look
##   shadows          -> day_night.gd sun/moon lights

signal changed(key: String)

const PATH := "user://settings.cfg"
const KEYS := [
	"fullscreen", "vsync", "render_distance", "fov", "shadows",
	"master_volume", "muted", "mouse_sensitivity", "invert_y",
]

var fullscreen := false
var vsync := true
var render_distance: int = Constants.RENDER_DISTANCE
var fov := 80.0
var shadows := true
var master_volume := 1.0   # 0..1 linear on the Master bus
var muted := false
var mouse_sensitivity := 1.0  # multiplier on Constants.MOUSE_SENSITIVITY
var invert_y := false


func _ready() -> void:
	load_settings()
	_apply_engine_settings()


## Single entry point the settings UI uses. Applies + saves immediately.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_apply_engine_settings()
	save_settings()
	changed.emit(key)


func look_sensitivity() -> float:
	return Constants.MOUSE_SENSITIVITY * mouse_sensitivity


func _apply_engine_settings() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	# Master audio bus. TODO: actual sound effects/music are not shipped yet;
	# the bus settings will govern them the moment any audio plays.
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(bus, muted)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in KEYS:
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # first run: defaults stand
	for key: String in KEYS:
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))
	render_distance = clampi(render_distance, 4, 12)
	fov = clampf(fov, 60.0, 110.0)
	mouse_sensitivity = clampf(mouse_sensitivity, 0.2, 3.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
