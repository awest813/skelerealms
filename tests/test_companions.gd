## Integration tests for the companion framework (WS-B people systems).
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


class _TestContext extends DialogueContext:
	pass


var _manager: SKEntityManager
var _old_world: StringName
var _old_origin: Node3D
var _old_max_party: int


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)
	_old_world = GameInfo.world
	_old_origin = GameInfo.world_origin
	_old_max_party = CompanionSystem.max_party_size


func after_each() -> void:
	GameInfo.world = _old_world
	GameInfo.world_origin = _old_origin
	CompanionSystem.max_party_size = _old_max_party


# ── Fixture builders ─────────────────────────────────────────────────────


## Full NPC stack with ticking disabled; the follow module is driven manually.
func _make_companion(ref: StringName, pos: Vector3, world: StringName, with_inventory := false) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"npc"
	e.world = world
	e.position = pos
	var npc := NPCComponent.new()
	var follow := preload("res://addons/skelerealms/scripts/ai/Modules/companion_follow_module.gd").new()
	npc.add_child(follow)
	e.add_child(npc)
	e.add_child(NavigatorComponent.new())
	e.add_child(PuppetSpawnerComponent.new())
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	e.add_child(TeleportComponent.new())
	e.add_child(CompanionComponent.new())
	if with_inventory:
		e.add_child(InventoryComponent.new())
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _companion_of(ref: StringName) -> CompanionComponent:
	return CompanionSystem.get_companion(ref)


