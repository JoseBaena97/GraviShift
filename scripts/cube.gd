class_name Cube
extends RigidBody2D

## El cubo de energía. Es un cuerpo físico normal: se mueve por la gravedad
## del mundo, que controla Main. Todo lo visual (estela, deformación) es
## decorativo y no afecta a la colisión.

signal impacted(strength: float)  # 0..1 según lo fuerte del choque.

const SIZE := 44.0  # Debe coincidir con la CollisionShape2D de cube.tscn.
const CORE_COLOR := Color(0.2, 0.8, 1.0)  # Azul eléctrico.

const TRAIL_GRAVITY := 260.0  # Cuánto "caen" las partículas de la estela.
const STRETCH_PER_SPEED := 1.0 / 2500.0
const MAX_STRETCH := 0.3
const IMPACT_MIN_SPEED_DROP := 350.0
const IMPACT_RECOVERY := 10.0
const IMPACT_FULL_STRENGTH := 1500.0  # Frenazo (px/s) que cuenta como choque máximo.

var _pending_position := Vector2.ZERO
var _has_pending_teleport := false
var _trail: CPUParticles2D

var _previous_velocity := Vector2.ZERO
var _impact := 0.0  # Intensidad del aplastamiento tras un choque (0..MAX_STRETCH).
var _impact_dir := Vector2.DOWN


func _ready() -> void:
	_trail = _create_trail()
	add_child(_trail)


## Mueve el cubo a `pos` (global) y lo detiene.
## Con un RigidBody2D no se debe cambiar `position` directamente porque el
## motor de físicas lo sobrescribe; se hace dentro de _integrate_forces.
func teleport(pos: Vector2) -> void:
	_pending_position = pos
	_has_pending_teleport = true


## Muestra el cubo tras un teletransporte, sin estela desde la posición anterior.
func appear() -> void:
	show()
	_trail.restart()
	_impact = 0.0


func set_gravity_direction(direction: Vector2) -> void:
	_trail.gravity = direction * TRAIL_GRAVITY


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _has_pending_teleport:
		state.transform = Transform2D(0.0, _pending_position)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_previous_velocity = Vector2.ZERO  # Si no, el teletransporte parecería un choque.
		_has_pending_teleport = false


func _physics_process(_delta: float) -> void:
	# Un frenazo brusco es un choque contra una pared.
	var drop := _previous_velocity.length() - linear_velocity.length()
	if drop > IMPACT_MIN_SPEED_DROP:
		_impact = minf(drop * STRETCH_PER_SPEED * 1.5, MAX_STRETCH)
		_impact_dir = _previous_velocity.normalized()
		impacted.emit(clampf(drop / IMPACT_FULL_STRENGTH, 0.0, 1.0))
	_previous_velocity = linear_velocity


func _process(delta: float) -> void:
	_impact = lerpf(_impact, 0.0, 1.0 - exp(-IMPACT_RECOVERY * delta))
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.0)

	# Deformación: se estira en la dirección del movimiento y se aplasta
	# contra la pared al chocar. Solo afecta al dibujo.
	var speed := linear_velocity.length()
	if _impact > 0.01:
		draw_set_transform(Vector2.ZERO, _impact_dir.angle(), Vector2(1 - _impact, 1 + _impact))
	elif speed > 1.0:
		var stretch := minf(speed * STRETCH_PER_SPEED, MAX_STRETCH)
		draw_set_transform(Vector2.ZERO, linear_velocity.angle(), Vector2(1 + stretch, 1 - stretch))

	var half := SIZE / 2
	# Halo: varias capas semitransparentes cada vez más grandes.
	for i in range(3, 0, -1):
		var grow := i * (4.0 + 2.0 * pulse)
		draw_rect(Rect2(-half - grow, -half - grow, SIZE + grow * 2, SIZE + grow * 2),
				Color(CORE_COLOR, 0.08))
	draw_rect(Rect2(-half, -half, SIZE, SIZE), CORE_COLOR)
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color(1, 1, 1, 0.5), false, 2.0)
	draw_rect(Rect2(-half * 0.45, -half * 0.45, SIZE * 0.45, SIZE * 0.45),
			Color(1, 1, 1, 0.6 + 0.4 * pulse))


func _create_trail() -> CPUParticles2D:
	var trail := CPUParticles2D.new()
	trail.amount = 48
	trail.lifetime = 0.55
	trail.local_coords = false  # Las partículas se quedan donde nacen: estela.
	trail.show_behind_parent = true
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trail.emission_rect_extents = Vector2(SIZE, SIZE) * 0.4
	trail.spread = 180.0
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 25.0
	trail.gravity = Vector2.DOWN * TRAIL_GRAVITY
	trail.scale_amount_min = 4.0
	trail.scale_amount_max = 9.0

	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	trail.scale_amount_curve = shrink

	var fade := Gradient.new()
	fade.set_color(0, Color(CORE_COLOR, 0.7))
	fade.set_color(1, Color(CORE_COLOR, 0.0))
	trail.color_ramp = fade
	return trail
