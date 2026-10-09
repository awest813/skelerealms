extends RigidBody3D
## Local -Z is forward. Input and AI/tests share the same command interface.
signal reset_completed
## Emitted when take_damage() reduces shields or hull.
signal damaged(amount: float)
## Emitted once when shields drop from above zero to zero.
signal shield_broken
## Emitted exactly once when hull reaches zero.
signal destroyed

@export var thrust_acceleration := 22.0
@export var strafe_acceleration := 14.0
@export var brake_acceleration := 35.0
@export var assist_deceleration := 5.0
@export var maximum_speed := 120.0
@export var angular_speed := 1.25
@export var angular_response := 8.0
@export var zone_radius := 2000.0
@export var mouse_sensitivity := 0.008
@export_group("Durability")
@export var max_shield := 50.0
@export var shield_regen_rate := 8.0
@export var shield_regen_delay := 3.0
@export var max_hull := 100.0
var shield: float
var hull: float
var destroyed_flag := false
## Transparent bubble mesh flashed on hits; assigned by the ship builder.
var shield_bubble: MeshInstance3D
var _since_damage := 999.0
var _bubble_left := 0.0
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
	shield = max_shield
	hull = max_hull
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

## Shields absorb damage first; overflow reaches the hull. Emits destroyed
## exactly once. Destroyed ships keep drifting but accept no commands.
func take_damage(amount: float) -> void:
	if destroyed_flag or amount <= 0.0:
		return
	_since_damage = 0.0
	var remaining := amount
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		if shield <= 0.0:
			shield = 0.0
			shield_broken.emit()
	if remaining > 0.0:
		hull = maxf(0.0, hull - remaining)
	shield_flash()
	damaged.emit(amount)
	if hull <= 0.0 and not destroyed_flag:
		destroyed_flag = true
		clear_commands()
		destroyed.emit()

func repair_full() -> void:
	shield = max_shield
	hull = max_hull
	destroyed_flag = false
	_since_damage = shield_regen_delay


## Show the shield bubble briefly; fades out in _process.
func shield_flash() -> void:
	if shield_bubble and is_instance_valid(shield_bubble):
		_bubble_left = 0.4
		shield_bubble.visible = true


func _process(delta: float) -> void:
	if _bubble_left <= 0.0:
		return
	_bubble_left -= delta
	if not (shield_bubble and is_instance_valid(shield_bubble)):
		_bubble_left = 0.0
		return
	var f := clampf(_bubble_left / 0.4, 0.0, 1.0)
	shield_bubble.scale = Vector3.ONE * (1.0 + (1.0 - f) * 0.15)
	var mat := shield_bubble.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 0.45 * f
	if _bubble_left <= 0.0:
		shield_bubble.visible = false

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		clear_commands()
		return
	if destroyed_flag:
		clear_commands()
		return
	_since_damage += delta
	if shield < max_shield and _since_damage >= shield_regen_delay:
		shield = minf(max_shield, shield + shield_regen_rate * delta)
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
