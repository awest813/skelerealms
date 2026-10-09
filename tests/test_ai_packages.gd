## Integration tests for AI packages (WS-B civilian daily life).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _ManagerFixture extends SKEntityManager:
	func _ready() -> void:
		pass


class _EntityFixture extends SKEntity:
	func _process(_delta: float) -> void:
		pass

	func get_component(type: String) -> SKEntityComponent:
		return get_node_or_null(type) as SKEntityComponent


class _StubPuppet extends Node3D:
	var movement_target_position := Vector3(999, 999, 999)

	func set_movement_target(pos: Vector3) -> void:
		movement_target_position = pos


var _manager: SKEntityManager
var _old_time: Dictionary


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)
	_old_time = GameInfo.world_time.duplicate()
	GameInfo.world_time[&"hour"] = 9
	GameInfo.world_time[&"minute"] = 0


func after_each() -> void:
	GameInfo.world_time = _old_time


# ── Fixture builders ─────────────────────────────────────────────────────


func _make_package(id: StringName, activity := &"loiter", priority := 0) -> AIPackage:
	var pkg := AIPackage.new()
	pkg.id = id
	pkg.activity = activity
	pkg.priority = priority
	return pkg


func _make_npc(ref: StringName, pos: Vector3, world: StringName, packages: Array = [], needs: Dictionary = {}) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"npc"
	e.world = world
	e.position = pos
	var npc := NPCComponent.new()
	var mover := preload("res://addons/skelerealms/scripts/ai/Modules/package_movement_module.gd").new()
	npc.add_child(mover)
	e.add_child(npc)
	e.add_child(NavigatorComponent.new())
	e.add_child(PuppetSpawnerComponent.new())
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	var pack := PackageComponent.new()
	for pkg in packages:
		pack.packages.append(pkg)
	e.add_child(pack)
	if not needs.is_empty():
		var needs_comp := NeedsComponent.new()
		e.add_child(needs_comp)
		for need_id in needs:
			needs_comp.set_need(need_id, needs[need_id])
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _pack_of(ref: StringName) -> PackageComponent:
	return (_manager.entities[ref] as SKEntity).get_component("PackageComponent") as PackageComponent


func _set_hour(hour: int, minute: int = 0) -> void:
	GameInfo.world_time[&"hour"] = hour
	GameInfo.world_time[&"minute"] = minute


# ── Evaluation ───────────────────────────────────────────────────────────


func test_time_windows() -> void:
	var day := _make_package(&"day", &"work")
	day.start_hour = 8.0
	day.end_hour = 18.0
	var night := _make_package(&"night", &"sleep")
	night.start_hour = 22.0
	night.end_hour = 6.0
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [day, night])
	var pack := _pack_of(&"c1")
	_set_hour(9)
	assert_eq(pack.evaluate().id, &"day", "Morning must work.")
	_set_hour(23)
	assert_eq(pack.evaluate().id, &"night", "Overnight windows must wrap past midnight.")
	_set_hour(3)
	assert_eq(pack.evaluate().id, &"night", "Early hours must hold the night package.")
	_set_hour(12)
	assert_eq(pack.evaluate().id, &"day", "Midday must work, not sleep.")


func test_always_window() -> void:
	var pkg := _make_package(&"idle", &"loiter")
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [pkg])
	assert_eq(_pack_of(&"c1").evaluate().id, &"idle", "Equal bounds must mean always.")


func test_need_gates() -> void:
	var meal := _make_package(&"meal", &"eat")
	meal.need_id = &"hunger"
	meal.need_min = 0.5
	var idle := _make_package(&"idle", &"loiter")
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [meal, idle], {&"hunger": 0.2})
	var pack := _pack_of(&"c1")
	assert_eq(pack.evaluate().id, &"idle", "Unmet needs must gate.")
	var needs_comp := e.get_component("NeedsComponent") as NeedsComponent
	needs_comp.set_need(&"hunger", 0.8)
	assert_eq(pack.evaluate().id, &"meal", "Met needs must open the gate.")


func test_need_gate_without_needs_component() -> void:
	var meal := _make_package(&"meal", &"eat")
	meal.need_id = &"hunger"
	meal.need_min = 1.0
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [meal])
	assert_eq(_pack_of(&"c1").evaluate(), null, "Need gates need a tracker to read.")


func test_priority_and_urgency() -> void:
	var feast := _make_package(&"feast", &"eat")
	feast.need_id = &"hunger"
	feast.need_min = 0.5
	var duty := _make_package(&"duty", &"work")
	duty.priority = 50
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [feast, duty], {&"hunger": 0.8})
	assert_eq(_pack_of(&"c1").evaluate().id, &"feast", "Need urgency must outbid base priority.")
	var first := _make_package(&"first", &"a")
	var second := _make_package(&"second", &"b")
	var e2 := _make_npc(&"c2", Vector3.ZERO, &"w", [first, second])
	assert_eq(_pack_of(&"c2").evaluate().id, &"first", "Ties must go to list order.")


