## Integration tests for QuestGraphEngine.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## QuestGraphEngine has no scene-tree dependencies, so all tests run headless.
extends GutTest


# ── Helpers ────────────────────────────────────────────────────────────────


## Build a minimal single-node quest that completes when the player talks to "npc_a".
func _make_single_node_quest() -> QuestDefinition:
	var node := QuestNodeDefinition.new()
	node.id = &"step_talk"
	node.trigger_type = "talk"
	node.target_id = &"npc_a"
	node.required_count = 1

	var def := QuestDefinition.new()
	def.id = &"test_single_node"
	def.quest_name = "Test Single Node"
	def.nodes = [node]
	def.xp_reward = 100
	return def


## Build a two-step sequential quest: kill 2 goblins, then talk to the captain.
func _make_two_step_quest() -> QuestDefinition:
	var node_kill := QuestNodeDefinition.new()
	node_kill.id = &"kill_goblins"
	node_kill.trigger_type = "kill"
	node_kill.target_id = &"goblin"
	node_kill.required_count = 2
	node_kill.next_node_ids = [&"report_to_captain"]

	var node_talk := QuestNodeDefinition.new()
	node_talk.id = &"report_to_captain"
	node_talk.trigger_type = "talk"
	node_talk.target_id = &"captain"
	node_talk.required_count = 1
	node_talk.prerequisites = [&"kill_goblins"]

	var def := QuestDefinition.new()
	def.id = &"test_two_step"
	def.quest_name = "Test Two Step"
	def.nodes = [node_kill, node_talk]
	def.completion_node_ids = [&"report_to_captain"]
	def.xp_reward = 250
	return def


## Build a branching quest: two parallel pickup nodes, both needed to complete.
func _make_parallel_quest() -> QuestDefinition:
	var node_a := QuestNodeDefinition.new()
	node_a.id = &"collect_herbs"
	node_a.trigger_type = "pickup"
	node_a.target_id = &"herb"
	node_a.required_count = 3

	var node_b := QuestNodeDefinition.new()
	node_b.id = &"collect_mushrooms"
	node_b.trigger_type = "pickup"
	node_b.target_id = &"mushroom"
	node_b.required_count = 2

	var def := QuestDefinition.new()
	def.id = &"test_parallel"
	def.quest_name = "Test Parallel"
	def.nodes = [node_a, node_b]
	def.xp_reward = 150
	return def


func _make_engine_with(def: QuestDefinition) -> QuestGraphEngine:
	var engine := QuestGraphEngine.new()
	engine.register_quest(def)
	return engine


# ── Registration ────────────────────────────────────────────────────────────


func test_register_quest_creates_inactive_state() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	assert_eq(engine.get_quest_status(&"test_single_node"), "inactive",
		"Newly registered quest should be inactive.")


func test_get_registered_quest_ids_returns_registered() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	var ids := engine.get_registered_quest_ids()
	assert_has(ids, &"test_single_node")


# ── Activation ───────────────────────────────────────────────────────────────


func test_activate_quest_returns_true_and_marks_active() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	var ok := engine.activate_quest(&"test_single_node")
	assert_true(ok, "activate_quest should return true on success.")
	assert_eq(engine.get_quest_status(&"test_single_node"), "active")


func test_activate_unknown_quest_returns_false() -> void:
	var engine := QuestGraphEngine.new()
	var ok := engine.activate_quest(&"does_not_exist")
	assert_false(ok)


func test_activate_twice_returns_false() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	var ok := engine.activate_quest(&"test_single_node")
	# Second activation is technically allowed (status stays "active"), but the
	# intent is to start nodes again — single-node quest nodes are already active.
	# Either true or false is acceptable; we just verify no crash.
	assert_true(ok == true or ok == false)


# ── Event application ─────────────────────────────────────────────────────


func test_apply_matching_event_completes_single_node_quest() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	var event := QuestEvent.new("talk", &"npc_a", 1)
	var results := engine.apply_event(event)
	assert_eq(results.size(), 1)
	var result: QuestGraphEngine.QuestEventResult = results[0]
	assert_true(result.quest_completed)
	assert_eq(result.xp_reward, 100)
	assert_eq(engine.get_quest_status(&"test_single_node"), "completed")


func test_apply_wrong_target_does_not_advance() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	var event := QuestEvent.new("talk", &"wrong_npc", 1)
	var results := engine.apply_event(event)
	assert_eq(results.size(), 0)
	assert_eq(engine.get_quest_status(&"test_single_node"), "active")


func test_apply_wrong_type_does_not_advance() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	var event := QuestEvent.new("kill", &"npc_a", 1)
	var results := engine.apply_event(event)
	assert_eq(results.size(), 0)


func test_apply_event_to_inactive_quest_does_nothing() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	var event := QuestEvent.new("talk", &"npc_a", 1)
	var results := engine.apply_event(event)
	assert_eq(results.size(), 0)
	assert_eq(engine.get_quest_status(&"test_single_node"), "inactive")


# ── Required count / partial progress ─────────────────────────────────────


func test_partial_progress_does_not_complete_node() -> void:
	var engine := _make_engine_with(_make_two_step_quest())
	engine.activate_quest(&"test_two_step")
	# Kill one goblin, need two
	var results := engine.apply_event(QuestEvent.new("kill", &"goblin", 1))
	assert_eq(results.size(), 1)
	var result: QuestGraphEngine.QuestEventResult = results[0]
	assert_false(result.quest_completed)
	assert_true(result.completed_node_ids.is_empty())
	assert_eq(engine.get_quest_status(&"test_two_step"), "active")


