class_name Cube
extends RigidBody2D

## El cubo de energía. Es un cuerpo físico normal: se mueve por la gravedad
## del mundo, que controla Main.

const SIZE := 44.0  # Debe coincidir con la CollisionShape2D de cube.tscn.
const CORE_COLOR := Color(0.35, 0.95, 1.0)

var _pending_position := Vector2.ZERO
var _has_pending_teleport := false


## Mueve el cubo a `pos` (global) y lo detiene.
## Con un RigidBody2D no se debe cambiar `position` directamente porque el
## motor de físicas lo sobrescribe; se hace dentro de _integrate_forces.
func teleport(pos: Vector2) -> void:
	_pending_position = pos
	_has_pending_teleport = true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _has_pending_teleport:
		state.transform = Transform2D(0.0, _pending_position)
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_has_pending_teleport = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var half := SIZE / 2

	# Halo: varias capas semitransparentes cada vez más grandes.
	for i in range(3, 0, -1):
		var grow := i * (4.0 + 2.0 * pulse)
		draw_rect(Rect2(-half - grow, -half - grow, SIZE + grow * 2, SIZE + grow * 2),
				Color(CORE_COLOR, 0.08))

	draw_rect(Rect2(-half, -half, SIZE, SIZE), CORE_COLOR)
	draw_rect(Rect2(-half * 0.45, -half * 0.45, SIZE * 0.45, SIZE * 0.45),
			Color(1, 1, 1, 0.6 + 0.4 * pulse))
