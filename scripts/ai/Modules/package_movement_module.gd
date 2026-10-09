extends AIModule
## Executes the active package: steers the puppet to its target and
## occupies tagged furniture on arrival. Yields to combat/busy states and
## to companion-follow orders (a recruited follower is on duty, not on
## break). Pair with PackageComponent on the same NPC; without one it is
## inert. Arrival radius and furniture handling below.


## Distance that counts as arrived.
const ARRIVAL_RADIUS := 1.5


func get_type() -> String:
	return "PackageMovementModule"


func initialize() -> void:
	_npc.updated.connect(_on_updated.bind())


func _package() -> AIPackage:
	var entity := _npc.parent_entity
	if entity == null or not entity.has_component("PackageComponent"):
		return null
	return (entity.get_component("PackageComponent") as PackageComponent).active_package


func _on_updated(_delta: float) -> void:
	var pkg := _package()
	if pkg == null:
		_stand_up()
		_last_pkg = null
		return
	if _npc._busy:
		_stand_up()
		return
	if _following_companion():
		_stand_up()
		return
	var entity: SKEntity = _npc.parent_entity
	if entity == null or not is_instance_valid(entity):
		return
	var dest := _destination(pkg, entity)
	if dest == null:
		_stand_up()
		return
	if pkg != _last_pkg:
		_stand_up()
		_last_pkg = pkg
	var feet := _feet_position(entity)
	if feet.distance_to(dest) > ARRIVAL_RADIUS:
		_stand_up()
		var puppet := _puppet(entity)
		if puppet and puppet.has_method("set_movement_target"):
			puppet.call("set_movement_target", dest)
	elif not pkg.furniture_tag.is_empty():
		_sit_down(pkg, feet)


## Companion-follow outranks packages: on-duty followers ignore their day.
func _following_companion() -> bool:
	var entity := _npc.parent_entity
	if entity == null or not entity.has_component("CompanionComponent"):
		return false
	var comp := entity.get_component("CompanionComponent") as CompanionComponent
	return comp and comp.recruited and comp.following


## Resolve the package destination in the entity's world, or null when
## the target is gone or lives elsewhere (re-evaluation heals this).
## Blank targets mean "right here" — always valid in any world.
func _destination(pkg: AIPackage, entity: SKEntity) -> Variant:
	if pkg.target_entity != &"":
		var manager := SKEntityManager.instance
		if manager == null:
			return null
		var target: SKEntity = manager.entities.get(pkg.target_entity)
		if target == null or not is_instance_valid(target):
			return null
		if target.world != entity.world:
			return null
		return target.position
	if pkg.target_world != "" and pkg.target_world != entity.world:
		return null
	# An unauthored loiter target stays here; authored points are world positions.
	if pkg.target_world.is_empty() and pkg.target_position == Vector3.ZERO:
		return entity.position
	return pkg.target_position


## Release the current seat, if any.
func _stand_up() -> void:
	if _seated_where != null and is_instance_valid(_seated_where):
		var entity := _npc.parent_entity
		(_seated_where as Furniture).unoccupy_entity(str(entity.name) if entity else "")
	_seated_where = null


## Occupy nearby tagged furniture once per arrival. Only seats within reach
## count — a chair across the map must never seat a distant actor.
func _sit_down(pkg: AIPackage, feet: Vector3) -> void:
	if _seated_where != null and is_instance_valid(_seated_where):
		return
	var seat := SkeleRealmsGlobal.find_alternative_furniture(pkg.furniture_tag) as Furniture
	if seat == null or not is_instance_valid(seat):
		return
	if (seat as Node3D).global_position.distance_to(feet) > ARRIVAL_RADIUS * 2.0:
		return
	var entity := _npc.parent_entity
	if seat.has_room() and seat.occupy(str(entity.name) if entity else ""):
		_seated_where = seat


var _seated_where: Furniture
var _last_pkg: AIPackage


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
