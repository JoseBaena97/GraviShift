class_name GravityArrow
extends Control

## Flecha del HUD que indica hacia dónde apunta la gravedad.

const COLOR := Color(0.35, 0.95, 1.0, 0.85)
const LENGTH := 36.0

var direction := Vector2.DOWN:
	set(value):
		direction = value
		queue_redraw()


func _draw() -> void:
	var center := size / 2
	var tip := center + direction * LENGTH
	var head_base := tip - direction * 26
	var side := direction.orthogonal() * 18
	draw_line(center - direction * LENGTH, head_base, COLOR, 8.0)
	draw_colored_polygon(PackedVector2Array([tip, head_base + side, head_base - side]), COLOR)
