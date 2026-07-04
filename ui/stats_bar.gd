class_name StatsBar
extends Control
## Survival HUD: hearts (left) + hunger drumsticks (right), drawn directly
## with _draw. Hidden entirely in Creative (hud.gd toggles visibility).

var _health: float = Constants.MAX_HEALTH
var _hunger: float = Constants.MAX_HUNGER

const ICON := 17.0   # icon cell width
const ICON_SIZE := 15.0

# Unit heart outline (concave polygon, scaled at draw time).
const _HEART := [
	Vector2(0.5, 0.95), Vector2(0.05, 0.5), Vector2(0.05, 0.25),
	Vector2(0.2, 0.08), Vector2(0.38, 0.08), Vector2(0.5, 0.28),
	Vector2(0.62, 0.08), Vector2(0.8, 0.08), Vector2(0.95, 0.25),
	Vector2(0.95, 0.5),
]


func set_health(v: float) -> void:
	_health = v
	queue_redraw()


func set_hunger(v: float) -> void:
	_hunger = v
	queue_redraw()


func _draw() -> void:
	var y := size.y - ICON_SIZE - 2.0
	# 10 hearts, 2 hp each, left-aligned.
	for i in 10:
		var fill := clampf(_health - i * 2.0, 0.0, 2.0) / 2.0
		var x := i * ICON
		_draw_heart(Vector2(x, y), Color(0.2, 0.05, 0.05, 0.85))
		if fill > 0.0:
			_draw_heart(Vector2(x, y), Color(0.85, 0.12, 0.12), fill)
	# 10 drumsticks, 2 points each, right-aligned (mirrored order like the HUD
	# it's inspired by).
	for i in 10:
		var fill := clampf(_hunger - i * 2.0, 0.0, 2.0) / 2.0
		var x := size.x - (i + 1) * ICON
		_draw_drumstick(Vector2(x, y), Color(0.2, 0.12, 0.05, 0.85))
		if fill > 0.0:
			_draw_drumstick(Vector2(x, y), Color(0.72, 0.45, 0.2), fill)


func _draw_heart(pos: Vector2, color: Color, scale_frac: float = 1.0) -> void:
	var s := ICON_SIZE * scale_frac
	var off := pos + Vector2.ONE * (ICON_SIZE - s) * 0.5
	var pts := PackedVector2Array()
	for p: Vector2 in _HEART:
		pts.push_back(off + p * s)
	draw_colored_polygon(pts, color)


func _draw_drumstick(pos: Vector2, color: Color, scale_frac: float = 1.0) -> void:
	var s := ICON_SIZE * scale_frac
	var off := pos + Vector2.ONE * (ICON_SIZE - s) * 0.5
	# Meaty end + bone handle.
	draw_circle(off + Vector2(0.38, 0.38) * s, 0.34 * s, color)
	draw_rect(Rect2(off + Vector2(0.45, 0.45) * s, Vector2(0.45, 0.22) * s), color)
	draw_circle(off + Vector2(0.9, 0.62) * s, 0.12 * s, Color(0.9, 0.88, 0.8, color.a))
