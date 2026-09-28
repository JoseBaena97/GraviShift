class_name Level
extends Node2D

## Construye un nivel a partir de un mapa de texto (ver Levels):
## colisiones de las paredes, zona de salida y pinchos. También lo dibuja.

signal exit_reached
signal hazard_touched

const TILE := 64

const BG_COLOR := Color(0.07, 0.09, 0.15)
const GRID_COLOR := Color(1, 1, 1, 0.03)
const WALL_COLOR := Color(0.18, 0.22, 0.35)
const WALL_EDGE_COLOR := Color(0.32, 0.4, 0.62)
const EXIT_COLOR := Color(0.45, 1.0, 0.55)
const SPIKE_COLOR := Color(1.0, 0.3, 0.4)

var cols := 0
var rows := 0
var start_position := Vector2.ZERO  # Centro de la casilla inicial, en coordenadas locales.

var _walls := {}  # Vector2i -> true
var _spikes: Array[Vector2i] = []
var _exit_cell := Vector2i(-1, -1)


func _process(_delta: float) -> void:
	queue_redraw()  # La salida tiene una animación de pulso.


func pixel_size() -> Vector2:
	return Vector2(cols, rows) * TILE


func build(map: Array) -> void:
	_clear()
	rows = map.size()
	cols = (map[0] as String).length()

	for y in rows:
		var line: String = map[y]
		for x in cols:
			var cell := Vector2i(x, y)
			match line[x]:
				"#":
					_walls[cell] = true
				"P":
					start_position = _cell_center(cell)
				"E":
					_exit_cell = cell
					_add_area(cell, TILE * 0.5, exit_reached)
				"^":
					_spikes.append(cell)
					_add_area(cell, TILE * 0.6, hazard_touched)

	_build_wall_colliders()
	queue_redraw()


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_walls.clear()
	_spikes.clear()
	_exit_cell = Vector2i(-1, -1)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## Área de detección que emite `signal_to_emit` cuando el cubo entra en ella.
func _add_area(cell: Vector2i, size: float, signal_to_emit: Signal) -> void:
	var area := Area2D.new()
	area.position = _cell_center(cell)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size, size)
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body is Cube:
			signal_to_emit.emit()
	)
	add_child(area)


## Une las paredes en el menor número de rectángulos posible (fusión voraz).
## Menos rectángulos significa menos juntas, y el cubo se engancha menos
## al deslizarse sobre ellas.
func _build_wall_colliders() -> void:
	var body := StaticBody2D.new()
	var wall_material := PhysicsMaterial.new()
	wall_material.friction = 0.2
	body.physics_material_override = wall_material
	add_child(body)

	var used := {}
	for y in rows:
		var x := 0
		while x < cols:
			if not _is_free_wall(Vector2i(x, y), used):
				x += 1
				continue
			var w := 1
			while x + w < cols and _is_free_wall(Vector2i(x + w, y), used):
				w += 1
			var h := 1
			while y + h < rows and _is_free_wall_run(x, y + h, w, used):
				h += 1
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					used[Vector2i(xx, yy)] = true

			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(w, h) * TILE
			shape.shape = rect
			shape.position = Vector2(x, y) * TILE + rect.size / 2
			body.add_child(shape)
			x += w


func _is_free_wall(cell: Vector2i, used: Dictionary) -> bool:
	return _walls.has(cell) and not used.has(cell)


func _is_free_wall_run(x: int, y: int, w: int, used: Dictionary) -> bool:
	for xx in range(x, x + w):
		if not _is_free_wall(Vector2i(xx, y), used):
			return false
	return true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, pixel_size()), BG_COLOR)
	for x in range(1, cols):
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, rows * TILE), GRID_COLOR)
	for y in range(1, rows):
		draw_line(Vector2(0, y * TILE), Vector2(cols * TILE, y * TILE), GRID_COLOR)

	for cell: Vector2i in _walls:
		var r := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
		draw_rect(r, WALL_COLOR)
		draw_rect(r.grow(-3), WALL_EDGE_COLOR, false, 2.0)

	for cell in _spikes:
		_draw_spike(_cell_center(cell))

	if _exit_cell.x >= 0:
		_draw_exit(_cell_center(_exit_cell))


func _draw_spike(center: Vector2) -> void:
	var outer := TILE * 0.4
	var inner := TILE * 0.15
	var points := PackedVector2Array()
	for i in 16:
		var radius := outer if i % 2 == 0 else inner
		points.append(center + Vector2.from_angle(i * TAU / 16) * radius)
	draw_colored_polygon(points, SPIKE_COLOR)


func _draw_exit(center: Vector2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	draw_circle(center, TILE * (0.38 + 0.06 * pulse), Color(EXIT_COLOR, 0.15))
	draw_arc(center, TILE * 0.3, 0, TAU, 32, EXIT_COLOR, 4.0)
	draw_circle(center, TILE * 0.12, EXIT_COLOR)
