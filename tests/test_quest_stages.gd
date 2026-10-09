## Integration tests for quest stages and the journal (WS-C story runtime).
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


func _make_npc(ref: StringName, pos: Vector3, world: StringName, covens: Dictionary = {}) -> SKEntity:
	var e := _EntityFixture.new()
	e.name = ref
	e.form_id = &"npc"
	e.world = world
	e.position = pos
	e.add_child(NPCComponent.new())
	e.add_child(NavigatorComponent.new())
	e.add_child(PuppetSpawnerComponent.new())
	e.add_child(InteractiveComponent.new())
	e.add_child(GOAPComponent.new())
	if not covens.is_empty():
		var cc := CovensComponent.new()
		var typed: Dictionary[StringName, int] = {}
		for k in covens:
			typed[StringName(k)] = int(covens[k])
		cc.covens = typed
		e.add_child(cc)
	for c in e.get_children():
		(c as Node).set_process(false)
		(c as Node).set_physics_process(false)
	_manager._add_entity_raw(e)
	return e


func _stage(index: int, objective: String, log: String, triggers: Array = [], completes := false, fails := false) -> QuestStage:
	var s := QuestStage.new()
	s.index = index
	s.objective = objective
	s.log_entry = log
	for t in triggers:
		s.trigger_nodes.append(t)
	s.completes_quest = completes
	s.fails_quest = fails
	return s


func _node(id: StringName, trigger: String, target: StringName, prereqs: Array = []) -> QuestNodeDefinition:
	var nd := QuestNodeDefinition.new()
	nd.id = id
	nd.trigger_type = trigger
	nd.target_id = target
	nd.required_count = 1
	for p in prereqs:
		nd.prerequisites.append(p)
	return nd


func _quest(qid: StringName, nodes: Array, stages: Array = []) -> QuestDefinition:
	var d := QuestDefinition.new()
	d.id = qid
	d.quest_name = "Test %s" % qid
	var typed_nodes: Array[QuestNodeDefinition] = []
	for n in nodes:
		typed_nodes.append(n)
	d.nodes = typed_nodes
	var typed_stages: Array[QuestStage] = []
	for s in stages:
		typed_stages.append(s)
	d.stages = typed_stages
	return d


func _stub_finder(candidates: Array) -> Callable:
	return func(filter: Dictionary) -> Array:
		var excluded: Array = filter.get("exclude_ids", [])
		return candidates.filter(func(c: Dictionary) -> bool: return not excluded.has(StringName(c.get("ref", ""))))


func _cand(ref: StringName, pos: Vector3) -> Dictionary:
	return {"ref": ref, "position": pos, "world": &"w"}


# ── Activation and auto-advance ──────────────────────────────────────────


func test_activation_logs_initial_stage() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_init", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Quest received."),
		_stage(20, "Later.", "Progress.", [&"n"]),
	])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_init"))
	var state := engine.get_quest_state(&"stage_init")
	assert_eq(state.current_stage, 10, "Lowest stage opens the journal.")
	assert_eq(state.journal.size(), 1, "Initial stage must log once.")
	assert_eq(int(state.journal[0]["stage"]), 10, "Logged entry carries its stage.")


func test_node_completion_advances_stage() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_auto", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Next.", "Advanced.", [&"n"]),
	])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_auto"))
	var results: Array = engine.apply_event(QuestEvent.new("talk", &"x", 1))
	assert_eq(results.size(), 1, "Event must affect the quest.")
	assert_eq(results[0].stages_advanced, [20], "Trigger must fire its stage.")
	var state := engine.get_quest_state(&"stage_auto")
	assert_eq(state.current_stage, 20, "Current stage must move.")
	assert_eq(state.journal.size(), 2, "Advance must log.")


func test_empty_trigger_stages_never_autofire() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_manual", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(30, "Secret.", "Hidden.", []),
	])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_manual"))
	engine.apply_event(QuestEvent.new("talk", &"x", 1))
	var state := engine.get_quest_state(&"stage_manual")
	assert_eq(state.journal.size(), 1, "Empty-trigger stages must not auto-fire.")
	assert_eq(state.current_stage, 10, "Current stage must hold.")


func test_stage_completion_ends_quest_with_xp() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_finish", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Done.", "Finished.", [&"n"], true),
	])
	def.xp_reward = 100
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_finish"))
	var results: Array = engine.apply_event(QuestEvent.new("talk", &"x", 1))
	assert_true(results[0].quest_completed, "Stage flag must complete the quest.")
	assert_eq(results[0].xp_reward, 100, "Stage completion must pay XP.")
	assert_eq(engine.get_quest_status(&"stage_finish"), "completed", "Status must flip.")


func test_stage_failure_ends_quest_without_xp() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_fail", [_node(&"n", "talk", &"x"), _node(&"m", "kill", &"y")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Failed.", "It went wrong.", [&"m"], false, true),
	])
	def.xp_reward = 100
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_fail"))
	var results: Array = engine.apply_event(QuestEvent.new("kill", &"y", 1))
	assert_true(results[0].quest_failed, "Fail flag must surface.")
	assert_false(results[0].quest_completed, "Failed quests must not complete.")
	assert_eq(results[0].xp_reward, 0, "Failed quests must not pay.")
	assert_eq(engine.get_quest_status(&"stage_fail"), "failed", "Status must flip.")
	assert_false(engine.activate_quest(&"stage_fail"), "Failed quests must not reactivate.")


