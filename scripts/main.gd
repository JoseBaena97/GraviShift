extends Node2D

## Controla la partida: carga niveles, lee la entrada (deslizar, inclinar
## o teclado), cambia la gravedad del mundo físico y gestiona el HUD.

const SWIPE_MIN_DISTANCE := 60.0
const TILT_DEADZONE := 2.0  # m/s². Por debajo, el móvil está casi en horizontal.
const TILT_SMOOTHING := 8.0
## Si al probar en el móvil la gravedad va al revés, cámbialo a -1.0.
const TILT_SIGN := 1.0

## Espacio de pantalla que ocupa el HUD, arriba y abajo.
const HUD_TOP := 150.0
const HUD_BOTTOM := 120.0
const SIDE_MARGIN := 24.0
const MAX_ZOOM := 1.25

const EXIT_COLOR := Color(0.6, 1.0, 0.3)
const HAZARD_COLOR := Color(1.0, 0.22, 0.32)
const SHAKE_STRENGTH := 14.0
const SHAKE_DECAY := 8.0

@onready var level: Level = $Level
@onready var cube: Cube = $Cube
@onready var camera: Camera2D = $Camera2D
@onready var top_bar: Control = $HUD/TopBar
@onready var shifts_label: Label = $HUD/TopBar/Stats/Shifts/ShiftsLabel
@onready var time_label: Label = $HUD/TopBar/Stats/Time/TimeLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var intro: Control = $HUD/Intro
@onready var intro_number: Label = $HUD/Intro/LevelNumber
@onready var intro_name: Label = $HUD/Intro/LevelName
@onready var message: Control = $HUD/Message
@onready var message_title: Label = $HUD/Message/Title
@onready var message_stats: Label = $HUD/Message/Stats
@onready var pause_panel: Control = $HUD/PausePanel
@onready var pause_level_info: Label = $HUD/PausePanel/Box/LevelInfo
@onready var mode_button: Button = $HUD/PausePanel/Box/ModeButton

var current_level := 0
var gravity_dir := Vector2.DOWN
var shifts := 0
var elapsed := 0.0

var _insets := Vector2.ZERO  # Área segura (arriba, abajo), ver Game.safe_area_insets().
var _last_axis := Vector2.DOWN  # Último eje contado como "shift".
var _swipe_start := Vector2.ZERO
var _swiping := false
var _busy := false  # true mientras se gana, se muere o se carga un nivel.
var _shake := 0.0
var _intro_tween: Tween


func _ready() -> void:
	level.exit_reached.connect(_on_exit_reached)
	level.hazard_touched.connect(_on_hazard_touched)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_update_mode_button()
	load_level(Game.current_level)


func load_level(index: int, show_intro := true) -> void:
	_busy = true
	current_level = index
	Game.current_level = index
	var data: Dictionary = Levels.DATA[index]
	level.build(data["map"])
	_fit_camera()
	hint_label.text = _hint_for(data)
	message.hide()

	shifts = 0
	elapsed = 0.0
	_last_axis = Vector2.DOWN
	set_gravity(Vector2.DOWN)
	_update_stats()
	if show_intro:
		_show_intro(index, data)
	cube.teleport(level.to_global(level.start_position))

	# Esperamos a que el teletransporte se aplique en el motor de físicas antes
	# de mostrar el cubo y volver a aceptar colisiones. Si no, las áreas nuevas
	# podrían detectar el cubo en su posición antigua.
	await get_tree().physics_frame
	await get_tree().physics_frame
	cube.appear()
	_busy = false


func _hint_for(data: Dictionary) -> String:
	# La pista del primer nivel depende del modo de control elegido.
	if current_level == 0 and Game.tilt_mode:
		return "Inclina el móvil para cambiar la gravedad"
	return data["hint"]


func _show_intro(index: int, data: Dictionary) -> void:
	intro_number.text = "NIVEL %d" % (index + 1)
	intro_name.text = data["name"]
	if _intro_tween:
		_intro_tween.kill()
	intro.modulate.a = 1.0
	_intro_tween = create_tween()
	_intro_tween.tween_interval(1.4)
	_intro_tween.tween_property(intro, "modulate:a", 0.0, 0.6)


