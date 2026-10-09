## Integration tests for quest aliases (QuestAlias fill + resolution).
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


var _manager: SKEntityManager


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)


func after_each() -> void:
	QuestSystem.reset_data()
	QuestSystem.engine.entity_finder = QuestSystem._default_entity_finder


# ── Fixture builders ─────────────────────────────────────────────────────


## Fabricate a live entity with the full NPC component stack (ticking
## disabled — the finder only needs structure and data, not AI frames).
func _make_npc(ref: StringName, pos: Vector3, world: StringName, covens: Dictionary = {}, form: StringName = &"npc") -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = form
	e.world = world
	e.position = pos
	e.add_child(NPCComponent.new())
	e.add_child(NavigatorComponent.new())
	e.add_child(PuppetSpawnerComponent.new())
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	if not covens.is_empty():
		var cc := CovensComponent.new()
		var typed_covens: Dictionary[StringName, int] = {}
		for k in covens:
			typed_covens[StringName(k)] = int(covens[k])
		cc.covens = typed_covens
		e.add_child(cc)
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _make_prop(ref: StringName, pos: Vector3, world: StringName) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"prop"
	e.world = world
	e.position = pos
	_manager._add_entity_raw(e)
	return e


func _alias(id: StringName, npc := true, coven := &"", form := &"", exclude: Array = [], nearest := &"", optional := false) -> QuestAlias:
	var a := QuestAlias.new()
	a.id = id
	a.must_be_npc = npc
	a.required_coven = coven
	a.required_form = form
	for x in exclude:
		a.exclude_ids.append(x)
	a.nearest_to = nearest
	a.optional = optional
	return a


func _node(id: StringName, trigger: String, target: StringName, prereqs: Array = []) -> QuestNodeDefinition:
	var nd := QuestNodeDefinition.new()
	nd.id = id
	nd.trigger_type = trigger
	nd.target_id = target
	nd.required_count = 1
	for p in prereqs:
		nd.prerequisites.append(p)
	return nd


func _quest(qid: StringName, aliases: Array, nodes: Array) -> QuestDefinition:
	var d := QuestDefinition.new()
	d.id = qid
	var typed_aliases: Array[QuestAlias] = []
	for a in aliases:
		typed_aliases.append(a)
	d.aliases = typed_aliases
	var typed_nodes: Array[QuestNodeDefinition] = []
	for n in nodes:
		typed_nodes.append(n)
	d.nodes = typed_nodes
	return d


## Test-double finder. Honors exclude_ids like the real contract requires,
## so chained-alias tests behave faithfully.
func _stub_finder(candidates: Array) -> Callable:
	return func(filter: Dictionary) -> Array:
		var excluded: Array = filter.get("exclude_ids", [])
		return candidates.filter(func(c: Dictionary) -> bool: return not excluded.has(StringName(c.get("ref", ""))))


func _cand(ref: StringName, pos: Vector3, world := &"w") -> Dictionary:
	return {"ref": ref, "position": pos, "world": world}


# ── Fill selection ───────────────────────────────────────────────────────


func test_fill_picks_coven_member_by_default_finder() -> void:
	var w: StringName = GameInfo.world
	_make_npc(&"guard", Vector3(100, 0, 0), w, {&"guards": 1})
	_make_npc(&"snitch_b", Vector3(50, 0, 0), w, {&"thieves": 1})
	_make_npc(&"snitch_a", Vector3(10, 0, 0), w, {&"thieves": 1})
	_make_prop(&"crate", Vector3(5, 0, 0), w)
	var engine := QuestGraphEngine.new()
	engine.entity_finder = QuestSystem._default_entity_finder
	var def := _quest(&"alias_coven", [_alias(&"Mark", true, &"thieves")], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest_with_params(&"alias_coven", {}, {"player_position": Vector3.ZERO, "world": w}))
	# First registry match among thieves, in insertion order.
	assert_eq(engine.get_alias_ref(&"alias_coven", &"Mark"), &"snitch_b")


