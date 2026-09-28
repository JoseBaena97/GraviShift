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
@onready var top_bar: Control = $HUD/TopBar
@onready var level_label: Label = $HUD/TopBar/LevelLabel
@onready var hint_label: Label = $HUD/TopBar/HintLabel
@onready var gravity_arrow: GravityArrow = $HUD/TopBar/GravityArrow
@onready var message_label: Label = $HUD/MessageLabel
@onready var buttons: Control = $HUD/Buttons
@onready var mode_button: Button = $HUD/Buttons/ModeButton

var current_level := 0
var gravity_dir := Vector2.DOWN

var _insets := Vector2.ZERO  # Área segura (arriba, abajo), ver Game.safe_area_insets().
var _swipe_start := Vector2.ZERO
var _swiping := false
var _busy := false  # true mientras se gana, se muere o se carga un nivel.


func _ready() -> void:
	level.exit_reached.connect(_on_exit_reached)
	level.hazard_touched.connect(_on_hazard_touched)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_update_mode_button()
	load_level(Game.current_level)


func load_level(index: int) -> void:
	_busy = true
	current_level = index
	Game.current_level = index
	var data: Dictionary = Levels.DATA[index]
	level.build(data["map"])
	_fit_camera()
	level_label.text = "Nivel %d · %s" % [index + 1, data["name"]]
	hint_label.text = _hint_for(data)
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


func _hint_for(data: Dictionary) -> String:
	# La pista del primer nivel depende del modo de control elegido.
	if current_level == 0 and Game.tilt_mode:
		return "Inclina el móvil para cambiar la gravedad"
	return data["hint"]


func set_gravity(direction: Vector2) -> void:
	gravity_dir = direction.normalized()
	# Cambia la gravedad de todo el espacio físico; la magnitud viene de
	# physics/2d/default_gravity en project.godot.
	PhysicsServer2D.area_set_param(get_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity_dir)
	gravity_arrow.direction = gravity_dir


# --- Entrada -----------------------------------------------------------------

func _notification(what: int) -> void:
	# Botón "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_swiping = event.pressed
		_swipe_start = event.position
	elif event is InputEventScreenDrag and _swiping:
		var delta: Vector2 = event.position - _swipe_start
		if delta.length() >= SWIPE_MIN_DISTANCE:
			_swiping = false  # Un gesto = un cambio de gravedad.
			if not Game.tilt_mode:
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
			KEY_ESCAPE:
				Game.go_to_menu()


func _physics_process(delta: float) -> void:
	if not Game.tilt_mode:
		return
	# El sensor de gravedad ya filtra los movimientos bruscos; si el móvil no
	# lo tiene, usamos el acelerómetro, que da la misma lectura pero con ruido.
	var g := Input.get_gravity()
	if g.is_zero_approx():
		g = Input.get_accelerometer()
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
	Game.complete_level(current_level)
	var last := current_level == Game.level_count() - 1
	message_label.text = "¡Has completado\ntodos los niveles!" if last else "¡Nivel completado!"
	message_label.show()
	await get_tree().create_timer(2.5 if last else 1.2).timeout
	if last:
		Game.go_to_menu()
	else:
		load_level(current_level + 1)


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


func _on_menu_pressed() -> void:
	Game.go_to_menu()


func _on_mode_pressed() -> void:
	Game.set_tilt_mode(not Game.tilt_mode)
	if not Game.tilt_mode:
		set_gravity(_snap_to_axis(gravity_dir))
	_update_mode_button()
	hint_label.text = _hint_for(Levels.DATA[current_level])


func _update_mode_button() -> void:
	mode_button.text = "Inclinar" if Game.tilt_mode else "Deslizar"


# --- Cámara y área segura ----------------------------------------------------

## Aparta el HUD de la cámara frontal y de la barra de gestos.
func _apply_safe_area() -> void:
	_insets = Game.safe_area_insets()
	top_bar.offset_top = _insets.x
	top_bar.offset_bottom = HUD_TOP + _insets.x
	buttons.offset_top = -130.0 - _insets.y
	buttons.offset_bottom = -50.0 - _insets.y
	_fit_camera()


## Encaja el nivel en el hueco que deja libre el HUD, sea cual sea la pantalla.
func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var hud_top := HUD_TOP + _insets.x
	var hud_bottom := HUD_BOTTOM + _insets.y
	var available := view - Vector2(SIDE_MARGIN * 2, hud_top + hud_bottom)
	var level_size := level.pixel_size()
	var zoom := minf(MAX_ZOOM, minf(available.x / level_size.x, available.y / level_size.y))
	camera.zoom = Vector2(zoom, zoom)
	# El hueco libre no está centrado verticalmente (el HUD de arriba es más
	# alto), así que desplazamos la cámara para compensar.
	camera.position = level_size / 2 - Vector2(0, (hud_top - hud_bottom) / 2) / zoom
