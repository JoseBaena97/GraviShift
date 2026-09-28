extends Control

## Menú principal y selector de niveles.

const LEVEL_BUTTON_SIZE := Vector2(150, 150)
const COMPLETED_COLOR := Color(0.45, 1.0, 0.55)
const PARTICLE_COLOR := Color(0.35, 0.95, 1.0, 0.12)
const GRID_COLOR := Color(1, 1, 1, 0.035)
const GRID_STEP := 64.0

## Fondo decorativo: cubos que caen y cuya gravedad gira cada pocos segundos.
const PARTICLE_COUNT := 18
const GRAVITY_CHANGE_INTERVAL := 3.0

@onready var main_panel: Control = $MainPanel
@onready var levels_panel: Control = $LevelsPanel
@onready var play_button: Button = $MainPanel/PlayButton
@onready var mode_button: Button = $MainPanel/ModeButton
@onready var level_grid: GridContainer = $LevelsPanel/LevelGrid
@onready var version_label: Label = $VersionLabel

var _particles: Array[Vector2] = []
var _particle_speeds: Array[float] = []
var _particle_gravity := Vector2.DOWN
var _gravity_timer := 0.0


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	_update_play_button()
	_update_mode_button()
	_build_level_grid()
	_show_levels(false)

	var area := get_viewport_rect().size
	for i in PARTICLE_COUNT:
		_particles.append(Vector2(randf() * area.x, randf() * area.y))
		_particle_speeds.append(randf_range(40.0, 140.0))


func _notification(what: int) -> void:
	# Botón "atrás" de Android.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_go_back()


func _go_back() -> void:
	if levels_panel.visible:
		_show_levels(false)
	else:
		get_tree().quit()


func _show_levels(open: bool) -> void:
	levels_panel.visible = open
	main_panel.visible = not open


func _update_play_button() -> void:
	var done := Game.completed_levels
	if done == 0 or done >= Game.level_count():
		play_button.text = "Jugar"
	else:
		play_button.text = "Continuar · Nivel %d" % (done + 1)


func _update_mode_button() -> void:
	mode_button.text = "Control: inclinar" if Game.tilt_mode else "Control: deslizar"


func _build_level_grid() -> void:
	for child in level_grid.get_children():
		child.queue_free()
	for i in Game.level_count():
		var button := Button.new()
		button.custom_minimum_size = LEVEL_BUTTON_SIZE
		button.text = str(i + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 52)
		button.disabled = not Game.is_unlocked(i)
		if Game.is_completed(i):
			button.add_theme_color_override("font_color", COMPLETED_COLOR)
		button.pressed.connect(Game.start_level.bind(i))
		level_grid.add_child(button)


func _on_play_pressed() -> void:
	# Si ya se han superado todos, se empieza desde el primero.
	var all_done := Game.completed_levels >= Game.level_count()
	Game.start_level(0 if all_done else Game.next_level_to_play())


func _on_levels_pressed() -> void:
	_show_levels(true)


func _on_back_pressed() -> void:
	_show_levels(false)


func _on_mode_pressed() -> void:
	Game.set_tilt_mode(not Game.tilt_mode)
	_update_mode_button()


# --- Fondo animado -----------------------------------------------------------

func _process(delta: float) -> void:
	_gravity_timer += delta
	if _gravity_timer >= GRAVITY_CHANGE_INTERVAL:
		_gravity_timer = 0.0
		var turn := PI / 2 if randf() < 0.5 else -PI / 2
		_particle_gravity = _particle_gravity.rotated(turn).round()

	var area := size
	for i in _particles.size():
		var p := _particles[i] + _particle_gravity * _particle_speeds[i] * delta
		_particles[i] = Vector2(fposmod(p.x, area.x), fposmod(p.y, area.y))
	queue_redraw()


func _draw() -> void:
	var x := GRID_STEP
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR)
		x += GRID_STEP
	var y := GRID_STEP
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR)
		y += GRID_STEP

	for i in _particles.size():
		var side := remap(_particle_speeds[i], 40.0, 140.0, 10.0, 26.0)
		draw_rect(Rect2(_particles[i] - Vector2(side, side) / 2, Vector2(side, side)), PARTICLE_COLOR)
