class_name PackageComponent
extends SKEntityComponent
## Daily-life brain for civilian NPCs: evaluates an ordered package stack
## (eat, sleep, work, patrol...) against time windows, needs, and target
## reachability, and publishes the winner. PackageMovementModule executes;
## schedules keep handling scripted sequences untouched.
##
## Precedence, highest first: combat/busy > companion-follow > packages >
## schedules. Effective priority is base priority plus the gated need value,
## so hungrier NPCs prefer food automatically. Re-evaluates on game minutes,
## need updates, and demand.


## Emitted when the active package changes (null = idling, nothing valid).
signal package_changed(package: AIPackage)


## Ordered package stack, highest intent last or first — order only breaks
## effective-priority ties (first wins), so list freely.
@export var packages: Array[AIPackage] = []
## Currently executing package, or null.
var active_package: AIPackage


func _init() -> void:
	name = "PackageComponent"


func _ready() -> void:
	super._ready()
	GameInfo.minute_incremented.connect(evaluate)
	if parent_entity and parent_entity.has_component("NeedsComponent"):
		(parent_entity.get_component("NeedsComponent") as NeedsComponent).needs_updated.connect(evaluate)
	evaluate()


## Re-evaluate the stack. Returns the new active package (possibly null).
func evaluate() -> AIPackage:
	var now := _now_hours()
	var best: AIPackage = null
	var best_score := -INF
	for pkg in packages:
		if not _is_valid(pkg, now):
			continue
		# Needs run 0..1, so scale urgency to outbid meaningful base priorities.
		var score := float(pkg.priority) + _need_value(pkg) * 100.0
		if score > best_score:
			best_score = score
			best = pkg
	if best != active_package:
		active_package = best
		package_changed.emit(best)
	return active_package


## Structural sanity: duplicate ids. Returns issue dicts {type, detail}.
func validate() -> Array:
	var issues: Array = []
	var seen := {}
	for pkg in packages:
		if seen.has(pkg.id):
			issues.append({"type": "duplicate_package", "detail": "Duplicate package id '%s'." % pkg.id})
		seen[pkg.id] = true
	return issues


func save() -> Dictionary:
	return {"active_package": str(active_package.id) if active_package else ""}


func load_data(data: Dictionary) -> void:
	var want := StringName(str(data.get("active_package", "")))
	active_package = null
	if want != &"":
		for pkg in packages:
			if pkg.id == want:
				active_package = pkg
				break


func _now_hours() -> float:
	return float(GameInfo.hour) + float(GameInfo.minute) / 60.0


func _need_value(pkg: AIPackage) -> float:
	if pkg.need_id.is_empty():
		return 0.0
	if parent_entity == null or not parent_entity.has_component("NeedsComponent"):
		return 0.0
	return (parent_entity.get_component("NeedsComponent") as NeedsComponent).get_need(pkg.need_id)


func _is_valid(pkg: AIPackage, now: float) -> bool:
	if not _in_window(pkg, now):
		return false
	if not pkg.need_id.is_empty():
		if parent_entity == null or not parent_entity.has_component("NeedsComponent"):
			return false
		if _need_value(pkg) < pkg.need_min:
			return false
	return _target_resolvable(pkg)


## Entity targets must exist in the same world (streamed-out targets heal
## on later ticks); fixed points only need a matching world.
func _target_resolvable(pkg: AIPackage) -> bool:
	if pkg.target_entity != &"":
		var manager := SKEntityManager.instance
		if manager == null:
			return false
		var target: SKEntity = manager.entities.get(pkg.target_entity)
		if target == null or not is_instance_valid(target):
			return false
		return parent_entity != null and target.world == parent_entity.world
	if pkg.target_world != "" and parent_entity != null:
		return pkg.target_world == parent_entity.world
	return true


func _in_window(pkg: AIPackage, now: float) -> bool:
	if is_equal_approx(pkg.start_hour, pkg.end_hour):
		return true
	if pkg.start_hour < pkg.end_hour:
		return now >= pkg.start_hour and now < pkg.end_hour
	return now >= pkg.start_hour or now < pkg.end_hour
