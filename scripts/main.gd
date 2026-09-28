extends Node2D

## Controla la partida: carga niveles, lee la entrada (deslizar, inclinar
## o teclado) y cambia la gravedad del mundo físico.

const SWIPE_MIN_DISTANCE := 60.0
const TILT_DEADZONE := 2.0  # m/s². Por debajo, el móvil está casi en horizontal.
const TILT_SMOOTHING := 8.0
## Si al probar en el móvil la gravedad va al revés, cámbialo a -1.0.
const TILT_SIGN := 1.0

## Espacio de pantalla que ocupa el HUD, arriba y abajo.
const HUD_TOP := 230.0
const HUD_BOTTOM := 160.0
const SIDE_MARGIN := 24.0
const MAX_ZOOM := 1.25

@onready var level: Level = $Level
@onready var cube: Cube = $Cube
@onready var camera: Camera2D = $Camera2D
@onready var level_label: Label = $HUD/LevelLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var gravity_arrow: GravityArrow = $HUD/GravityArrow
@onready var message_label: Label = $HUD/MessageLabel
@onready var mode_button: Button = $HUD/ModeButton

var current_level := 0
var gravity_dir := Vector2.DOWN
var tilt_mode := false

var _swipe_start := Vector2.ZERO
var _swiping := false
var _busy := false  # true mientras se gana, se muere o se carga un nivel.


func _ready() -> void:
	level.exit_reached.connect(_on_exit_reached)
	level.hazard_touched.connect(_on_hazard_touched)
	get_viewport().size_changed.connect(_fit_camera)
	_update_mode_button()
	load_level(0)


func load_level(index: int) -> void:
	_busy = true
	current_level = index
	var data: Dictionary = Levels.DATA[index]
	level.build(data["map"])
	_fit_camera()
	level_label.text = "Nivel %d · %s" % [index + 1, data["name"]]
	hint_label.text = data["hint"]
	message_label.hide()
	set_gravity(Vector2.DOWN)
	cube.teleport(level.to_global(level.start_position))

	# Esperamos a que el teletransporte se aplique en el motor de físicas antes
	# de mostrar el cubo y volver a aceptar colisiones. Si no, las áreas nuevas
	# podrían detectar el cubo en su posición antigua.
	await get_tree().physics_frame
	await get_tree().physics_frame
	cube.show()
	_busy = false


func set_gravity(direction: Vector2) -> void:
	gravity_dir = direction.normalized()
	# Cambia la gravedad de todo el espacio físico; la magnitud viene de
	# physics/2d/default_gravity en project.godot.
	PhysicsServer2D.area_set_param(get_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity_dir)
	gravity_arrow.direction = gravity_dir


# --- Entrada -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_swiping = event.pressed
		_swipe_start = event.position
	elif event is InputEventScreenDrag and _swiping:
		var delta: Vector2 = event.position - _swipe_start
		if delta.length() >= SWIPE_MIN_DISTANCE:
			_swiping = false  # Un gesto = un cambio de gravedad.
			if not tilt_mode:
				set_gravity(_snap_to_axis(delta))
	elif event is InputEventKey and event.pressed and not event.echo:
		# Teclado: para probar en el PC.
		match event.keycode:
			KEY_UP, KEY_W:
				set_gravity(Vector2.UP)
			KEY_DOWN, KEY_S:
				set_gravity(Vector2.DOWN)
			KEY_LEFT, KEY_A:
				set_gravity(Vector2.LEFT)
			KEY_RIGHT, KEY_D:
				set_gravity(Vector2.RIGHT)
			KEY_R:
				_on_restart_pressed()
			KEY_T:
				_on_mode_pressed()


func _physics_process(delta: float) -> void:
	if not tilt_mode:
		return
	var g := Input.get_gravity()
	var target := Vector2(g.x, -g.y) * TILT_SIGN  # El eje Y del sensor apunta hacia arriba.
	if target.length() < TILT_DEADZONE:
		return
	# Suavizado exponencial: independiente de los FPS y sin temblores del sensor.
	var weight := 1.0 - exp(-TILT_SMOOTHING * delta)
	set_gravity(gravity_dir.slerp(target.normalized(), weight))


func _snap_to_axis(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))


# --- Eventos de juego --------------------------------------------------------

func _on_exit_reached() -> void:
	if _busy:
		return
	_busy = true
	cube.hide()
	var last := current_level == Levels.DATA.size() - 1
	message_label.text = "¡Has completado\ntodos los niveles!" if last else "¡Nivel completado!"
	message_label.show()
	await get_tree().create_timer(2.5 if last else 1.2).timeout
	load_level(0 if last else current_level + 1)


func _on_hazard_touched() -> void:
	if _busy:
		return
	_busy = true
	cube.hide()
	await get_tree().create_timer(0.5).timeout
	load_level(current_level)


func _on_restart_pressed() -> void:
	if not _busy:
		load_level(current_level)


func _on_mode_pressed() -> void:
	tilt_mode = not tilt_mode
	if not tilt_mode:
		set_gravity(_snap_to_axis(gravity_dir))
	_update_mode_button()


func _update_mode_button() -> void:
	mode_button.text = "Modo: inclinar" if tilt_mode else "Modo: deslizar"


# --- Cámara ------------------------------------------------------------------

## Encaja el nivel en el hueco que deja libre el HUD, sea cual sea la pantalla.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var available := view - Vector2(SIDE_MARGIN * 2, HUD_TOP + HUD_BOTTOM)
	var level_size := level.pixel_size()
	var zoom := minf(MAX_ZOOM, minf(available.x / level_size.x, available.y / level_size.y))
	camera.zoom = Vector2(zoom, zoom)
	# El hueco libre no está centrado verticalmente (el HUD de arriba es más
	# alto), así que desplazamos la cámara para compensar.
	camera.position = level_size / 2 - Vector2(0, (HUD_TOP - HUD_BOTTOM) / 2) / zoom
