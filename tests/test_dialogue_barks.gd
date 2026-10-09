## Integration tests for dialogue barks and voice hooks (WS-D dialogue depth).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _TestContext extends DialogueContext:
	var skills := {}
	var flags := {}

	func get_skill_level(skill_id: StringName) -> int:
		return int(skills.get(skill_id, 0))

	func get_flag(flag: String) -> bool:
		return bool(flags.get(flag, false))


func after_each() -> void:
	for bark_id in [&"b_test", &"b_low", &"b_high", &"b_generic", &"b_specific", &"b_gated", &"b_sys"]:
		BarkSystem.unregister_bark(bark_id)


# ── Fixture builders ─────────────────────────────────────────────────────


func _bark(id: StringName, trigger := &"greet", speaker := &"", priority := 0) -> DialogueBark:
	var bark := DialogueBark.new()
	bark.id = id
	bark.trigger = trigger
	bark.speaker = speaker
	bark.text = "Line for %s." % id
	bark.priority = priority
	return bark


func _flag_condition(flag: String, value := true) -> DialogueChoiceCondition:
	var cond := DialogueChoiceCondition.new()
	cond.type = "flag"
	cond.flag = flag
	cond.flag_equals = value
	return cond


func _engine_with(barks: Array) -> BarkEngine:
	var engine := BarkEngine.new()
	for b in barks:
		engine.register_bark(b)
	return engine


# ── Shared condition semantics ───────────────────────────────────────────


func test_skill_gates_still_work_after_extraction() -> void:
	var engine := DialogueEngine.new()
	var def := DialogueDefinition.new()
	def.id = &"cond_check"
	def.start_node_id = &"n"
	var gated := DialogueChoice.new()
	gated.id = &"gated"
	gated.text = "Secret."
	gated.next_node_id = &""
	var cond := DialogueChoiceCondition.new()
	cond.type = "skill_min"
	cond.skill_id = &"sneak"
	cond.min_value = 5
	gated.conditions = [cond]
	var nd := DialogueNode.new()
	nd.id = &"n"
	nd.speaker = "X"
	nd.text = "Well?"
	nd.choices = [gated]
	def.nodes = [nd]
	engine.register_dialogue(def)
	var poor := _TestContext.new()
	assert_false(engine.create_session(&"cond_check", poor).get_current_node().choices[0].is_available, "Low skill must block.")
	var rich := _TestContext.new()
	rich.skills = {&"sneak": 9}
	assert_true(engine.create_session(&"cond_check", rich).get_current_node().choices[0].is_available, "High skill must pass.")


func test_voice_fields_reach_views() -> void:
	var engine := DialogueEngine.new()
	var def := DialogueDefinition.new()
	def.id = &"voice_check"
	def.start_node_id = &"n"
	var nd := DialogueNode.new()
	nd.id = &"n"
	nd.speaker = "X"
	nd.text = "Spoken."
	nd.voice_id = &"x_001"
	nd.display_seconds = 2.5
	nd.terminal = true
	def.nodes = [nd]
	engine.register_dialogue(def)
	var view := engine.create_session(&"voice_check", _TestContext.new()).get_current_node()
	assert_eq(view.voice_id, &"x_001", "Voice id must reach the view.")
	assert_eq(view.display_seconds, 2.5, "Hold time must reach the view.")


# ── Picking ──────────────────────────────────────────────────────────────


func test_priority_wins_registration_order() -> void:
	var engine := _engine_with([_bark(&"b_low", &"greet", &"", 1), _bark(&"b_high", &"greet", &"", 9)])
	var winner := engine.query(&"greet", &"anyone", _TestContext.new())
	assert_ne(winner, null, "Something must win.")
	assert_eq(winner.id, &"b_high", "Higher priority must win regardless of order.")


