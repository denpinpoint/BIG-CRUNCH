class_name ModeMenu
extends Control
## Start-of-world title screen: pick Survival or Creative, continue a save,
## open settings, or quit. Pauses the tree while open; the world keeps
## streaming in behind it (World runs in PROCESS_MODE_ALWAYS), so play starts
## instantly. F4 live-toggles the mode later without touching this menu.

## Shared SettingsMenu instance, injected by hud.gd.
var settings_menu: SettingsMenu

const _ACCENT := Color(0.49, 0.78, 0.33)     # grass green
const _ACCENT_BLUE := Color(0.36, 0.62, 0.92)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Painted gradient + drifting voxel silhouettes (no external assets).
	var art := TitleArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	# Title with a soft drop shadow (a darker copy behind, via a container).
	var title := Label.new()
	title.text = "VOXELCRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 0.94))
	title.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.05, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)

	var accent := ColorRect.new()
	accent.color = _ACCENT
	accent.custom_minimum_size = Vector2(300, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(accent)

	var subtitle := Label.new()
	subtitle.text = "an original voxel sandbox"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.modulate = Color(1, 1, 1, 0.6)
	box.add_child(subtitle)

	box.add_child(_spacer(22))

	if SaveManager.has_save():
		box.add_child(_button("Continue", _continue_save, _ACCENT_BLUE))
	box.add_child(_button("Play Survival", func() -> void: _choose(GameMode.Mode.SURVIVAL), _ACCENT))
	box.add_child(_button("Play Creative", func() -> void: _choose(GameMode.Mode.CREATIVE), _ACCENT_BLUE))
	box.add_child(_button("Settings", func() -> void: settings_menu.open()))
	box.add_child(_button("Quit", func() -> void: get_tree().quit()))

	box.add_child(_spacer(20))
	var hint := Label.new()
	hint.text = "WASD move · Space jump · LMB mine · RMB place/use · 1-9 hotbar\nE inventory · F4 mode · F5/F9 save/load · F3 debug · Esc pause"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)
	# TODO: seed entry field for custom worlds (world seed is Constants.DEFAULT_SEED).

	# Version footer, bottom-right.
	var version := Label.new()
	version.text = "v0.4 · Godot 4"
	version.add_theme_font_size_override("font_size", 11)
	version.modulate = Color(1, 1, 1, 0.4)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -120
	version.offset_top = -24
	version.offset_right = -10
	version.offset_bottom = -6
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)


func _button(text: String, on_pressed: Callable, accent: Color = Color(0.5, 0.5, 0.55)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(on_pressed)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	normal.set_border_width_all(2)
	normal.border_color = accent.darkened(0.2)
	normal.set_corner_radius_all(4)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.35)
	hover.border_color = accent
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.5)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _choose(mode: int) -> void:
	GameMode.set_mode(mode)
	_close()


func _continue_save() -> void:
	if SaveManager.load_game():
		_close()


func _close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


## Vertical dusk gradient with a row of drifting isometric-cube silhouettes.
## All procedural, redrawn as it animates.
class TitleArt:
	extends Control

	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# Vertical gradient background (deep blue -> warm horizon).
		var top := Color(0.05, 0.07, 0.13)
		var mid := Color(0.12, 0.13, 0.22)
		var bottom := Color(0.26, 0.20, 0.24)
		var steps := 24
		for i in steps:
			var f := float(i) / steps
			var col := top.lerp(mid, minf(f * 2.0, 1.0)) if f < 0.5 else mid.lerp(bottom, (f - 0.5) * 2.0)
			draw_rect(Rect2(0, size.y * f, size.x, size.y / steps + 1.0), col)

		# A ground band of slow-drifting cubes near the bottom.
		var base_y := size.y * 0.82
		var cube := 46.0
		var count := int(size.x / cube) + 3
		for i in count:
			var phase := i * 1.7
			var x := fposmod(i * cube - _t * 12.0, size.x + cube * 2.0) - cube
			var bob := sin(_t * 0.6 + phase) * 5.0
			_draw_cube(Vector2(x, base_y + bob), cube * 0.7, i)

	func _draw_cube(pos: Vector2, s: float, seed_i: int) -> void:
		var greens := [Color(0.30, 0.42, 0.22), Color(0.34, 0.40, 0.26), Color(0.24, 0.34, 0.20)]
		var top_c: Color = greens[seed_i % greens.size()]
		var h := s * 0.5
		# Top face (diamond).
		var top_pts := PackedVector2Array([
			pos + Vector2(0, -h), pos + Vector2(s, 0), pos + Vector2(0, h), pos + Vector2(-s, 0)
		])
		draw_colored_polygon(top_pts, top_c)
		# Left + right faces.
		var left := PackedVector2Array([
			pos + Vector2(-s, 0), pos + Vector2(0, h), pos + Vector2(0, h + s), pos + Vector2(-s, s)
		])
		var right := PackedVector2Array([
			pos + Vector2(s, 0), pos + Vector2(0, h), pos + Vector2(0, h + s), pos + Vector2(s, s)
		])
		draw_colored_polygon(left, top_c.darkened(0.35))
		draw_colored_polygon(right, top_c.darkened(0.2))
