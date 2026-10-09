extends Node
## Steering AI for a drone ship. Drives the parent ship's command interface
## (thrust_command / rotation_command); never touches physics directly, so it
## works with any body running ship_controller.gd.
##
## States: APPROACH closes distance, ATTACK orbits and fires when aimed,
## EVADE breaks away after taking heavy damage or to avoid ramming.

enum State { APPROACH, ATTACK, EVADE }

## Beyond this distance the drone closes in; inside it, it attacks.
@export var attack_range := 60.0
## Inside this distance the drone breaks off to avoid ramming the player.
@export var break_range := 18.0
## Entering EVADE when hull drops below this fraction of maximum.
@export var evade_hull_fraction := 0.5
## Seconds spent evading before re-approaching.
@export var evade_time := 2.0
## Proportional steering gain mapping angle error to rotation commands.
@export var steer_gain := 2.0
## Maximum aim error (degrees) the drone accepts before firing.
@export var aim_fire_deg := 6.0

var ship: RigidBody3D
var player: Node3D
var laser: Node
## When true the player is docked: hold an 80 m standoff, never fire.
var player_docked := false
var state := State.APPROACH
var _evade_left := 0.0
var _orbit_side := 1.0


func _ready() -> void:
	if ship == null:
		ship = get_parent() as RigidBody3D


func _physics_process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	if bool(ship.get("destroyed_flag")):
		ship.set("thrust_command", Vector3.ZERO)
		ship.set("rotation_command", Vector3.ZERO)
		return
	if player == null or not is_instance_valid(player) or bool(player.get("destroyed_flag")):
		ship.set("thrust_command", Vector3.ZERO)
		ship.set("rotation_command", Vector3.ZERO)
		return
	if player_docked:
		_hold_standoff()
		return
	var to_player: Vector3 = (player as Node3D).global_position - (ship as Node3D).global_position
	var distance := to_player.length()
	if _evade_left > 0.0:
		_evade_left -= delta
		state = State.EVADE
	elif float(ship.get("hull")) < float(ship.get("max_hull")) * evade_hull_fraction:
		_enter_evade(evade_time)
	elif distance < break_range:
		_enter_evade(1.0)
	elif distance > attack_range:
		if state != State.APPROACH:
			state = State.APPROACH
	else:
		if state != State.ATTACK:
			state = State.ATTACK
			_orbit_side = -_orbit_side
	match state:
		State.APPROACH:
			_steer_toward(to_player)
			ship.set("thrust_command", Vector3(0, 0, -1))
		State.ATTACK:
			_steer_toward(to_player)
			ship.set("thrust_command", Vector3(0.6 * _orbit_side, 0, -0.35))
			if laser != null and is_instance_valid(laser) and _aim_angle(to_player) <= deg_to_rad(aim_fire_deg):
				laser.call("fire")
		State.EVADE:
			var away := -to_player.normalized() + Vector3(0.7 * _orbit_side, 0.35, 0)
			_steer_toward(away)
			ship.set("thrust_command", Vector3(0, 0, -1))


func _enter_evade(duration: float) -> void:
	state = State.EVADE
	_evade_left = duration


## Circle the docked player at range without firing.
func _hold_standoff() -> void:
	var offset: Vector3 = (ship as Node3D).global_position - (player as Node3D).global_position
	if offset.length() < 70.0:
		_steer_toward(offset)
		ship.set("thrust_command", Vector3(0, 0, -1))
	else:
		_steer_toward(-offset)
		ship.set("thrust_command", Vector3(0.5 * _orbit_side, 0, -0.2))


## Angle in radians between the ship's nose (-Z) and a world direction.
func _aim_angle(world_dir: Vector3) -> float:
	var forward := -((ship as Node3D).global_transform.basis.z)
	return forward.angle_to(world_dir.normalized())


## Convert a desired world-space flight direction into pitch/yaw rate
## commands. Local -Z is forward: positive local X is right, positive Y is up.
func _steer_toward(world_dir: Vector3) -> void:
	var local_dir: Vector3 = (ship as Node3D).global_transform.basis.inverse() * world_dir.normalized()
	var pitch := clampf(atan2(local_dir.y, -local_dir.z) * steer_gain, -1.0, 1.0)
	var yaw := clampf(-atan2(local_dir.x, -local_dir.z) * steer_gain, -1.0, 1.0)
	ship.set("rotation_command", Vector3(pitch, yaw, 0.0))