func test_generic_fallback() -> void:
	var engine := _engine_with([_bark(&"b_specific", &"greet", &"Guard"), _bark(&"b_generic", &"greet", &"")])
	assert_eq(engine.query(&"greet", &"Guard", _TestContext.new()).id, &"b_specific", "Specific speaker must win ties.")
	assert_eq(engine.query(&"greet", &"Stranger", _TestContext.new()).id, &"b_generic", "Generic must cover the rest.")
	assert_eq(engine.query(&"farewell", &"Guard", _TestContext.new()), null, "Wrong trigger must yield nothing.")


func test_conditions_gate_barks() -> void:
	var gated := _bark(&"b_gated", &"greet")
	gated.conditions = [_flag_condition("met_king")]
	var engine := _engine_with([gated])
	assert_eq(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Failing conditions must block.")
	var ctx := _TestContext.new()
	ctx.flags = {"met_king": true}
	assert_ne(engine.query(&"greet", &"anyone", ctx), null, "Passing conditions must allow.")


func test_chance_bounds_are_deterministic() -> void:
	var never := _bark(&"b_test", &"greet")
	never.chance = 0.0
	var always := _bark(&"b_test", &"greet")
	always.chance = 1.0
	var engine := _engine_with([never])
	assert_eq(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Zero chance must never fire.")
	engine.register_bark(always)
	assert_ne(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Full chance must fire.")


func test_failed_rolls_record_no_cooldown() -> void:
	var bark := _bark(&"b_test", &"greet")
	bark.chance = 0.0
	bark.cooldown_seconds = 600.0
	var engine := _engine_with([bark])
	assert_eq(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Setup miss must fail.")
	bark.chance = 1.0
	assert_ne(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Misses must not start cooldowns.")


func test_cooldown_gates_refire() -> void:
	var now := [100.0]
	var engine := _engine_with([_bark(&"b_test", &"greet")])
	engine.clock = func() -> float: return now[0]
	assert_ne(engine.query(&"greet", &"anyone", _TestContext.new()), null, "First bark must fire.")
	assert_eq(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Cooldown must block refire.")
	now[0] = 100.0 + 30.0
	assert_ne(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Expired cooldown must allow.")
	engine.unregister_bark(&"b_test")
	assert_eq(engine.query(&"greet", &"anyone", _TestContext.new()), null, "Unregistered barks must not fire.")


# ── Validation ───────────────────────────────────────────────────────────


func test_validate_bark() -> void:
	var engine := BarkEngine.new()
	var bad := DialogueBark.new()
	bad.id = &"bad"
	bad.chance = 2.0
	bad.cooldown_seconds = -1.0
	var issues: Array = engine.validate_bark(bad)
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("empty_trigger"), "Empty triggers must be flagged.")
	assert_true(kinds.has("empty_text"), "Empty text must be flagged.")
	assert_true(kinds.has("bad_chance"), "Out-of-range chance must be flagged.")
	assert_true(kinds.has("bad_cooldown"), "Negative cooldown must be flagged.")
	var good := _bark(&"b_test", &"greet", &"Guard")
	assert_eq(engine.validate_bark(good), [], "Sound barks validate clean.")


# ── BarkSystem ───────────────────────────────────────────────────────────


func test_system_say_emits_payload() -> void:
	var bark := _bark(&"b_sys", &"kill", &"Hunter")
	bark.voice_id = &"h_007"
	bark.display_seconds = 1.5
	BarkSystem.register_bark(bark)
	watch_signals(BarkSystem)
	var result := BarkSystem.say(&"kill", &"Hunter", _TestContext.new())
	assert_false(result.is_empty(), "Eligible bark must return a payload.")
	assert_eq(result["bark_id"], &"b_sys", "Payload must name the bark.")
	assert_eq(result["text"], "Line for b_sys.", "Payload must carry text.")
	assert_eq(result["voice_id"], &"h_007", "Payload must carry voice.")
	assert_signal_emit_count(BarkSystem, "bark_said", 1, "Firing must emit.")
	assert_eq(BarkSystem.say(&"dance", &"Hunter", _TestContext.new()), {}, "Nothing eligible must yield {}.")
