## Integration tests for the Radiant Story Manager (WS-C story runtime).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


var _owned_templates: Array = []


func after_each() -> void:
	for tid in _owned_templates:
		RadiantSystem.engine.unregister_template(StringName(tid))
	_owned_templates.clear()
	QuestSystem.reset_data()
	RadiantSystem.reset_data()
	RadiantSystem.auto_forward = true
	GameInfo.is_loading = false
	QuestSystem.engine.entity_finder = QuestSystem._default_entity_finder


## Register through the system and track for per-test cleanup, so templates
## never leak across tests (leaked templates would match later events).
func _register(t: RadiantTemplate) -> void:
	RadiantSystem.register_template(t)
	_owned_templates.append(StringName(t.id))


# ── Fixture builders ─────────────────────────────────────────────────────


func _node(id: StringName, trigger: String, target: StringName) -> QuestNodeDefinition:
	var nd := QuestNodeDefinition.new()
	nd.id = id
	nd.trigger_type = trigger
	nd.target_id = target
	nd.required_count = 1
	return nd


func _quest(qid: StringName, target: StringName) -> QuestDefinition:
	var d := QuestDefinition.new()
	d.id = qid
	d.quest_name = "Test %s" % qid
	var typed: Array[QuestNodeDefinition] = [_node(&"n", "kill", target)]
	d.nodes = typed
	return d


func _template(tid: StringName, quest_id: StringName, target: StringName, event_target := &"", cooldown := 60, max_active := 1) -> RadiantTemplate:
	var t := RadiantTemplate.new()
	t.id = tid
	t.quest_template = _quest(quest_id, target)
	t.trigger_type = "kill"
	t.trigger_target = event_target
	t.cooldown_minutes = cooldown
	t.max_active = max_active
	return t


func _kill(target: StringName) -> QuestEvent:
	return QuestEvent.new("kill", target, 1)


# ── Engine: planning ─────────────────────────────────────────────────────


func test_matching_trigger_plans_issuance() -> void:
	var re := RadiantEngine.new()
	re.register_template(_template(&"wolf_hunt", &"wolf_hunt_q", &"wolf", &"wolf"))
	var plans: Array = re.plan_issuance(_kill(&"wolf"), 0)
	assert_eq(plans.size(), 1, "Matching event must plan one issuance.")
	assert_eq(String(plans[0]["instance_id"]), "wolf_hunt_001", "First instance takes _001.")
	assert_eq(String((plans[0]["template"] as RadiantTemplate).id), "wolf_hunt", "Plan carries its template.")


func test_trigger_target_filtering() -> void:
	var re := RadiantEngine.new()
	re.register_template(_template(&"wolf_only", &"wolf_only_q", &"wolf", &"wolf"))
	assert_eq(re.plan_issuance(_kill(&"bear"), 0).size(), 0, "Wrong target must not plan.")
	var re_any := RadiantEngine.new()
	re_any.register_template(_template(&"any_kill", &"any_kill_q", &"wolf", &""))
	assert_eq(re_any.plan_issuance(_kill(&"bear"), 0).size(), 1, "Empty target must match any target.")
	assert_eq(re_any.plan_issuance(QuestEvent.new("talk", &"bear", 1), 0).size(), 0, "Wrong type must not plan.")


func test_cooldown_gates_reissue() -> void:
	var re := RadiantEngine.new()
	re.register_template(_template(&"cd", &"cd_q", &"wolf", &"", 60, 99))
	assert_eq(re.plan_issuance(_kill(&"wolf"), 0).size(), 1, "First plan must pass.")
	re.record_issuance(&"cd", &"cd_001", 0)
	assert_eq(re.plan_issuance(_kill(&"wolf"), 30).size(), 0, "Cooldown must block early reissue.")
	var plans: Array = re.plan_issuance(_kill(&"wolf"), 60)
	assert_eq(plans.size(), 1, "Cooldown expiry must allow reissue.")
	assert_eq(String(plans[0]["instance_id"]), "cd_002", "Numbering must advance, never reuse.")


func test_max_active_caps_parallel_instances() -> void:
	var qe := QuestGraphEngine.new()
	var re := RadiantEngine.new()
	re.quest_engine = qe
	re.register_template(_template(&"cap", &"cap_q", &"wolf", &"", 0, 1))
	var inst: QuestDefinition = (_template(&"cap", &"cap_q", &"wolf").quest_template as QuestDefinition).duplicate(true)
	inst.id = &"cap_001"
	qe.register_quest(inst)
	assert_true(qe.activate_quest(&"cap_001"))
	re.record_issuance(&"cap", &"cap_001", 0)
	assert_eq(re.plan_issuance(_kill(&"wolf"), 0).size(), 0, "Active instance must block.")
	qe.apply_event(QuestEvent.new("kill", &"wolf", 1))
	var plans: Array = re.plan_issuance(_kill(&"wolf"), 0)
	assert_eq(plans.size(), 1, "Completed instances must free the cap.")
	assert_eq(String(plans[0]["instance_id"]), "cap_002", "Numbering must not reuse ids.")


# ── Engine: validate / snapshot ──────────────────────────────────────────