func test_fill_nearest_to_player() -> void:
	var w: StringName = GameInfo.world
	_make_npc(&"far", Vector3(90, 0, 0), w, {&"thieves": 1})
	_make_npc(&"near", Vector3(8, 0, 0), w, {&"thieves": 1})
	var engine := QuestGraphEngine.new()
	engine.entity_finder = QuestSystem._default_entity_finder
	var def := _quest(&"alias_near", [_alias(&"Mark", true, &"thieves", &"", [], &"player")], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest_with_params(&"alias_near", {}, {"player_position": Vector3.ZERO, "world": w}))
	assert_eq(engine.get_alias_ref(&"alias_near", &"Mark"), &"near")


func test_fill_respects_exclude_and_form() -> void:
	var w: StringName = GameInfo.world
	_make_npc(&"giver", Vector3(1, 0, 0), w, {}, &"quest_giver")
	_make_npc(&"thug", Vector3(2, 0, 0), w, {}, &"thug")
	var engine := QuestGraphEngine.new()
	engine.entity_finder = QuestSystem._default_entity_finder
	var def := _quest(&"alias_filter", [_alias(&"Mark", true, &"", &"thug", [&"giver"])], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"alias_filter"))
	assert_eq(engine.get_alias_ref(&"alias_filter", &"Mark"), &"thug")


func test_fill_chains_to_earlier_alias() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"den", Vector3(0, 0, 0)), _cand(&"lookout", Vector3(30, 0, 0))])
	var def := _quest(&"alias_chain", [
		_alias(&"Den", false),
		_alias(&"Lookout", false, &"", &"", [&"den"], &"Den"),
	], [_node(&"n", "talk", &"{Lookout}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"alias_chain"))
	assert_eq(engine.get_alias_ref(&"alias_chain", &"Den"), &"den")
	# Lookout is nearest to the den (30m), not the player.
	assert_eq(engine.get_alias_ref(&"alias_chain", &"Lookout"), &"lookout")


func test_optional_miss_activates_required_miss_blocks() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([])
	var maybe := _quest(&"alias_optional", [_alias(&"Ghost", false, &"", &"", [], &"", true)], [_node(&"n", "talk", &"{Ghost}")])
	engine.register_quest(maybe)
	assert_true(engine.activate_quest(&"alias_optional"), "Optional miss must not block activation.")
	assert_eq(engine.get_alias_ref(&"alias_optional", &"Ghost"), &"", "Missed optional stays empty.")
	var must := _quest(&"alias_required", [_alias(&"Ghost")], [_node(&"n", "talk", &"{Ghost}")])
	engine.register_quest(must)
	assert_false(engine.activate_quest(&"alias_required"), "Required miss must block activation.")
	assert_eq(engine.get_quest_status(&"alias_required"), "inactive", "Failed fill must not flip status.")
	assert_false(engine.last_alias_error.is_empty(), "Failure must explain itself.")


func test_no_finder_blocks_required_but_not_plain() -> void:
	var engine := QuestGraphEngine.new()
	var with_alias := _quest(&"alias_nofinder", [_alias(&"Mark")], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(with_alias)
	assert_false(engine.activate_quest(&"alias_nofinder"), "Alias quest without a finder must not activate.")
	var plain := _quest(&"plain_nofinder", [], [_node(&"n", "talk", &"anyone")])
	engine.register_quest(plain)
	assert_true(engine.activate_quest(&"plain_nofinder"), "Aliasless quests must not need a finder.")


func test_unknown_anchor_fails() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"x", Vector3.ZERO)])
	var def := _quest(&"alias_badanchor", [_alias(&"A", false, &"", &"", [], &"Nope")], [_node(&"n", "talk", &"{A}")])
	engine.register_quest(def)
	assert_false(engine.activate_quest(&"alias_badanchor"), "Unknown anchors must fail loudly.")


# ── Match-time resolution ────────────────────────────────────────────────


func test_events_match_only_the_filled_ref() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"snitch_a", Vector3.ZERO), _cand(&"snitch_b", Vector3.ZERO)])
	var def := _quest(&"alias_match", [_alias(&"Mark", false)], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"alias_match"))
	assert_eq(engine.get_alias_ref(&"alias_match", &"Mark"), &"snitch_a")
	engine.apply_event(QuestEvent.new("talk", &"snitch_b", 1))
	assert_eq(engine.get_quest_status(&"alias_match"), "active", "Wrong ref must not advance.")
	engine.apply_event(QuestEvent.new("talk", &"snitch_a", 1))
	assert_eq(engine.get_quest_status(&"alias_match"), "completed", "Filled ref must advance.")