func set_gravity(direction: Vector2) -> void:
	gravity_dir = direction.normalized()
	# Cambia la gravedad de todo el espacio físico; la magnitud viene de
	# physics/2d/default_gravity en project.godot.
	PhysicsServer2D.area_set_param(get_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity_dir)
	cube.set_gravity_direction(gravity_dir)

	# Un "shift" es un cambio de eje. En modo inclinar la gravedad varía de
	# forma continua, así que solo cuenta cuando cambia el eje dominante.
	var axis := _snap_to_axis(gravity_dir)
	if axis != _last_axis:
		_last_axis = axis
		shifts += 1
		_update_stats()


# --- Bucle -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _busy:
		elapsed += delta
		_update_stats()

	if _shake > 0.1:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-SHAKE_DECAY * delta))
	else:
		camera.offset = Vector2.ZERO


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


func _update_stats() -> void:
	shifts_label.text = str(shifts)
	time_label.text = _format_time(elapsed)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


# --- Entrada -----------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Botón "atrás" de Android: abre o cierra la pausa.
			_set_paused(not get_tree().paused)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Al salir de la app (llamada, notificación...) se pausa sola.
			if OS.has_feature("mobile") and not get_tree().paused:
				_set_paused(true)


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
				_set_paused(true)


func _snap_to_axis(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))


# --- Eventos de juego --------------------------------------------------------

func _on_exit_reached() -> void:
	if _busy:
		return
	_busy = true
	_spawn_burst(cube.global_position, EXIT_COLOR)
	cube.hide()
	Game.complete_level(current_level)
	var last := current_level == Game.level_count() - 1
	message_title.text = "¡Juego completado!" if last else "¡Nivel completado!"
	message_stats.text = "%d %s · %s" % [shifts, "shift" if shifts == 1 else "shifts",
			_format_time(elapsed)]
	message.show()
	await get_tree().create_timer(2.5 if last else 1.5).timeout
	if last:
		Game.go_to_menu()
	else:
		load_level(current_level + 1)


func _on_hazard_touched() -> void:
	if _busy:
		return
	_busy = true
	_spawn_burst(cube.global_position, HAZARD_COLOR)
	_shake = SHAKE_STRENGTH
	cube.hide()
	await get_tree().create_timer(0.6).timeout
	load_level(current_level, false)


## Explosión de partículas de un solo uso que se borra al terminar.
func _spawn_burst(pos: Vector2, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 28
	burst.lifetime = 0.7
	burst.spread = 180.0
	burst.initial_velocity_min = 150.0
	burst.initial_velocity_max = 380.0
	burst.damping_min = 200.0
	burst.damping_max = 300.0
	burst.gravity = gravity_dir * 500.0
	burst.scale_amount_min = 5.0
	burst.scale_amount_max = 11.0
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	burst.color_ramp = fade
	burst.finished.connect(burst.queue_free)
	add_child(burst)
	burst.emitting = true


# --- Pausa -------------------------------------------------------------------

func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_panel.visible = paused
	if paused:
		pause_level_info.text = "Nivel %d · %s" % [current_level + 1, Levels.DATA[current_level]["name"]]
		_update_mode_button()


func _on_pause_pressed() -> void:
	_set_paused(true)


func _on_resume_pressed() -> void:
	_set_paused(false)


func _on_restart_pressed() -> void:
	_set_paused(false)
	if not _busy:
		load_level(current_level, false)


func _on_menu_pressed() -> void:
	Game.go_to_menu()


func _on_mode_pressed() -> void:
	Game.set_tilt_mode(not Game.tilt_mode)
	if not Game.tilt_mode:
		set_gravity(_snap_to_axis(gravity_dir))
	_update_mode_button()
	hint_label.text = _hint_for(Levels.DATA[current_level])


func _update_mode_button() -> void:
	mode_button.text = "Control: inclinar" if Game.tilt_mode else "Control: deslizar"


# --- Cámara y área segura ----------------------------------------------------

## Aparta el HUD de la cámara frontal y de la barra de gestos.
func _apply_safe_area() -> void:
	_insets = Game.safe_area_insets()
	top_bar.offset_top = _insets.x
	top_bar.offset_bottom = HUD_TOP + _insets.x
	hint_label.offset_top = -110.0 - _insets.y
	hint_label.offset_bottom = -50.0 - _insets.y
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
	# El hueco libre no está centrado verticalmente, así que desplazamos la
	# cámara para compensar.
	camera.position = level_size / 2 - Vector2(0, (hud_top - hud_bottom) / 2) / zoom
