extends AIModule
## Steering for recruited, following companions.
##
## Every frame a companion is recruited, ordered to follow, and free
## (not busy, which already covers combat), this drives their puppet toward
## the player anchor ([member GameInfo.world_origin]): walking via movement
## targets inside follow range, catching up by teleport beyond it or across
## worlds. Attach as a child of NPCComponent next to a CompanionComponent;
## without one the module stays inert. Schedules resume on their own when
## following stops, since this only ever overwrites the movement target
## while actively following.
##
## NOTE: the hook is initialize() (no underscore). DefaultMovementModule's
## _initialize() is never called by NPCComponent — do not copy that shape.


## Fixed catch-up offset beside the player. Deterministic by design.
const CATCHUP_OFFSET := Vector3(2, 0, 2)


func get_type() -> String:
	return "CompanionFollowModule"


func initialize() -> void:
	_npc.updated.connect(_on_updated.bind())


func _companion() -> CompanionComponent:
	var entity := _npc.parent_entity
	if entity == null or not entity.has_component("CompanionComponent"):
		return null
	return entity.get_component("CompanionComponent") as CompanionComponent


func _on_updated(_delta: float) -> void:
	var comp := _companion()
	if comp == null or not comp.recruited or not comp.following:
		return
	if _npc._busy:
		return
	var anchor := GameInfo.world_origin
	if anchor == null or not is_instance_valid(anchor):
		return
	var entity: SKEntity = _npc.parent_entity
	if entity == null or not is_instance_valid(entity):
		return
	# Cross-world travel (fast travel, doors): teleport along.
	if entity.world != GameInfo.world:
		_place_near(entity, GameInfo.world, anchor.global_position)
		return
	var feet := _feet_position(entity)
	if feet.distance_to(anchor.global_position) > comp.catchup_distance:
		_place_near(entity, entity.world, anchor.global_position)
		return
	if feet.distance_to(anchor.global_position) > comp.follow_distance:
		var puppet := _puppet(entity)
		if puppet and puppet.has_method("set_movement_target"):
			puppet.call("set_movement_target", anchor.global_position)


## Puppet position when spawned, else the abstract entity position.
func _feet_position(entity: SKEntity) -> Vector3:
	var puppet := _puppet(entity)
	if puppet and is_instance_valid(puppet):
		return (puppet as Node3D).global_position
	return entity.position


func _puppet(entity: SKEntity) -> Node:
	if not entity.has_component("PuppetSpawnerComponent"):
		return null
	var spawner := entity.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent
	if spawner == null:
		return null
	return spawner.puppet


## Move entity and (when spawned) puppet beside the anchor point.
func _place_near(entity: SKEntity, world_id: String, anchor_pos: Vector3) -> void:
	var dest := anchor_pos + CATCHUP_OFFSET
	var teleporter: TeleportComponent = null
	if entity.has_component("TeleportComponent"):
		teleporter = entity.get_component("TeleportComponent") as TeleportComponent
	if teleporter:
		teleporter.teleport(world_id, dest)
	else:
		entity.world = world_id
		entity.position = dest
	var puppet := _puppet(entity)
	if puppet and is_instance_valid(puppet):
		var spawner := entity.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent
		if spawner:
			spawner.set_puppet_position(dest)