# ── Explicit set_stage ───────────────────────────────────────────────────


func test_set_stage_advances_and_rejects() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_set", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(50, "Jumped.", "Skipped ahead."),
	])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_set"))
	assert_eq(engine.set_stage(&"stage_set", 50), "advanced", "Explicit jumps must apply.")
	var state := engine.get_quest_state(&"stage_set")
	assert_eq(state.current_stage, 50, "Current must move.")
	assert_eq(engine.set_stage(&"stage_set", 50), "", "Re-setting current must be a silent no-op.")
	assert_eq(engine.set_stage(&"stage_set", 99), "", "Unknown stages must be rejected.")
	assert_eq(engine.set_stage(&"missing", 10), "", "Unknown quests must be rejected.")


func test_set_stage_completion_and_failure() -> void:
	var engine := QuestGraphEngine.new()
	var done_def := _quest(&"stage_set_done", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Done.", "Finished.", [], true),
	])
	engine.register_quest(done_def)
	assert_true(engine.activate_quest(&"stage_set_done"))
	assert_eq(engine.set_stage(&"stage_set_done", 20), "completed", "Flagged stages must complete.")
	assert_eq(engine.get_quest_status(&"stage_set_done"), "completed", "Status must flip.")
	var doomed := _quest(&"stage_set_fail", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Ruined.", "Failed.", [], false, true),
	])
	engine.register_quest(doomed)
	assert_true(engine.activate_quest(&"stage_set_fail"))
	assert_eq(engine.set_stage(&"stage_set_fail", 20), "failed", "Flagged stages must fail.")
	assert_eq(engine.get_quest_status(&"stage_set_fail"), "failed", "Status must flip.")


# ── Journal content ──────────────────────────────────────────────────────


func test_journal_resolves_aliases_and_marks_done() -> void:
	var engine := QuestGraphEngine.new()
	engine.entity_finder = _stub_finder([_cand(&"snitch_a", Vector3.ZERO)])
	var def := _quest(&"stage_journal", [_node(&"n", "talk", &"{Mark}"), _node(&"m", "talk", &"other")], [
		_stage(10, "Find them.", "Talk to {Mark}."),
		_stage(20, "Done.", "Handled {Mark}.", [&"n"]),
	])
	var alias := QuestAlias.new()
	alias.id = &"Mark"
	alias.must_be_npc = false
	var typed_aliases: Array[QuestAlias] = [alias]
	def.aliases = typed_aliases
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_journal"))
	var journal := engine.get_journal(&"stage_journal")
	assert_eq(str(journal["name"]), "Test stage_journal", "Journal carries the quest name.")
	assert_eq(str(journal["status"]), "active", "Journal carries status.")
	assert_eq(int(journal["current_stage"]), 10, "Journal carries the current stage.")
	assert_true(str(journal["log"][0]["text"]).contains("snitch_a"), "Log must resolve aliases.")
	engine.apply_event(QuestEvent.new("talk", &"snitch_a", 1))
	journal = engine.get_journal(&"stage_journal")
	assert_eq((journal["objectives"] as Array).size(), 2, "Seen stages list as objectives.")
	assert_true(bool(journal["objectives"][0]["done"]), "Past stages read done.")
	assert_false(bool(journal["objectives"][1]["done"]), "Current stage reads open.")
	assert_eq(str(journal["objectives"][1]["text"]), "Done.", "Objective text comes from the stage.")


func test_stageless_journal_falls_back_to_nodes() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_none", [_node(&"n", "talk", &"x")], [])
	(def.nodes[0] as QuestNodeDefinition).description = "Talk to X."
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_none"))
	var journal := engine.get_journal(&"stage_none")
	assert_eq(int(journal["current_stage"]), -1, "Stageless quests have no current stage.")
	assert_eq((journal["objectives"] as Array).size(), 1, "Active nodes list as objectives.")
	assert_false(bool(journal["objectives"][0]["done"]), "Open nodes read open.")
	assert_eq((journal["log"] as Array).size(), 0, "Stageless quests log nothing.")
	assert_eq(engine.get_current_objective(&"stage_none"), "Talk to X.", "Fallback objective is the node text.")
	assert_eq(engine.get_journal(&"missing"), {}, "Unknown quests yield empty journals.")
	assert_eq(engine.get_current_objective(&"missing"), "", "Unknown quests yield empty objectives.")


# ── Validation and persistence ───────────────────────────────────────────