func test_explicit_params_take_precedence_over_fills() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"snitch_a", Vector3.ZERO)])
	var def := _quest(&"alias_param", [_alias(&"Mark", false)], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest_with_params(&"alias_param", {"Mark": "override"}))
	# The definition was rewritten to the literal; the fill is shadowed.
	engine.apply_event(QuestEvent.new("talk", &"override", 1))
	assert_eq(engine.get_quest_status(&"alias_param"), "completed", "Explicit params must win.")


func test_unfilled_placeholder_matches_nothing() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([])
	var def := _quest(&"alias_empty", [_alias(&"Ghost", false, &"", &"", [], &"", true)], [_node(&"n", "talk", &"{Ghost}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"alias_empty"))
	engine.apply_event(QuestEvent.new("talk", &"anyone", 1))
	assert_eq(engine.get_quest_status(&"alias_empty"), "active", "Unresolved placeholders must be inert, not errors.")


# ── Persistence ──────────────────────────────────────────────────────────


func test_save_restore_keeps_fills() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"snitch_a", Vector3.ZERO)])
	var def := _quest(&"alias_save", [_alias(&"Mark", false)], [_node(&"n", "talk", &"{Mark}")])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"alias_save"))
	var snapshot := engine.get_snapshot()
	var revived := QuestGraphEngine.new()
	revived.entity_finder = _stub_finder([])
	revived.register_quest(def)
	revived.restore_snapshot(snapshot)
	assert_eq(revived.get_alias_ref(&"alias_save", &"Mark"), &"snitch_a", "Fills must survive save/load.")
	assert_eq(revived.get_alias_refs(&"alias_save"), {&"Mark": &"snitch_a"}, "Bulk read must round-trip.")
	revived.apply_event(QuestEvent.new("talk", &"snitch_a", 1))
	assert_eq(revived.get_quest_status(&"alias_save"), "completed", "Restored quests must still match fills.")


func test_alias_refill_is_atomic_and_clears_optional_misses() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"refill", [_alias(&"A", false), _alias(&"B", false, &"", &"", [&"first", &"replacement"])], [])
	engine.register_quest(def)
	engine.entity_finder = _stub_finder([_cand(&"first", Vector3.ZERO), _cand(&"second", Vector3.ONE)])
	assert_true(engine.fill_aliases(&"refill"))
	var original := engine.get_alias_refs(&"refill")
	engine.entity_finder = _stub_finder([_cand(&"replacement", Vector3.ZERO)])
	assert_false(engine.fill_aliases(&"refill"))
	assert_eq(engine.get_alias_refs(&"refill"), original, "Failed fills must preserve the previous complete set.")
	def.aliases[1].optional = true
	assert_true(engine.fill_aliases(&"refill"))
	assert_eq(engine.get_alias_ref(&"refill", &"B"), &"", "Optional misses must clear stale refs.")


# ── Authoring validation ──────────────────────────────────────────────────


