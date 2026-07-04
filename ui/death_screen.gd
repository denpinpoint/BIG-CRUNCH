class_name DeathScreen
extends Control
## Simple death/respawn screen (Survival). The world keeps running behind it.

signal respawn_requested

func _ready() -> void:
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.0, 0.0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "You died"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	var button := Button.new()
	button.text = "Respawn"
	button.custom_minimum_size = Vector2(220, 44)
	button.pressed.connect(_on_respawn)
	box.add_child(button)


func open() -> void:
	visible = true


func _on_respawn() -> void:
	visible = false
	respawn_requested.emit()
