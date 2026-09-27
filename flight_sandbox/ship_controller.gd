extends RigidBody3D
## Local -Z is forward. Input and AI/tests share the same command interface.
signal reset_completed

@export var thrust_acceleration := 22.0
@export var strafe_acceleration := 14.0
@export var brake_acceleration := 35.0
@export var assist_deceleration := 5.0
@export var maximum_speed := 120.0
@export var angular_speed := 1.25
@export var angular_response := 8.0
@export var zone_radius := 2000.0
@export var mouse_sensitivity := 0.008
var assist_enabled := true
var controls_enabled := true
var read_player_input := true
var thrust_command := Vector3.ZERO
var rotation_command := Vector3.ZERO
var brake_command := false
var _mouse_command := Vector2.ZERO
var _reset_requested := false
var boundary_resets := 0

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not read_player_input:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_command = (_mouse_command + event.relative * mouse_sensitivity).limit_length(1.0)
	if event.is_action_pressed("flight_assist"):
		assist_enabled = not assist_enabled
	if event.is_action_pressed("flight_reset"):
		request_reset()

func clear_commands() -> void:
	thrust_command = Vector3.ZERO
	rotation_command = Vector3.ZERO
	_mouse_command = Vector2.ZERO
	brake_command = false

func request_reset() -> void:
	_reset_requested = true
	clear_commands()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		clear_commands()
		return
	if read_player_input:
		thrust_command = Vector3(
			Input.get_axis("flight_left", "flight_right"),
			Input.get_axis("flight_down", "flight_up"),
			Input.get_axis("flight_forward", "flight_reverse")
		).limit_length(1.0)
		rotation_command = Vector3(
			Input.get_axis("flight_pitch_down", "flight_pitch_up") - _mouse_command.y,
			Input.get_axis("flight_yaw_right", "flight_yaw_left") - _mouse_command.x,
			Input.get_axis("flight_roll_right", "flight_roll_left")
		).limit_length(1.0)
		brake_command = Input.is_action_pressed("flight_brake")
		_mouse_command = _mouse_command.move_toward(Vector2.ZERO, delta * 2.5)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_requested or state.transform.origin.length() > zone_radius:
		if not _reset_requested:
			boundary_resets += 1
		state.transform = Transform3D.IDENTITY
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_requested = false
		clear_commands()
		reset_physics_interpolation()
		reset_completed.emit()
		return
	if not controls_enabled:
		return
	# Calculate and apply this tick's forces here, so reset cannot inherit
	# a force accumulated by the previous _physics_process callback.
	var step := state.step
	var translation := thrust_command.limit_length(1.0)
	var acceleration := translation * Vector3(strafe_acceleration, strafe_acceleration, thrust_acceleration)
	var target_velocity := state.linear_velocity
	if brake_command:
		# Braking takes priority even when a thrust key is still held.
		target_velocity = target_velocity.move_toward(Vector3.ZERO, brake_acceleration * step)
	else:
		target_velocity += state.transform.basis * acceleration * step
		if assist_enabled and translation.is_zero_approx():
			target_velocity = target_velocity.move_toward(Vector3.ZERO, assist_deceleration * step)
	target_velocity = target_velocity.limit_length(maximum_speed)
	state.apply_central_force((target_velocity - state.linear_velocity) * mass / step)
	# An assisted angular-rate controller compensates for the hull's inertia,
	# keeping pitch, yaw and roll response consistent for different hull shapes.
	var target_angular := state.transform.basis * rotation_command.limit_length(1.0) * angular_speed
	var angular_acceleration := (target_angular - state.angular_velocity) * (1.0 - exp(-angular_response * step)) / step
	state.apply_torque(state.inverse_inertia_tensor.inverse() * angular_acceleration)