func test_target_resolvability() -> void:
	_make_npc(&"target", Vector3(10, 0, 0), &"w", [])
	_make_npc(&"far_target", Vector3(10, 0, 0), &"elsewhere", [])
	var to_known := _make_package(&"to_known", &"visit")
	to_known.target_entity = &"target"
	var to_missing := _make_package(&"to_missing", &"visit")
	to_missing.target_entity = &"ghost"
	var to_far := _make_package(&"to_far", &"visit")
	to_far.target_entity = &"far_target"
	var to_fixed := _make_package(&"to_fixed", &"visit")
	to_fixed.target_position = Vector3(5, 0, 5)
	var to_wrong_world := _make_package(&"to_wrong_world", &"visit")
	to_wrong_world.target_position = Vector3(5, 0, 5)
	to_wrong_world.target_world = "elsewhere"
	var blank := _make_package(&"blank", &"loiter")
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [to_missing, to_far, to_wrong_world, to_known, to_fixed, blank])
	assert_eq(_pack_of(&"c1").evaluate().id, &"to_known", "First resolvable package must win.")


func test_change_signals_only_on_change() -> void:
	var b := _make_package(&"b", &"y")
	b.start_hour = 12.0
	b.end_hour = 13.0
	var ghost := _make_package(&"ghost", &"z")
	ghost.target_entity = &"nobody"
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [b, ghost])
	var pack := _pack_of(&"c1")
	watch_signals(pack)
	_set_hour(12)
	pack.evaluate()
	assert_signal_emit_count(pack, "package_changed", 1, "First pick must emit.")
	pack.evaluate()
	assert_signal_emit_count(pack, "package_changed", 1, "Steady state must stay quiet.")
	_set_hour(0)
	pack.evaluate()
	assert_signal_emit_count(pack, "package_changed", 2, "Falling idle must emit.")
	_set_hour(12)
	pack.evaluate()
	assert_signal_emit_count(pack, "package_changed", 3, "Returning must emit.")


func test_minute_tick_reevaluates() -> void:
	var b := _make_package(&"b", &"y")
	b.start_hour = 12.0
	b.end_hour = 13.0
	b.priority = 1
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [_make_package(&"a", &"x"), b])
	var pack := _pack_of(&"c1")
	_set_hour(9)
	assert_eq(pack.evaluate().id, &"a", "Setup must idle on A.")
	_set_hour(12)
	GameInfo.minute_incremented.emit()
	assert_eq(pack.active_package.id, &"b", "Minute ticks must re-evaluate.")


func test_validate_and_save() -> void:
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [_make_package(&"a"), _make_package(&"a")])
	var pack := _pack_of(&"c1")
	var issues: Array = pack.validate()
	assert_eq(issues.size(), 1, "Duplicate ids must be flagged.")
	assert_eq(str(issues[0]["type"]), "duplicate_package", "Issue must be typed.")
	pack.evaluate()
	var fresh := PackageComponent.new()
	fresh.packages = pack.packages
	fresh.load_data(pack.save())
	assert_eq(fresh.active_package.id, pack.active_package.id, "Active package must persist.")
	fresh.load_data({"active_package": "nope"})
	assert_eq(fresh.active_package, null, "Unknown ids must restore to idle.")


# ── Movement execution ───────────────────────────────────────────────────


func _stub_puppet_at(pos: Vector3) -> Node3D:
	var stub := _StubPuppet.new()
	stub.position = pos
	add_child_autofree(stub)
	return stub


func test_movement_steers_to_target() -> void:
	_make_npc(&"target", Vector3(20, 0, 0), &"w", [])
	var visit := _make_package(&"visit", &"visit")
	visit.target_entity = &"target"
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [visit])
	var pack := _pack_of(&"c1")
	pack.evaluate()
	var stub := _stub_puppet_at(Vector3.ZERO)
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, Vector3(20, 0, 0), "Puppets must steer to package targets.")


func test_fixed_destination_does_not_move_with_actor() -> void:
	var visit := _make_package(&"fixed", &"visit")
	visit.target_position = Vector3(20, 0, 0)
	var e := _make_npc(&"c1", Vector3(5, 0, 0), &"w", [visit])
	_pack_of(&"c1").evaluate()
	var stub := _stub_puppet_at(Vector3(5, 0, 0))
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, visit.target_position)
	e.position = Vector3(10, 0, 0)
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, visit.target_position, "Walking must not displace the destination.")