func _set_anchor(pos: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.position = pos
	add_child_autofree(marker)
	GameInfo.world_origin = marker
	return marker


# ── Component data ───────────────────────────────────────────────────────


func test_component_save_load_round_trip() -> void:
	var e := _make_companion(&"c1", Vector3.ZERO, &"w")
	var comp := _companion_of(&"c1")
	comp.recruited = true
	comp.following = false
	comp.affinity = 42
	comp.home_world = "w"
	comp.home_position = Vector3(1, 2, 3)
	comp.carry_capacity = 50
	comp.affinity_perk_id = &"perk_bold"
	comp.follow_distance = 5.0
	comp.catchup_distance = 80.0
	var fresh := CompanionComponent.new()
	fresh.load_data(comp.save())
	assert_true(fresh.recruited, "Recruited must persist.")
	assert_false(fresh.following, "Waiting orders must persist.")
	assert_eq(fresh.affinity, 42, "Affinity must persist.")
	assert_eq(fresh.home_world, "w", "Home world must persist.")
	assert_eq(fresh.home_position, Vector3(1, 2, 3), "Home position must persist.")
	assert_eq(fresh.carry_capacity, 50, "Capacity must persist.")
	assert_eq(fresh.affinity_perk_id, &"perk_bold", "Perk hook must persist.")
	assert_eq(fresh.follow_distance, 5.0, "Follow distance must persist.")
	assert_eq(fresh.catchup_distance, 80.0, "Catchup distance must persist.")
	fresh.load_data({"affinity": 150})
	assert_eq(fresh.affinity, 100, "Affinity must clamp on load.")


func test_cargo_capacity() -> void:
	var e := _make_companion(&"c1", Vector3.ZERO, &"w", true)
	var comp := _companion_of(&"c1")
	assert_eq(comp.cargo_count(), 0, "Empty holds read zero.")
	assert_true(comp.can_carry(30), "Capacity default must allow 30.")
	var inv := e.get_component("InventoryComponent") as InventoryComponent
	inv.inventory = PackedStringArray(["a", "b"])
	assert_eq(comp.cargo_count(), 2, "Hold count must follow inventory.")
	assert_false(comp.can_carry(29), "Overflowing trades must be refused.")
	assert_true(comp.can_carry(28), "Exact fits must be allowed.")


# ── Roster ───────────────────────────────────────────────────────────────


func test_recruit_flow() -> void:
	var e := _make_companion(&"c1", Vector3(7, 0, 0), &"w")
	watch_signals(CompanionSystem)
	assert_true(CompanionSystem.recruit(&"c1"), "Recruit must succeed.")
	var comp := _companion_of(&"c1")
	assert_true(comp.recruited, "Flag must set.")
	assert_true(comp.following, "Recruits must follow by default.")
	assert_eq(comp.home_world, "w", "Home world must capture.")
	assert_eq(comp.home_position, Vector3(7, 0, 0), "Home position must capture.")
	assert_signal_emit_count(CompanionSystem, "companion_recruited", 1, "Recruit must emit.")
	assert_true(CompanionSystem.recruit(&"c1"), "Re-recruit must be idempotent.")
	assert_signal_emit_count(CompanionSystem, "companion_recruited", 1, "Idempotent recruit must not re-emit.")
	assert_eq(CompanionSystem.get_party(), [&"c1"], "Party must list recruits.")
	assert_false(CompanionSystem.recruit(&"ghost"), "Unknown refs must fail.")


func test_party_cap() -> void:
	CompanionSystem.max_party_size = 1
	_make_companion(&"c1", Vector3.ZERO, &"w")
	_make_companion(&"c2", Vector3.ZERO, &"w")
	assert_true(CompanionSystem.recruit(&"c1"), "First recruit must succeed.")
	assert_false(CompanionSystem.recruit(&"c2"), "Full parties must refuse.")
	assert_eq(CompanionSystem.get_party(), [&"c1"], "Party must hold one.")


func test_dismiss_teleports_home() -> void:
	var e := _make_companion(&"c1", Vector3(7, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	e.position = Vector3(90, 0, 90)
	watch_signals(CompanionSystem)
	assert_true(CompanionSystem.dismiss(&"c1"), "Dismiss must succeed.")
	var comp := _companion_of(&"c1")
	assert_false(comp.recruited, "Flag must clear.")
	assert_false(comp.following, "Orders must clear.")
	assert_eq(e.world, "w", "Dismiss must return home world.")
	assert_eq(e.position, Vector3(7, 0, 0), "Dismiss must return home position.")
	assert_signal_emit_count(CompanionSystem, "companion_dismissed", 1, "Dismiss must emit.")
	assert_false(CompanionSystem.dismiss(&"c1"), "Double dismiss must fail.")


func test_dismiss_without_home_stays_put() -> void:
	var e := _make_companion(&"c1", Vector3(7, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	var comp := _companion_of(&"c1")
	comp.home_world = ""
	e.position = Vector3(90, 0, 90)
	assert_true(CompanionSystem.dismiss(&"c1"), "Homeless dismiss must still clear flags.")
	assert_eq(e.position, Vector3(90, 0, 90), "Nowhere to send means stay put.")
	assert_false(comp.recruited, "Flags must clear regardless.")


func test_follow_orders() -> void:
	_make_companion(&"c1", Vector3.ZERO, &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	watch_signals(CompanionSystem)
	assert_true(CompanionSystem.set_following(&"c1", false), "Wait order must apply.")
	assert_false(_companion_of(&"c1").following, "Flag must clear.")
	assert_signal_emit_count(CompanionSystem, "follow_state_changed", 1, "Orders must emit.")
	assert_true(CompanionSystem.set_following(&"c1", false), "Repeat orders must succeed quietly.")
	assert_signal_emit_count(CompanionSystem, "follow_state_changed", 1, "Repeat orders must not re-emit.")
	assert_true(CompanionSystem.set_following(&"c1", true), "Follow order must apply.")
	assert_false(CompanionSystem.set_following(&"ghost", true), "Strangers take no orders.")


# ── Affinity ─────────────────────────────────────────────────────────────


func test_affinity_bands_and_milestones() -> void:
	_make_companion(&"c1", Vector3.ZERO, &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	assert_eq(CompanionSystem.get_affinity_level(&"c1"), "NEUTRAL", "Zero starts neutral.")
	assert_eq(CompanionSystem.level_for(-50), "FRACTURED", "Band edges must hold.")
	assert_eq(CompanionSystem.level_for(-49), "WARY", "Band edges must hold.")
	assert_eq(CompanionSystem.level_for(24), "NEUTRAL", "Band edges must hold.")
	assert_eq(CompanionSystem.level_for(25), "TRUSTED", "Band edges must hold.")
	assert_eq(CompanionSystem.level_for(60), "SWORN", "Band edges must hold.")
	watch_signals(CompanionSystem)
	assert_true(CompanionSystem.adjust_affinity(&"c1", 30, "quest"), "Adjust must succeed.")
	assert_eq(_companion_of(&"c1").affinity, 30, "Affinity must accumulate.")
	assert_signal_emit_count(CompanionSystem, "affinity_changed", 1, "Changes must emit.")
	assert_signal_emit_count(CompanionSystem, "affinity_milestone", 1, "Band crossings must emit.")
	assert_true(CompanionSystem.adjust_affinity(&"c1", -5, "rude"), "Small drops stay in band.")
	assert_signal_emit_count(CompanionSystem, "affinity_milestone", 1, "In-band moves must not re-emit.")
	assert_true(CompanionSystem.adjust_affinity(&"c1", 500, "hero"), "Overflow must clamp.")
	assert_eq(_companion_of(&"c1").affinity, 100, "Affinity must clamp high.")
	assert_false(CompanionSystem.adjust_affinity(&"ghost", 10), "Strangers have no affinity.")
	assert_eq(CompanionSystem.get_affinity(&"ghost"), 0, "Unknown refs read zero.")
	assert_eq(CompanionSystem.get_affinity_level(&"ghost"), "NEUTRAL", "Unknown refs read neutral.")


func test_fractured_companions_walk_away() -> void:
	var e := _make_companion(&"c1", Vector3(7, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	e.position = Vector3(90, 0, 90)
	watch_signals(CompanionSystem)
	assert_true(CompanionSystem.adjust_affinity(&"c1", -100, "betrayal"), "Break must apply.")
	assert_false(_companion_of(&"c1").recruited, "The betrayed must leave.")
	assert_eq(e.position, Vector3(7, 0, 0), "The betrayed must go home.")
	assert_signal_emit_count(CompanionSystem, "companion_left", 1, "Walking away must emit.")


# ── Follow steering ──────────────────────────────────────────────────────


func _steer(e: SKEntity) -> void:
	var npc := e.get_component("NPCComponent") as NPCComponent
	var module = null
	for child in npc.get_children():
		if child.has_method("get_type") and child.get_type() == "CompanionFollowModule":
			module = child
			break
	assert_ne(module, null, "Follow module must be attached.")
	module._on_updated(0.1)


func test_follow_steers_toward_player() -> void:
	GameInfo.world = &"w"
	_set_anchor(Vector3.ZERO)
	var e := _make_companion(&"c1", Vector3(10, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	var stub := _StubPuppet.new()
	add_child_autofree(stub)
	stub.position = Vector3(10, 0, 0)
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_steer(e)
	assert_true(stub.movement_target_position.distance_to(Vector3.ZERO) < 0.01, "Far puppets must target the player.")


func test_follow_holds_close_and_yields() -> void:
	GameInfo.world = &"w"
	_set_anchor(Vector3.ZERO)
	var e := _make_companion(&"c1", Vector3(1, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	var stub := _StubPuppet.new()
	add_child_autofree(stub)
	stub.position = Vector3(1, 0, 0)
	stub.movement_target_position = Vector3(77, 0, 77)
	(e.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent).puppet = stub
	_steer(e)
	assert_eq(stub.movement_target_position, Vector3(77, 0, 77), "Close puppets must keep their target.")
	var npc := e.get_component("NPCComponent") as NPCComponent
	npc._busy = true
	stub.position = Vector3(50, 0, 0)
	_steer(e)
	assert_eq(stub.movement_target_position, Vector3(77, 0, 77), "Busy companions must not steer.")
	npc._busy = false
	CompanionSystem.set_following(&"c1", false)
	_steer(e)
	assert_eq(stub.movement_target_position, Vector3(77, 0, 77), "Waiting companions must not steer.")


func test_follow_catches_up_across_distance_and_worlds() -> void:
	GameInfo.world = &"w"
	_set_anchor(Vector3.ZERO)
	var e := _make_companion(&"c1", Vector3(200, 0, 0), &"w")
	assert_true(CompanionSystem.recruit(&"c1"))
	_steer(e)
	assert_true(e.position.distance_to(Vector3.ZERO) < 5.0, "Far companions must teleport near.")
	assert_eq(e.world, "w", "World must hold.")
	e.world = &"elsewhere"
	e.position = Vector3(500, 0, 500)
	_steer(e)
	assert_eq(e.world, "w", "Cross-world companions must follow worlds.")
	assert_true(e.position.distance_to(Vector3.ZERO) < 5.0, "Cross-world companions must land near.")


func test_follow_needs_anchor_and_recruitment() -> void:
	GameInfo.world = &"w"
	GameInfo.world_origin = null
	var e := _make_companion(&"c1", Vector3(50, 0, 0), &"w")
	(e.get_component("NPCComponent") as NPCComponent).updated.emit(0.1)
	assert_eq(e.position, Vector3(50, 0, 0), "Anchorless steering must no-op without crashing.")
	_set_anchor(Vector3.ZERO)
	_steer(e)
	assert_eq(e.position, Vector3(50, 0, 0), "Unrecruited NPCs must ignore follow logic.")


func test_follow_module_without_companion_is_inert() -> void:
	GameInfo.world = &"w"
	_set_anchor(Vector3.ZERO)
	# Full NPC stack but no CompanionComponent: the module must stay silent.
	var e := _EntityFixture.new()
	e.name = &"plain"
	e.world = &"w"
	e.position = Vector3(50, 0, 0)
	var npc := NPCComponent.new()
	var follow := preload("res://addons/skelerealms/scripts/ai/Modules/companion_follow_module.gd").new()
	npc.add_child(follow)
	e.add_child(npc)
	e.add_child(NavigatorComponent.new())
	e.add_child(PuppetSpawnerComponent.new())
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	e.add_child(TeleportComponent.new())
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	follow._on_updated(0.1)
	assert_eq(e.position, Vector3(50, 0, 0), "Companionless entities must be inert, not errors.")


# ── Dialogue integration ─────────────────────────────────────────────────


func _recruit_choice(companion: StringName) -> DialogueChoice:
	var ch := DialogueChoice.new()
	ch.id = &"recruit"
	ch.text = "Join me."
	ch.next_node_id = &"done"
	return ch


func _recruit_tree(companion: StringName, effect: String) -> DialogueDefinition:
	var def := DialogueDefinition.new()
	def.id = &"recruit_demo"
	def.start_node_id = &"ask"
	var fx := DialogueChoiceEffect.new()
	fx.type = effect
	fx.companion_id = companion
	var ask := DialogueChoice.new()
	ask.id = &"ask"
	ask.text = "Will you come?"
	ask.next_node_id = &"done"
	ask.effects = [fx]
	var done := DialogueNode.new()
	done.id = &"done"
	done.speaker = "Companion"
	done.text = "Lead on."
	done.terminal = true
	var start := DialogueNode.new()
	start.id = &"ask"
	start.speaker = "Companion"
	start.text = "Maybe."
	start.choices = [ask]
	def.nodes = [start, done]
	return def


func test_dialogue_recruit_and_dismiss_effects() -> void:
	_make_companion(&"c1", Vector3.ZERO, &"w")
	var engine := DialogueEngine.new()
	engine.register_dialogue(_recruit_tree(&"c1", "recruit_companion"))
	var session := engine.create_session(&"recruit_demo", DialogueContext.new())
	session.choose(&"ask")
	assert_true(_companion_of(&"c1").recruited, "Recruit effect must recruit.")
	var engine2 := DialogueEngine.new()
	var def2 := _recruit_tree(&"c1", "dismiss_companion")
	(def2.nodes[0] as DialogueNode).choices[0].effects[0].type = "dismiss_companion"
	engine2.register_dialogue(def2)
	var session2 := engine2.create_session(&"recruit_demo", DialogueContext.new())
	session2.choose(&"ask")
	assert_false(_companion_of(&"c1").recruited, "Dismiss effect must dismiss.")


func test_dialogue_companion_conditions() -> void:
	_make_companion(&"c1", Vector3.ZERO, &"w")
	var engine := DialogueEngine.new()
	var gated := DialogueChoice.new()
	gated.id = &"secret"
	gated.text = "Tell me everything."
	gated.next_node_id = &""
	var cond := DialogueChoiceCondition.new()
	cond.type = "companion_recruited"
	cond.companion_id = &"c1"
	gated.conditions = [cond]
	var loyal := DialogueChoice.new()
	loyal.id = &"loyal"
	loyal.text = "For old times."
	loyal.next_node_id = &""
	var cond2 := DialogueChoiceCondition.new()
	cond2.type = "companion_affinity_min"
	cond2.companion_id = &"c1"
	cond2.min_value = 25
	loyal.conditions = [cond2]
	var start := DialogueNode.new()
	start.id = &"ask"
	start.speaker = "Companion"
	start.text = "Yes?"
	start.choices = [gated, loyal]
	var def := DialogueDefinition.new()
	def.id = &"cond_demo"
	def.start_node_id = &"ask"
	def.nodes = [start]
	engine.register_dialogue(def)
	var session := engine.create_session(&"cond_demo", DialogueContext.new())
	var view := session.get_current_node()
	assert_false(view.choices[0].is_available, "Strangers must be gated.")
	assert_false(view.choices[1].is_available, "Low affinity must gate.")
	assert_true(CompanionSystem.recruit(&"c1"), "Setup recruit must work.")
	CompanionSystem.adjust_affinity(&"c1", 30, "test")
	var session2 := engine.create_session(&"cond_demo", DialogueContext.new())
	var view2 := session2.get_current_node()
	assert_true(view2.choices[0].is_available, "Recruits must pass the gate.")
	assert_true(view2.choices[1].is_available, "High affinity must pass.")
