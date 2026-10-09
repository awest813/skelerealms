extends AIModule


## Default movement that doesn't interface with animations at all. Just gliding across the floor like Jamiroquai.


func get_type() -> String:
	return "DefaultMovementModule"


func _initialize() -> void:
	_npc.puppet_request_move.connect(move.bind())


## Pure steering math, extracted for tests: velocity toward a point at speed.
static func steering_velocity(from_pos: Vector3, target_pos: Vector3, speed: float) -> Vector3:
	return from_pos.direction_to(target_pos) * speed


func move(puppet:NPCPuppet) -> void:
	if puppet.navigation_agent.is_navigation_finished():
		return

	var target:Vector3 = puppet.navigation_agent.get_next_path_position()
	var pos:Vector3 = puppet.global_position

	puppet.velocity = steering_velocity(pos, target, puppet.movement_speed)
	puppet.move_and_slide()
