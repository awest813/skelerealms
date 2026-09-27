extends RefCounted
## Swept, forward-only gate crossings prevent skipped gates at high speed.
signal gate_passed(index: int)
var gates: Array[Vector3] = []
var next_gate := 0
var elapsed := 0.0
var finished := false
var started := false
var _previous := Vector3.ZERO
var _start_position := Vector3.ZERO
const CLEARANCE := 11.0 # Accounts for the ship hull and gate posts.

func reset(position := Vector3.ZERO) -> void:
	next_gate = 0
	elapsed = 0.0
	finished = false
	started = false
	_previous = position
	_start_position = position

func advance(position: Vector3, delta: float) -> void:
	if finished or gates.is_empty():
		_previous = position
		return
	if position.distance_to(_start_position) > 0.001:
		started = true
	if started:
		elapsed += delta
	while next_gate < gates.size():
		var gate := gates[next_gate]
		if _previous.z <= gate.z or position.z > gate.z:
			break
		var fraction := (gate.z - _previous.z) / (position.z - _previous.z)
		var crossing := _previous.lerp(position, fraction)
		if absf(crossing.x - gate.x) > CLEARANCE or absf(crossing.y - gate.y) > CLEARANCE:
			break
		var passed := next_gate
		next_gate += 1
		if next_gate == gates.size():
			# Count only the part of this tick before the finish plane.
			elapsed -= delta * (1.0 - fraction)
		gate_passed.emit(passed)
	finished = next_gate == gates.size()
	_previous = position