func test_validate_template() -> void:
	var re := RadiantEngine.new()
	var broken := RadiantTemplate.new()
	broken.id = &"broken"
	assert_true((re.validate_template(broken)[0] as Dictionary)["type"] == "missing_quest", "Missing quest must be flagged.")
	var no_trigger := _template(&"notrig", &"notrig_q", &"wolf")
	no_trigger.trigger_type = ""
	var trig_issues: Array = re.validate_template(no_trigger)
	assert_eq(trig_issues.size(), 1, "Empty trigger must be flagged.")
	assert_eq(str(trig_issues[0]["type"]), "empty_trigger", "Issue must be typed.")
	var good := _template(&"good", &"good_q", &"wolf", &"wolf")
	assert_eq(re.validate_template(good), [], "Sound templates validate clean.")


func test_engine_snapshot_round_trip() -> void:
	var re := RadiantEngine.new()
	re.register_template(_template(&"snap", &"snap_q", &"wolf"))
	re.record_issuance(&"snap", &"snap_001", 42)
	var revived := RadiantEngine.new()
	revived.register_template(_template(&"snap", &"snap_q", &"wolf"))
	revived.restore_snapshot(re.get_snapshot())
	assert_eq(revived.get_instances(), {&"snap_001": &"snap"}, "Instance map must survive.")
	assert_eq(revived.plan_issuance(_kill(&"wolf"), 50).size(), 0, "Cooldown must survive.")
	var plans: Array = revived.plan_issuance(_kill(&"wolf"), 102)
	assert_eq(String(plans[0]["instance_id"]), "snap_002", "Counters must survive.")


func test_unregister_quest() -> void:
	var qe := QuestGraphEngine.new()
	qe.register_quest(_quest(&"gone", &"wolf"))
	assert_true(qe.activate_quest(&"gone"))
	qe.unregister_quest(&"gone")
	assert_eq(qe.get_quest_status(&"gone"), "inactive", "Unregistered quests read inactive.")
	assert_false(qe.validate_graph(&"gone").valid, "Unregistered quests fail validation.")


# ── System: end-to-end issuance ──────────────────────────────────────────


func test_system_issues_and_signals() -> void:
	RadiantSystem.ticks = 0
	_register(_template(&"sys", &"sys_q", &"wolf", &"wolf", 60, 1))
	watch_signals(RadiantSystem)
	watch_signals(QuestSystem)
	var issued: Array = RadiantSystem.notify_event(_kill(&"wolf"))
	assert_eq(issued, [&"sys_001"], "System must issue and return the id.")
	assert_eq(QuestSystem.get_quest_status(&"sys_001"), "active", "Instance must activate.")
	assert_signal_emit_count(RadiantSystem, "radiant_quest_issued", 1, "Issuance must emit.")
	assert_signal_emit_count(QuestSystem, "quest_activated", 1, "Activation must emit.")
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")).size(), 0, "Cooldown must block immediate reissue.")
	QuestSystem.apply_event(_kill(&"wolf"))
	assert_eq(QuestSystem.get_quest_status(&"sys_001"), "completed", "Setup completion must land.")
	RadiantSystem.ticks = 60
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")), [&"sys_002"], "Cooldown expiry must issue onward.")


func test_system_respects_loading_and_forward_flag() -> void:
	_register(_template(&"load", &"load_q", &"wolf", &"", 0, 99))
	GameInfo.is_loading = true
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")), [], "Loading must suspend issuance.")
	GameInfo.is_loading = false
	RadiantSystem.auto_forward = false
	QuestSystem.apply_event(_kill(&"wolf"))
	assert_eq(QuestSystem.get_quest_status(&"load_001"), "inactive", "Disabled forwarding must not issue.")
	RadiantSystem.auto_forward = true
	QuestSystem.apply_event(_kill(&"wolf"))
	assert_eq(QuestSystem.get_quest_status(&"load_001"), "active", "Quest events must auto-forward.")


func test_system_save_load_cycle() -> void:
	RadiantSystem.ticks = 0
	_register(_template(&"cyc", &"cyc_q", &"wolf", &"", 60, 1))
	RadiantSystem.ticks = 10
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")), [&"cyc_001"], "Setup issuance must work.")
	var quest_blob := QuestSystem.save()
	var radiant_blob := RadiantSystem.save()
	QuestSystem.reset_data()
	RadiantSystem.reset_data()
	QuestSystem.load_data(quest_blob)
	RadiantSystem.load_data(radiant_blob)
	assert_eq(QuestSystem.get_quest_status(&"cyc_001"), "active", "Instances must reactivate on load.")
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")).size(), 0, "Restored cooldown must hold.")
	QuestSystem.apply_event(_kill(&"wolf"))
	assert_eq(QuestSystem.get_quest_status(&"cyc_001"), "completed", "Setup completion must land.")
	RadiantSystem.ticks = 70
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")), [&"cyc_002"], "Numbering must continue past restores.")


func test_system_load_skips_missing_templates() -> void:
	_register(_template(&"gone_mod", &"gone_mod_q", &"wolf", &"", 0, 99))
	assert_eq(RadiantSystem.notify_event(_kill(&"wolf")), [&"gone_mod_001"], "Setup issuance must work.")
	var radiant_blob := RadiantSystem.save()
	# Simulate a removed mod: template AND instance definition go away.
	RadiantSystem.engine.unregister_template(&"gone_mod")
	QuestSystem.unregister_quest(&"gone_mod_001")
	QuestSystem.reset_data()
	RadiantSystem.reset_data()
	RadiantSystem.load_data(radiant_blob)
	assert_eq(QuestSystem.get_quest_status(&"gone_mod_001"), "inactive", "Orphaned instances must stay down.")
