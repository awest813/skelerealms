class_name CreaturePuppet
extends NPCPuppet
## Puppet for non-humanoid bodies, driven by a [CreatureProfile].
##
## Ground bodies behave exactly like NPCs (navmesh, movement modules) with
## profile-scaled speed, collision, and senses. Flyers ignore the navigation
## stack and steer themselves in open air toward movement targets, so every
## existing interface — set_movement_target, follow packages, companion
## orders, combat targeting — works unchanged across body plans.
## Pair with an entity carrying NPCComponent and friends, like any puppet.


## Body plan. Null means plain NPC behavior (ground, scene-defined shape).
@export var profile: CreatureProfile

## Whether apply_profile already ran (mults must apply exactly once).
var _profile_applied := false


func _ready() -> void:
	super._ready()
	apply_profile()


## Movement targets are live state here (the base keeps the spawn value),
## and flyers skip the navmesh agent entirely — there are no navmaps in sky.
func set_movement_target(movement_target: Vector3) -> void:
	movement_target_position = movement_target
	if _is_flying():
		return
	super.set_movement_target(movement_target)


func _physics_process(delta: float) -> void:
	if _is_flying():
		_fly_step(delta)
	else:
		super._physics_process(delta)


func _is_flying() -> bool:
	return profile != null and profile.movement_mode == CreatureProfile.MovementMode.FLY


## Apply the profile once: locomotion tuning, collision capsule, and sense
## scaling over scene-authored eyes. Safe to call directly (tests do).
func apply_profile() -> void:
	if profile == null or _profile_applied:
		return
	_profile_applied = true
	movement_speed = profile.move_speed
	_apply_collision()
	_apply_senses()


func _apply_collision() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = profile.collision_radius
	capsule.height = profile.collision_height
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).shape = capsule
			return
	var fresh := CollisionShape3D.new()
	fresh.shape = capsule
	add_child(fresh)


func _apply_senses() -> void:
	for child in get_children():
		if child is EyesPerception:
			(child as EyesPerception).view_distance *= profile.perception_range_mult
			(child as EyesPerception).fov_h = minf((child as EyesPerception).fov_h * profile.perception_fov_mult, 179.0)
			(child as EyesPerception).fov_v = minf((child as EyesPerception).fov_v * profile.perception_fov_mult, 179.0)


## Yaw-limited steering along the body forward vector, pitched to climb
## and dive. Stays upright (no roll) and settles inside arrive_radius.
func _fly_step(delta: float) -> void:
	var to_target: Vector3 = movement_target_position - global_position
	if to_target.length() <= profile.arrive_radius:
		velocity = velocity.move_toward(Vector3.ZERO, profile.move_speed * 4.0 * delta)
		move_and_slide()
		return
	var dir := to_target.normalized()
	var turn := clampf(profile.turn_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), turn)
	rotation.x = lerp_angle(rotation.x, asin(clampf(dir.y, -1.0, 1.0)), turn)
	velocity = -global_transform.basis.z * profile.move_speed
	move_and_slide()
