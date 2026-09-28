extends Node

## Audio global: buses, efectos sintetizados y zumbido de los láseres.
## Registrado como autoload "Audio" (después de "Game", del que lee las opciones).

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const POOL_SIZE := 8  # Efectos que pueden sonar a la vez.
const PITCH_VARIATION := 0.06  # ±6 %: evita que un sonido repetido canse.
const HUM_VOLUME_DB := -12.0
const CLICK_VOLUME_DB := -6.0
const PAUSE_LOWPASS_HZ := 900.0

var _sounds := {}  # nombre -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _hum: AudioStreamPlayer


func _ready() -> void:
	# Debe seguir funcionando con el juego en pausa (clics del menú de pausa).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()

	_sounds = {
		"shift": SfxSynth.shift(),
		"impact": SfxSynth.impact(),
		"portal": SfxSynth.portal(),
		"spike_death": SfxSynth.spike_death(),
		"laser_death": SfxSynth.laser_death(),
		"click": SfxSynth.click(),
	}

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)

	_hum = AudioStreamPlayer.new()
	_hum.bus = SFX_BUS
	_hum.stream = SfxSynth.laser_hum()
	add_child(_hum)

	set_sfx_enabled(Game.sfx_enabled)
	# Clic automático en todos los botones del juego, incluidos los que se
	# crean por código (como la cuadrícula de niveles).
	get_tree().node_added.connect(_on_node_added)


## Crea los buses Music y SFX colgando de Master. La música lleva un filtro
## paso bajo, apagado, que se enciende durante la pausa.
func _create_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")

	var music := AudioServer.get_bus_index(MUSIC_BUS)
	if AudioServer.get_bus_effect_count(music) == 0:
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = PAUSE_LOWPASS_HZ
		AudioServer.add_bus_effect(music, lowpass)
		AudioServer.set_bus_effect_enabled(music, 0, false)


## Reproduce un efecto. Usa los reproductores del grupo por turnos: si están
## todos ocupados, corta el más antiguo.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = _sounds[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	player.play()


## Intensidad del zumbido de los láseres, de 0 (apagado) a 1.
func set_hum_level(level: float) -> void:
	if level <= 0.01:
		if _hum.playing:
			_hum.stop()
		return
	_hum.volume_db = HUM_VOLUME_DB + linear_to_db(level)
	if not _hum.playing:
		_hum.play()


## Durante la pausa la música se oye "a través de la pared".
func set_music_muffled(muffled: bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(MUSIC_BUS), 0, muffled)


func set_sfx_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not enabled)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click", CLICK_VOLUME_DB))
