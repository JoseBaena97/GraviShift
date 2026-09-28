extends Button

## Botón de pausa discreto: dibuja el icono (dos barras) en vez de usar texto,
## para no depender de que la fuente tenga el símbolo.

const ICON_COLOR := Color(0.85, 0.97, 1.0, 0.85)


func _draw() -> void:
	var bar := Vector2(size.x * 0.12, size.y * 0.38)
	var gap := size.x * 0.1
	var top := (size.y - bar.y) / 2
	var left := size.x / 2 - gap / 2 - bar.x
	draw_rect(Rect2(Vector2(left, top), bar), ICON_COLOR)
	draw_rect(Rect2(Vector2(size.x / 2 + gap / 2, top), bar), ICON_COLOR)