func test_validate_stages() -> void:
	var engine := QuestGraphEngine.new()
	var dup := _quest(&"v", [_node(&"n", "talk", &"x")], [
		_stage(10, "A.", "A."),
		_stage(10, "B.", "B."),
	])
	var dup_issues: Array = engine.validate_stages(dup)
	assert_eq(dup_issues.size(), 1, "Duplicate indices collapse to one issue.")
	assert_eq(str(dup_issues[0]["type"]), "duplicate_stage", "Issue must be typed.")
	var bad := _quest(&"v", [_node(&"n", "talk", &"x")], [
		_stage(10, "A.", "A.", [&"ghost"]),
	])
	var bad_issues: Array = engine.validate_stages(bad)
	assert_eq(bad_issues.size(), 1, "Unknown trigger nodes must be flagged.")
	assert_eq(str(bad_issues[0]["type"]), "bad_stage_trigger", "Issue must be typed.")
	var clean := _quest(&"v", [_node(&"n", "talk", &"x")], [
		_stage(10, "A.", "A."),
		_stage(20, "B.", "B.", [&"n"]),
	])
	assert_eq(engine.validate_stages(clean), [], "Sound stages validate clean.")


func test_save_restore_keeps_stages_and_journal() -> void:
	var engine := QuestGraphEngine.new()
	var def := _quest(&"stage_save", [_node(&"n", "talk", &"x"), _node(&"m", "talk", &"y")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Next.", "Advanced.", [&"n"]),
	])
	engine.register_quest(def)
	assert_true(engine.activate_quest(&"stage_save"))
	engine.apply_event(QuestEvent.new("talk", &"x", 1))
	var snapshot := engine.get_snapshot()
	var revived := QuestGraphEngine.new()
	revived.register_quest(def)
	revived.restore_snapshot(snapshot)
	var journal := revived.get_journal(&"stage_save")
	assert_eq(int(journal["current_stage"]), 20, "Current stage must survive.")
	assert_eq((journal["log"] as Array).size(), 2, "Journal must survive.")
	assert_eq(str(revived.get_current_objective(&"stage_save")), "Next.", "Objective must survive.")


# ── Authored demo quest with stages ──────────────────────────────────────


func test_tres_demo_stages_run_end_to_end() -> void:
	var def := load("res://quests/alias_demo_quest.tres") as QuestDefinition
	assert_ne(def, null, "Staged demo quest must load.")
	assert_eq(def.stages.size(), 3, "Demo must declare three stages.")
	var engine := QuestGraphEngine.new()
	assert_eq(engine.validate_stages(def), [], "Demo stages must validate clean.")
	assert_eq(engine.validate_aliases(def), [], "Demo aliases must validate clean.")
	var w: StringName = GameInfo.world
	_make_npc(&"guard", Vector3(100, 0, 0), w, {&"guards": 1})
	_make_npc(&"snitch_b", Vector3(50, 0, 0), w, {&"thieves": 1})
	_make_npc(&"snitch_a", Vector3(10, 0, 0), w, {&"thieves": 1})
	engine.entity_finder = QuestSystem._default_entity_finder
	engine.register_quest(def)
	assert_true(engine.activate_quest_with_params(&"demo_alias", {}, {"player_position": Vector3.ZERO, "world": w}))
	var journal := engine.get_journal(&"demo_alias")
	assert_eq(int(journal["current_stage"]), 10, "Activation must open stage 10.")
	assert_true(str(journal["log"][0]["text"]).contains("snitch_a"), "Stage 10 must name the filled mark.")
	engine.apply_event(QuestEvent.new("talk", &"snitch_a", 1))
	journal = engine.get_journal(&"demo_alias")
	assert_eq(int(journal["current_stage"]), 20, "Finding the mark must advance the stage.")
	engine.apply_event(QuestEvent.new("talk", &"guard", 1))
	assert_eq(engine.get_quest_status(&"demo_alias"), "completed", "Demo must complete end to end.")
	journal = engine.get_journal(&"demo_alias")
	assert_true(bool(journal["objectives"][0]["done"]) and bool(journal["objectives"][1]["done"]), "Finished quest objectives read done.")


# ── QuestSystem stage wiring ─────────────────────────────────────────────


func test_questsystem_set_stage_signals() -> void:
	var def := _quest(&"stage_sys", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Done.", "Finished.", [&"n"], true),
	])
	def.xp_reward = 40
	QuestSystem.register_quest(def)
	assert_true(QuestSystem.activate_quest(&"stage_sys"))
	watch_signals(QuestSystem)
	assert_eq(QuestSystem.set_stage(&"stage_sys", 20), "completed", "System must forward outcomes.")
	assert_signal_emit_count(QuestSystem, "quest_completed", 1, "Completion must emit.")
	var doomed := _quest(&"stage_sys_fail", [_node(&"n", "talk", &"x")], [
		_stage(10, "Begin.", "Started."),
		_stage(20, "Ruined.", "Failed.", [], false, true),
	])
	QuestSystem.register_quest(doomed)
	assert_true(QuestSystem.activate_quest(&"stage_sys_fail"))
	assert_eq(QuestSystem.set_stage(&"stage_sys_fail", 20), "failed", "System must forward failures.")
	assert_signal_emit_count(QuestSystem, "quest_failed", 1, "Failure must emit.")
	assert_true(QuestSystem.get_journal(&"stage_sys_fail")["objectives"][0]["done"] == false, "Failed objectives read open.")
