class_name SfxSynth
extends RefCounted

## Sintetizador mínimo de efectos de sonido. Genera las ondas por código y
## las devuelve como AudioStreamWAV (PCM de 16 bits, mono), así que el juego
## no necesita archivos de audio para los efectos.
##
## Cada efecto combina las mismas piezas básicas:
##   - un oscilador (seno, cuadrada, sierra, triangular) o ruido,
##   - un barrido de frecuencia (exponencial, que es como lo percibe el oído),
##   - una envolvente: ataque lineal y caída en curva.

enum Wave { SINE, SQUARE, SAW, TRIANGLE, NOISE }

## 22 kHz basta para efectos de sintetizador y reduce a la mitad el tiempo de
## generación al arrancar, que en un móvil se nota.
const MIX_RATE := 22050


# --- Efectos -----------------------------------------------------------------

## Cambio de gravedad: barrido ascendente con un soplo de ruido.
static func shift() -> AudioStreamWAV:
	var out := _tone(Wave.SINE, 0.14, 260.0, 620.0, 0.35, 0.01, 2.0)
	out = _mix(out, _tone(Wave.NOISE, 0.12, 0.0, 0.0, 0.12, 0.03, 2.0, 0.15))
	return _to_stream(out)


## Choque contra una pared: golpe grave que cae de tono, con un clic inicial.
static func impact() -> AudioStreamWAV:
	var out := _tone(Wave.SINE, 0.18, 140.0, 45.0, 0.8, 0.002, 3.0)
	out = _mix(out, _tone(Wave.NOISE, 0.03, 0.0, 0.0, 0.3, 0.0, 3.0, 0.5))
	return _to_stream(out)


## Entrar al portal: arpegio ascendente de do mayor (do, mi, sol, do).
static func portal() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var step := 0.07
	var out := PackedFloat32Array()
	for i in notes.size():
		var note := _tone(Wave.TRIANGLE, 0.35, notes[i], notes[i], 0.28, 0.005, 2.0)
		out = _mix(out, note, i * step)
	# Brillo final una octava por encima.
	out = _mix(out, _tone(Wave.SINE, 0.4, 2093.0, 2093.0, 0.08, 0.01, 2.0), notes.size() * step)
	return _to_stream(out)


## Muerte en pinchos: onda cuadrada que se desploma y ruido seco.
static func spike_death() -> AudioStreamWAV:
	var out := _tone(Wave.SQUARE, 0.35, 380.0, 55.0, 0.3, 0.0, 1.5)
	out = _mix(out, _tone(Wave.NOISE, 0.2, 0.0, 0.0, 0.35, 0.0, 3.0, 1.0))
	return _to_stream(out)


## Muerte en láser: chisporroteo eléctrico (sierra con vibrato rápido).
static func laser_death() -> AudioStreamWAV:
	var duration := 0.3
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var progress := t / duration
		var freq := 1400.0 * pow(180.0 / 1400.0, progress)
		freq *= 1.0 + 0.3 * sin(TAU * 35.0 * t)  # Vibrato: el "zumbido" eléctrico.
		phase += freq / MIX_RATE
		out[i] = _osc(Wave.SAW, phase) * 0.28 * pow(1.0 - progress, 1.5)
	out = _mix(out, _tone(Wave.NOISE, 0.08, 0.0, 0.0, 0.3, 0.0, 2.0, 1.0))
	return _to_stream(out)


## Zumbido continuo de los láseres (en bucle). Todas las frecuencias caben un
## número entero de veces en la duración, así el bucle no tiene saltos.
static func laser_hum() -> AudioStreamWAV:
	var duration := 0.5
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / MIX_RATE
		var tone := 0.5 * _osc(Wave.SAW, 110.0 * t) + 0.5 * sin(TAU * 220.0 * t)
		var tremolo := 0.75 + 0.25 * sin(TAU * 30.0 * t)
		out[i] = tone * tremolo * 0.4
	return _to_stream(out, true)


## Pulsar un botón: clic breve y suave.
static func click() -> AudioStreamWAV:
	return _to_stream(_tone(Wave.SINE, 0.045, 1000.0, 700.0, 0.25, 0.002, 2.0))


# --- Piezas básicas ----------------------------------------------------------

## Genera un tono con barrido de frecuencia y envolvente.
## `lowpass` (0..1) solo se usa con ruido: valores bajos lo hacen más sordo.
static func _tone(wave: Wave, duration: float, freq_start: float, freq_end: float,
		volume: float, attack: float, decay_power: float, lowpass := 1.0) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var filtered := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var progress := t / duration
		var sample: float
		if wave == Wave.NOISE:
			# Filtro paso bajo de un polo sobre ruido blanco.
			filtered += lowpass * (randf_range(-1.0, 1.0) - filtered)
			sample = filtered
		else:
			phase += freq_start * pow(freq_end / freq_start, progress) / MIX_RATE
			sample = _osc(wave, phase)
		var envelope := minf(t / attack, 1.0) if attack > 0.0 else 1.0
		envelope *= pow(1.0 - progress, decay_power)
		out[i] = sample * envelope * volume
	return out


static func _osc(wave: Wave, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match wave:
		Wave.SINE:
			return sin(p * TAU)
		Wave.SQUARE:
			return 1.0 if p < 0.5 else -1.0
		Wave.SAW:
			return 2.0 * p - 1.0
		Wave.TRIANGLE:
			return 1.0 - 4.0 * absf(p - 0.5)
	return 0.0


## Devuelve `target` con `other` sumado a partir de `offset` segundos
## (lo alarga si hace falta).
static func _mix(target: PackedFloat32Array, other: PackedFloat32Array,
		offset := 0.0) -> PackedFloat32Array:
	var start := int(offset * MIX_RATE)
	if target.size() < start + other.size():
		target.resize(start + other.size())
	for i in other.size():
		target[start + i] += other[i]
	return target


static func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