func _module_of(e: SKEntity) -> Node:
	var npc := e.get_component("NPCComponent") as NPCComponent
	for child in npc.get_children():
		if child.has_method("get_type") and child.get_type() == "PackageMovementModule":
			return child
	return null


func test_arrival_occupies_nearby_furniture_only() -> void:
	_make_npc(&"target", Vector3(20, 0, 0), &"w", [])
	var visit := _make_package(&"visit", &"visit")
	visit.target_entity = &"target"
	visit.furniture_tag = &"chair"
	var e := _make_npc(&"c1", Vector3(20, 0, 0), &"w", [visit])
	_pack_of(&"c1").evaluate()
	var near_chair := Furniture.new()
	near_chair.position = Vector3(20, 0, 1)
	near_chair.add_to_group(&"chair")
	add_child_autofree(near_chair)
	var far_chair := Furniture.new()
	far_chair.position = Vector3(500, 0, 500)
	far_chair.add_to_group(&"chair")
	add_child_autofree(far_chair)
	var stub := _stub_puppet_at(Vector3(20, 0, 0))
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_module_of(e)._on_updated(0.1)
	assert_true(near_chair._occupants.has("c1"), "Arrival must seat nearby furniture.")
	assert_false(far_chair._occupants.has("c1"), "Distant furniture must never seat.")
	assert_eq(stub.movement_target_position, Vector3(999, 999, 999), "Arrived puppets must hold.")
	(e.get_component("PackageComponent") as PackageComponent).active_package = null
	_module_of(e)._on_updated(0.1)
	assert_false(near_chair._occupants.has("c1"), "Expired packages must release furniture.")


func test_package_change_releases_and_retargets() -> void:
	_make_npc(&"t1", Vector3(20, 0, 0), &"w", [])
	_make_npc(&"t2", Vector3(-30, 0, 0), &"w", [])
	var first := _make_package(&"first", &"a")
	first.target_entity = &"t1"
	first.furniture_tag = &"chair"
	var second := _make_package(&"second", &"b")
	second.target_entity = &"t2"
	second.start_hour = 12.0
	second.end_hour = 13.0
	second.priority = 1
	var e := _make_npc(&"c1", Vector3(20, 0, 0), &"w", [first, second])
	var pack := _pack_of(&"c1")
	_set_hour(9)
	pack.evaluate()
	var chair := Furniture.new()
	chair.position = Vector3(20, 0, 1)
	chair.add_to_group(&"chair")
	add_child_autofree(chair)
	var stub := _stub_puppet_at(Vector3(20, 0, 0))
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_module_of(e)._on_updated(0.1)
	assert_true(chair._occupants.has("c1"), "Setup must seat.")
	_set_hour(12)
	pack.evaluate()
	_module_of(e)._on_updated(0.1)
	assert_false(chair._occupants.has("c1"), "Switches must free the old seat.")
	assert_eq(stub.movement_target_position, Vector3(-30, 0, 0), "Switches must retarget.")


func test_movement_yields() -> void:
	_make_npc(&"target", Vector3(20, 0, 0), &"w", [])
	var visit := _make_package(&"visit", &"visit")
	visit.target_entity = &"target"
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [visit])
	_pack_of(&"c1").evaluate()
	var stub := _stub_puppet_at(Vector3.ZERO)
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	var npc := e.get_component("NPCComponent") as NPCComponent
	npc._busy = true
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, Vector3(999, 999, 999), "Busy NPCs must not steer.")
	npc._busy = false
	e.add_child(CompanionComponent.new())
	var comp := e.get_component("CompanionComponent") as CompanionComponent
	comp.recruited = true
	comp.following = true
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, Vector3(999, 999, 999), "On-duty followers must ignore packages.")
	comp.following = false
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, Vector3(20, 0, 0), "Off-duty companions resume days.")


func test_no_package_or_target_means_idle() -> void:
	var e := _make_npc(&"c1", Vector3.ZERO, &"w", [])
	assert_eq(_pack_of(&"c1").evaluate(), null, "No packages must idle.")
	var stub := _stub_puppet_at(Vector3.ZERO)
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_module_of(e)._on_updated(0.1)
	assert_eq(stub.movement_target_position, Vector3(999, 999, 999), "Idle must not steer.")
	var missing := _make_package(&"gone", &"visit")
	missing.target_entity = &"nobody"
	var e2 := _make_npc(&"c2", Vector3.ZERO, &"w", [missing])
	assert_eq(_pack_of(&"c2").evaluate(), null, "Missing targets must idle, not error.")