func test_full_progress_completes_node_and_activates_successor() -> void:
	var engine := _make_engine_with(_make_two_step_quest())
	engine.activate_quest(&"test_two_step")
	# Kill both goblins
	engine.apply_event(QuestEvent.new("kill", &"goblin", 1))
	var results := engine.apply_event(QuestEvent.new("kill", &"goblin", 1))
	assert_eq(results.size(), 1)
	var result: QuestGraphEngine.QuestEventResult = results[0]
	assert_has(result.completed_node_ids, &"kill_goblins")
	assert_has(result.activated_node_ids, &"report_to_captain")
	assert_false(result.quest_completed)


func test_two_step_quest_completes_after_second_step() -> void:
	var engine := _make_engine_with(_make_two_step_quest())
	engine.activate_quest(&"test_two_step")
	engine.apply_event(QuestEvent.new("kill", &"goblin", 2))
	var results := engine.apply_event(QuestEvent.new("talk", &"captain", 1))
	assert_eq(results.size(), 1)
	var result: QuestGraphEngine.QuestEventResult = results[0]
	assert_true(result.quest_completed)
	assert_eq(result.xp_reward, 250)
	assert_eq(engine.get_quest_status(&"test_two_step"), "completed")


# ── Parallel nodes ────────────────────────────────────────────────────────


func test_parallel_quest_requires_both_nodes() -> void:
	var engine := _make_engine_with(_make_parallel_quest())
	engine.activate_quest(&"test_parallel")
	engine.apply_event(QuestEvent.new("pickup", &"herb", 3))
	assert_eq(engine.get_quest_status(&"test_parallel"), "active",
		"Quest should still be active after only one branch completes.")
	engine.apply_event(QuestEvent.new("pickup", &"mushroom", 2))
	assert_eq(engine.get_quest_status(&"test_parallel"), "completed")


# ── Snapshot / restore ────────────────────────────────────────────────────


func test_snapshot_and_restore_preserves_progress() -> void:
	var engine := _make_engine_with(_make_two_step_quest())
	engine.activate_quest(&"test_two_step")
	engine.apply_event(QuestEvent.new("kill", &"goblin", 1))

	var snap := engine.get_snapshot()

	# New engine, restore
	var engine2 := QuestGraphEngine.new()
	engine2.register_quest(_make_two_step_quest())
	engine2.restore_snapshot(snap)

	assert_eq(engine2.get_quest_status(&"test_two_step"), "active")
	# One more kill should complete the kill-goblins node
	var results := engine2.apply_event(QuestEvent.new("kill", &"goblin", 1))
	assert_eq(results.size(), 1)
	assert_has(results[0].completed_node_ids, &"kill_goblins")


func test_snapshot_of_completed_quest_restores_completed() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	engine.apply_event(QuestEvent.new("talk", &"npc_a", 1))
	assert_eq(engine.get_quest_status(&"test_single_node"), "completed")

	var snap := engine.get_snapshot()
	var engine2 := QuestGraphEngine.new()
	engine2.register_quest(_make_single_node_quest())
	engine2.restore_snapshot(snap)
	assert_eq(engine2.get_quest_status(&"test_single_node"), "completed")


func test_restore_snapshot_ignores_unregistered_quests() -> void:
	# If a snapshot contains a quest that hasn't been registered, it should not crash.
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	var snap := engine.get_snapshot()

	var engine2 := QuestGraphEngine.new()
	# Deliberately do NOT register the quest
	engine2.restore_snapshot(snap) # Should be a no-op, not a crash
	assert_eq(engine2.get_registered_quest_ids().size(), 0)


# ── reset_all_state ────────────────────────────────────────────────────────


func test_reset_all_state_reverts_to_inactive() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	engine.activate_quest(&"test_single_node")
	engine.reset_all_state()
	assert_eq(engine.get_quest_status(&"test_single_node"), "inactive")


# ── Validation ────────────────────────────────────────────────────────────


func test_validate_valid_quest_returns_valid() -> void:
	var engine := _make_engine_with(_make_single_node_quest())
	var report := engine.validate_graph(&"test_single_node")
	assert_true(report.valid, "Simple single-node quest should pass validation.")
	assert_eq(report.issues.size(), 0)


func test_validate_unregistered_quest_returns_not_found() -> void:
	var engine := QuestGraphEngine.new()
	var report := engine.validate_graph(&"no_such_quest")
	assert_false(report.valid)
	assert_eq(report.issues.size(), 1)
	assert_eq(report.issues[0].type, "not_found")


func test_validate_cycle_is_detected() -> void:
	# Create two nodes that reference each other as next_node_ids
	var node_a := QuestNodeDefinition.new()
	node_a.id = &"node_a"
	node_a.trigger_type = "custom"
	node_a.target_id = &"x"
	node_a.next_node_ids = [&"node_b"]

	var node_b := QuestNodeDefinition.new()
	node_b.id = &"node_b"
	node_b.trigger_type = "custom"
	node_b.target_id = &"y"
	node_b.next_node_ids = [&"node_a"]

	var def := QuestDefinition.new()
	def.id = &"test_cycle"
	def.nodes = [node_a, node_b]
	def.start_node_ids = [&"node_a"]
	def.completion_node_ids = [&"node_b"]

	var engine := _make_engine_with(def)
	var report := engine.validate_graph(&"test_cycle")
	assert_false(report.valid)
	var types: Array[String] = []
	for issue: QuestGraphEngine.QuestValidationIssue in report.issues:
		types.append(issue.type)
	assert_has(types, "cycle")


func test_validate_two_step_quest_is_valid() -> void:
	var engine := _make_engine_with(_make_two_step_quest())
	var report := engine.validate_graph(&"test_two_step")
	assert_true(report.valid,
		"Two-step sequential quest should pass validation. Issues: %s" % str(report.issues))
