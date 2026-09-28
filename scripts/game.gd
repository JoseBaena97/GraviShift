extends Node

## Estado global que sobrevive a los cambios de escena: progreso, opciones
## y nivel seleccionado. Registrado como autoload "Game" en project.godot.

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

var completed_levels := 0  # Los niveles 0..completed_levels-1 están superados.
var tilt_mode := false
var current_level := 0


func _ready() -> void:
	load_progress()


func level_count() -> int:
	return Levels.DATA.size()


func is_unlocked(index: int) -> bool:
	return index <= completed_levels


func is_completed(index: int) -> bool:
	return index < completed_levels


## Primer nivel sin superar, o el último si ya se han superado todos.
func next_level_to_play() -> int:
	return mini(completed_levels, level_count() - 1)


func complete_level(index: int) -> void:
	completed_levels = maxi(completed_levels, index + 1)
	save_progress()


func set_tilt_mode(enabled: bool) -> void:
	tilt_mode = enabled
	save_progress()


func start_level(index: int) -> void:
	current_level = index
	_change_scene(GAME_SCENE)


func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false  # Por si se sale desde el menú de pausa.
	get_tree().change_scene_to_file(path)


## Espacio que ocupan arriba la cámara frontal / muesca y abajo la barra de
## gestos, en unidades del viewport: Vector2(arriba, abajo).
## En escritorio devuelve cero: allí el "área segura" excluye la barra de
## tareas y no tiene nada que ver con la ventana del juego.
func safe_area_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	if window.y == 0:
		return Vector2.ZERO
	# Píxeles físicos -> unidades del viewport (el juego se escala para
	# encajar en la pantalla, ver display/window/stretch).
	var scale := get_viewport().get_visible_rect().size.y / window.y
	return Vector2(safe.position.y, window.y - safe.end.y) * scale


# --- Guardado ----------------------------------------------------------------
# ConfigFile guarda un .ini sencillo en user://, que en Android es la carpeta
# privada de la app (se borra al desinstalar).

func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "completed_levels", completed_levels)
	config.set_value("options", "tilt_mode", tilt_mode)
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # Primera partida.
	completed_levels = clampi(config.get_value("progress", "completed_levels", 0), 0, level_count())
	tilt_mode = config.get_value("options", "tilt_mode", false)
