class_name Level
extends Node2D

## Construye un nivel a partir de un mapa de texto (ver Levels):
## colisiones de las paredes, salida y peligros. También lo dibuja.

signal exit_reached
signal hazard_touched(kind: String)  # "spike" o "laser"

const TILE := 64

const FLOOR_COLOR := Color(0, 0, 0, 0.28)
const DOT_COLOR := Color(1, 1, 1, 0.07)
const WALL_COLOR := Color(0.12, 0.13, 0.17)
const WALL_EDGE_COLOR := Color(0.5, 0.56, 0.7)
const EXIT_COLOR := Color(0.6, 1.0, 0.3)  # Verde lima.
const HAZARD_COLOR := Color(1.0, 0.22, 0.32)

## Orden de preferencia de la pared a la que se clavan los pinchos.
const SPIKE_ANCHORS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
const NEIGHBORS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var cols := 0
var rows := 0
var start_position := Vector2.ZERO  # Centro de la casilla inicial, en coordenadas locales.

var _walls := {}  # Vector2i -> true
var _spikes := {}  # Vector2i -> dirección hacia la pared donde se clava (o ZERO)
var _lasers := {}  # Vector2i -> true si es horizontal
var _exit_cell := Vector2i(-1, -1)


func _process(_delta: float) -> void:
	queue_redraw()  # Portal y láseres están animados.


func pixel_size() -> Vector2:
	return Vector2(cols, rows) * TILE


## Centros de las casillas con láser (en coordenadas locales), para el zumbido.
func laser_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell: Vector2i in _lasers:
		result.append(_cell_center(cell))
	return result


func build(map: Array) -> void:
	_clear()
	rows = map.size()
	cols = (map[0] as String).length()

	# Primera pasada: paredes. Los pinchos necesitan saber dónde están.
	for y in rows:
		for x in cols:
			if (map[y] as String)[x] == "#":
				_walls[Vector2i(x, y)] = true

	for y in rows:
		var line: String = map[y]
		for x in cols:
			var cell := Vector2i(x, y)
			var center := _cell_center(cell)
			match line[x]:
				"P":
					start_position = center
				"E":
					_exit_cell = cell
					_add_area(center, Vector2(TILE, TILE) * 0.5, exit_reached.emit)
				"^":
					var anchor := _spike_anchor(cell)
					_spikes[cell] = anchor
					if anchor == Vector2i.ZERO:
						_add_area(center, Vector2(TILE, TILE) * 0.6, hazard_touched.emit.bind("spike"))
					else:
						# La zona peligrosa es la mitad de la casilla pegada a la pared.
						var along := Vector2(anchor).abs()
						var size := Vector2(TILE, TILE) * (Vector2.ONE * 0.9 - along * 0.4)
						_add_area(center + Vector2(anchor) * TILE * 0.25, size, hazard_touched.emit.bind("spike"))
				"=":
					_lasers[cell] = true
					_add_area(center, Vector2(TILE, TILE * 0.25), hazard_touched.emit.bind("laser"))
				"|":
					_lasers[cell] = false
					_add_area(center, Vector2(TILE * 0.25, TILE), hazard_touched.emit.bind("laser"))

	_build_wall_colliders()
	queue_redraw()


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_walls.clear()
	_spikes.clear()
	_lasers.clear()
	_exit_cell = Vector2i(-1, -1)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _spike_anchor(cell: Vector2i) -> Vector2i:
	for dir in SPIKE_ANCHORS:
		if _walls.has(cell + dir):
			return dir
	return Vector2i.ZERO


## Área de detección que llama a `on_enter` cuando el cubo entra en ella.
func _add_area(center: Vector2, size: Vector2, on_enter: Callable) -> void:
	var area := Area2D.new()
	area.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body is Cube:
			on_enter.call()
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


# --- Dibujo ------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_draw_floor()
	_draw_walls()
	for cell: Vector2i in _lasers:
		_draw_laser(cell, _lasers[cell], t)
	for cell: Vector2i in _spikes:
		_draw_spikes(cell, _spikes[cell])
	if _exit_cell.x >= 0:
		_draw_exit(_cell_center(_exit_cell), t)


func _draw_floor() -> void:
	draw_rect(Rect2(Vector2.ZERO, pixel_size()), FLOOR_COLOR)
	for y in range(1, rows):
		for x in range(1, cols):
			draw_circle(Vector2(x, y) * TILE, 1.5, DOT_COLOR)