func test_validate_aliases() -> void:
	var engine := QuestGraphEngine.new()
	var dup := _quest(&"v", [_alias(&"A"), _alias(&"A")], [])
	assert_eq(engine.validate_aliases(dup).size(), 1, "Duplicate ids collapse to one issue.")
	assert_eq(str(engine.validate_aliases(dup)[0]["type"]), "duplicate_alias", "Issue must be typed.")
	var bad := _quest(&"v", [_alias(&"A", false, &"", &"", [], &"Ghost")], [])
	var bad_issues: Array = engine.validate_aliases(bad)
	assert_eq(bad_issues.size(), 1, "Unknown anchors must be flagged.")
	assert_eq(str(bad_issues[0]["type"]), "bad_anchor", "Issue must be typed.")
	var fwd := _quest(&"v", [_alias(&"A", false, &"", &"", [], &"B"), _alias(&"B")], [])
	var fwd_issues: Array = engine.validate_aliases(fwd)
	assert_eq(fwd_issues.size(), 1, "Forward anchors must be flagged.")
	assert_eq(str(fwd_issues[0]["type"]), "forward_anchor", "Issue must be typed.")
	var clean := _quest(&"v", [_alias(&"A"), _alias(&"B", false, &"", &"", [], &"A")], [])
	assert_eq(engine.validate_aliases(clean), [], "Player/earlier anchors and dup-free ids are clean.")


# ── Authored demo quest (.tres) ──────────────────────────────────────────


func test_tres_demo_quest_loads_and_runs() -> void:
	var def := load("res://quests/alias_demo_quest.tres") as QuestDefinition
	assert_ne(def, null, "Demo quest resource must load.")
	assert_eq(def.aliases.size(), 1, "Demo quest must declare one alias.")
	var engine := QuestGraphEngine.new()
	assert_eq(engine.validate_aliases(def), [], "Demo aliases must validate clean.")
	var w: StringName = GameInfo.world
	_make_npc(&"guard", Vector3(100, 0, 0), w, {&"guards": 1})
	_make_npc(&"snitch_b", Vector3(50, 0, 0), w, {&"thieves": 1})
	_make_npc(&"snitch_a", Vector3(10, 0, 0), w, {&"thieves": 1})
	engine.entity_finder = QuestSystem._default_entity_finder
	engine.register_quest(def)
	assert_true(engine.activate_quest_with_params(&"demo_alias", {}, {"player_position": Vector3.ZERO, "world": w}))
	assert_eq(engine.get_alias_ref(&"demo_alias", &"Mark"), &"snitch_a", "Mark must be the nearest thief.")
	engine.apply_event(QuestEvent.new("talk", &"snitch_b", 1))
	assert_eq(engine.get_quest_status(&"demo_alias"), "active", "Wrong NPC must not advance the demo.")
	engine.apply_event(QuestEvent.new("talk", &"snitch_a", 1))
	engine.apply_event(QuestEvent.new("talk", &"guard", 1))
	assert_eq(engine.get_quest_status(&"demo_alias"), "completed", "Demo quest must complete end to end.")


# ── QuestSystem wiring ───────────────────────────────────────────────────


func test_questsystem_installs_finder_and_resolves() -> void:
	assert_true(QuestSystem.engine.entity_finder.is_valid(), "Autoload must install the default finder.")
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"snitch_a", Vector3.ZERO)])
	var def := _quest(&"alias_sys", [_alias(&"Mark", false)], [_node(&"n", "talk", &"{Mark}")])
	var previous: Callable = QuestSystem.engine.entity_finder
	QuestSystem.engine.entity_finder = engine.entity_finder
	QuestSystem.register_quest(def)
	assert_true(QuestSystem.activate_quest(&"alias_sys"))
	assert_eq(QuestSystem.resolve_alias(&"alias_sys", &"Mark"), &"snitch_a", "System must resolve fills.")
	assert_eq(QuestSystem.get_alias_refs(&"alias_sys"), {&"Mark": &"snitch_a"}, "System must expose all fills.")
	QuestSystem.engine.entity_finder = previous