## Relleno mate y borde luminoso solo en las caras que dan a una casilla
## libre, para que las paredes contiguas se lean como una sola pieza.
func _draw_walls() -> void:
	for cell: Vector2i in _walls:
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), WALL_COLOR)

	for cell: Vector2i in _walls:
		for dir in NEIGHBORS:
			var neighbor := cell + dir
			if _walls.has(neighbor) or not _in_bounds(neighbor):
				continue
			var edge := _cell_edge(cell, dir, 1.5)
			draw_line(edge[0], edge[1], WALL_EDGE_COLOR, 3.0)
			var inner := _cell_edge(cell, dir, 6.0)
			draw_line(inner[0], inner[1], Color(WALL_EDGE_COLOR, 0.15), 2.0)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


## Segmento del lado `dir` de la casilla, metido `inset` píxeles hacia dentro.
func _cell_edge(cell: Vector2i, dir: Vector2i, inset: float) -> Array[Vector2]:
	var center := _cell_center(cell)
	var d := Vector2(dir)
	var n := d.orthogonal()
	var mid := center + d * (TILE / 2.0 - inset)
	var half := TILE / 2.0
	return [mid - n * half, mid + n * half]


func _draw_spikes(cell: Vector2i, anchor: Vector2i) -> void:
	var center := _cell_center(cell)
	if anchor == Vector2i.ZERO:
		# Sin pared al lado: mina en forma de estrella.
		var points := PackedVector2Array()
		for i in 16:
			var radius := TILE * (0.4 if i % 2 == 0 else 0.15)
			points.append(center + Vector2.from_angle(i * TAU / 16) * radius)
		draw_colored_polygon(points, HAZARD_COLOR)
		return

	var d := Vector2(anchor)  # Hacia la pared.
	var n := d.orthogonal()
	var base := center + d * TILE * 0.5
	var width := TILE / 3.0
	# Resplandor en la base, pegado a la pared.
	var half := n * TILE / 2
	draw_colored_polygon(PackedVector2Array([base - half, base + half, base + half - d * 10,
			base - half - d * 10]), Color(HAZARD_COLOR, 0.25))
	for i in 3:
		var b := base + n * (i - 1) * width
		var tip := b - d * TILE * 0.5
		var tri := PackedVector2Array([b + n * width / 2, b - n * width / 2, tip])
		draw_colored_polygon(tri, HAZARD_COLOR)
		draw_line(b, tip, Color(1, 0.7, 0.75, 0.5), 1.5)


func _draw_laser(cell: Vector2i, horizontal: bool, t: float) -> void:
	var center := _cell_center(cell)
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var a := center - axis * TILE / 2
	var b := center + axis * TILE / 2
	# Parpadeo irregular: dos senos con frecuencias distintas.
	var flicker := 0.8 + 0.1 * sin(t * 31.0 + cell.x) + 0.1 * sin(t * 17.0 + cell.y)
	draw_line(a, b, Color(HAZARD_COLOR, 0.15 * flicker), 16.0)
	draw_line(a, b, Color(HAZARD_COLOR, 0.5 * flicker), 7.0)
	draw_line(a, b, Color(1, 0.85, 0.88, flicker), 2.5)

	# Emisores donde el rayo toca una pared.
	var step := Vector2i(axis)
	for side: int in [-1, 1]:
		if _walls.has(cell + step * side):
			var p := center + axis * side * (TILE / 2.0 - 5)
			var n := axis.orthogonal()
			draw_rect(Rect2(p - axis * 5 - n * 12, axis.abs() * 10 + n.abs() * 24), Color(0.3, 0.1, 0.13))
			draw_circle(p, 4.0, Color(HAZARD_COLOR, flicker))


func _draw_exit(center: Vector2, t: float) -> void:
	var blink := 0.7 + 0.3 * sin(t * 2.5)
	for i in 3:
		draw_circle(center, TILE * (0.3 + 0.07 * i), Color(EXIT_COLOR, 0.06 * blink))
	# Dos anillos discontinuos que giran en sentidos opuestos.
	_draw_dashed_ring(center, TILE * 0.36, 8, t * 1.2, Color(EXIT_COLOR, blink), 4.0)
	_draw_dashed_ring(center, TILE * 0.24, 4, -t * 2.0, Color(EXIT_COLOR, 0.7 * blink), 3.0)
	draw_circle(center, TILE * (0.07 + 0.03 * blink), Color(0.9, 1, 0.8, blink))


func _draw_dashed_ring(center: Vector2, radius: float, dashes: int, rotation_offset: float,
		color: Color, width: float) -> void:
	var arc := TAU / dashes
	for i in dashes:
		var start := rotation_offset + i * arc
		draw_arc(center, radius, start, start + arc * 0.55, 8, color, width)
