## Integration tests for dialogue scenes and persuasion attempts.
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _TestContext extends DialogueContext:
	var skills := {}
	var dispositions := {}
	var flags_set: Array = []

	func get_skill_level(skill_id: StringName) -> int:
		return int(skills.get(skill_id, 0))

	func get_disposition(speaker: String) -> int:
		return int(dispositions.get(speaker, 0))

	func set_flag(flag: String, value: bool) -> void:
		flags_set.append([flag, value])


func after_each() -> void:
	DialogueSystem.end_dialogue()


# ── Fixture builders ─────────────────────────────────────────────────────


func _choice(id: StringName, text: String, next: StringName = &"", check_skill := &"", dc := 0, fail_to := &"") -> DialogueChoice:
	var ch := DialogueChoice.new()
	ch.id = id
	ch.text = text
	ch.next_node_id = next
	ch.attempt_skill = check_skill
	ch.attempt_difficulty = dc
	ch.fail_next_node_id = fail_to
	return ch


func _node(id: StringName, speaker: String, text: String, choices: Array = [], terminal := false) -> DialogueNode:
	var nd := DialogueNode.new()
	nd.id = id
	nd.speaker = speaker
	nd.text = text
	nd.terminal = terminal
	var typed: Array[DialogueChoice] = []
	for ch in choices:
		typed.append(ch)
	nd.choices = typed
	return nd


func _persuade_tree() -> DialogueDefinition:
	var def := DialogueDefinition.new()
	def.id = &"persuade_demo"
	def.start_node_id = &"greet"
	var bribe := _choice(&"bribe", "How about 50 gold?", &"papers", &"speechcraft", 30, &"refused")
	var papers := _choice(&"papers", "Here are my papers.", &"papers")
	var leave := _choice(&"leave", "Move along.", &"")
	def.nodes = [
		_node(&"greet", "Guard", "Halt, citizen.", [bribe, papers]),
		_node(&"papers", "Guard", "These look fine.", [leave]),
		_node(&"refused", "Guard", "That won't work.", [leave]),
	] as Array[DialogueNode]
	return def


func _scene_tree() -> DialogueDefinition:
	var def := DialogueDefinition.new()
	def.id = &"scene_demo"
	def.start_node_id = &"s1"
	def.nodes = [
		_node(&"s1", "A", "A speaks.", [_choice(&"to_b", "Go on.", &"s2")]),
		_node(&"s2", "B", "B answers.", [_choice(&"bye", "Farewell.", &"")]),
	] as Array[DialogueNode]
	return def


func _make_scene() -> DialogueScene:
	var scene := DialogueScene.new()
	scene.id = &"parley"
	scene.dialogue_id = &"scene_demo"
	scene.participants = [&"GuardCaptain", &"Sidekick", &"player"]
	scene.cast = {&"s1": &"GuardCaptain", &"s2": &"Sidekick"}
	scene.greet_radius = 3.0
	return scene


func _engine_with(def: DialogueDefinition) -> DialogueEngine:
	var engine := DialogueEngine.new()
	engine.register_dialogue(def)
	return engine


## Find seeds whose first d100 roll lands on each side of 50. Self-calibrating:
## independent of engine RNG version, guaranteed to terminate in practice.
func _find_seeds() -> Array:
	var good := -1
	var bad := -1
	for s in range(1, 500):
		var r := RandomNumberGenerator.new()
		r.seed = s
		if r.randf_range(0.0, 100.0) < 50.0 and good < 0:
			good = s
		elif bad < 0:
			bad = s
		if good >= 0 and bad >= 0:
			break
	return [good, bad]


# ── Persuasion attempts ──────────────────────────────────────────────────


func test_attempt_success_applies_effects_and_advances() -> void:
	var seeds := _find_seeds()
	assert_true(seeds[0] >= 0 and seeds[1] >= 0, "Calibration seeds must exist.")
	var engine := _engine_with(_persuade_tree())
	var ctx := _TestContext.new()
	ctx.skills = {&"speechcraft": 30} # chance = 50 + 30 − 30 = 50
	var session := engine.create_session(&"persuade_demo", ctx)
	session.rng.seed = seeds[0]
	var result := session.choose(&"bribe")
	assert_true(result.attempted, "Attempt must be flagged.")
	assert_true(result.attempt_succeeded, "Rigged roll must succeed.")
	assert_true(result.success, "Success must apply.")
	assert_eq(result.current_node.id, &"papers", "Success must follow next_node_id.")


func test_attempt_failure_takes_fail_branch() -> void:
	var seeds := _find_seeds()
	var engine := _engine_with(_persuade_tree())
	var ctx := _TestContext.new()
	ctx.skills = {&"speechcraft": 30}
	var session := engine.create_session(&"persuade_demo", ctx)
	session.rng.seed = seeds[1]
	var result := session.choose(&"bribe")
	assert_true(result.attempted, "Attempt must be flagged.")
	assert_false(result.attempt_succeeded, "Rigged roll must fail.")
	assert_true(result.success, "Fail branch must still apply.")
	assert_eq(result.current_node.id, &"refused", "Failure must follow fail_next_node_id.")


func test_attempt_without_fail_target_fizzles() -> void:
	var def := DialogueDefinition.new()
	def.id = &"fizzle_demo"
	def.start_node_id = &"greet"
	var risky := _choice(&"risky", "Try it.", &"papers", &"speechcraft", 0, &"")
	def.nodes = [
		_node(&"greet", "Guard", "Well?", [risky]),
		_node(&"papers", "Guard", "Fine.", [_choice(&"leave", "Bye.", &"")]),
	] as Array[DialogueNode]
	var engine := _engine_with(def)
	var session := engine.create_session(&"fizzle_demo", _TestContext.new())
	session.rng.seed = 1
	var before := session.get_current_node()
	var result := session.choose(&"risky")
	if result.attempt_succeeded:
		assert_eq(result.current_node.id, &"papers", "Lucky success must advance.")
	else:
		assert_false(result.success, "Fizzle must not report success.")
		assert_eq(result.message, "Persuasion failed.", "Fizzle must explain itself.")
		assert_eq(session.get_current_node().id, before.id, "Fizzle must hold position.")


func test_choice_views_advertise_attempts() -> void:
	var engine := _engine_with(_persuade_tree())
	var session := engine.create_session(&"persuade_demo", _TestContext.new())
	var view := session.get_current_node()
	var bribe_view = null
	var papers_view = null
	for cv in view.choices:
		if cv.id == &"bribe":
			bribe_view = cv
		elif cv.id == &"papers":
			papers_view = cv
	assert_eq(bribe_view.attempt_skill, &"speechcraft", "UI must see the check.")
	assert_eq(bribe_view.attempt_difficulty, 30, "UI must see the difficulty.")
	assert_eq(papers_view.attempt_skill, &"", "Plain choices advertise nothing.")


func test_fail_effects_apply_only_on_failure() -> void:
	var def := DialogueDefinition.new()
	def.id = &"fx_demo"
	def.start_node_id = &"greet"
	var eff := DialogueChoiceEffect.new()
	eff.type = "set_flag"
	eff.flag = "bribed"
	eff.flag_value = true
	var bad_eff := DialogueChoiceEffect.new()
	bad_eff.type = "set_flag"
	bad_eff.flag = "offended"
	bad_eff.flag_value = true
	var attempt := _choice(&"try", "Try.", &"papers", &"speechcraft", 30, &"refused")
	attempt.effects = [eff]
	attempt.fail_effects = [bad_eff]
	def.nodes = [
		_node(&"greet", "Guard", "Well?", [attempt]),
		_node(&"papers", "Guard", "Fine.", [_choice(&"leave", "Bye.", &"")]),
		_node(&"refused", "Guard", "No.", [_choice(&"leave2", "Bye.", &"")]),
	] as Array[DialogueNode]
	var seeds := _find_seeds()
	var engine := _engine_with(def)
	var ctx := _TestContext.new()
	ctx.skills = {&"speechcraft": 30}
	var won := engine.create_session(&"fx_demo", ctx)
	won.rng.seed = seeds[0]
	won.choose(&"try")
	assert_true(ctx.flags_set.has(["bribed", true]), "Success must apply effects.")
	assert_false(ctx.flags_set.has(["offended", true]), "Success must skip fail effects.")
	var ctx2 := _TestContext.new()
	ctx2.skills = {&"speechcraft": 30}
	var lost := engine.create_session(&"fx_demo", ctx2)
	lost.rng.seed = seeds[1]
	lost.choose(&"try")
	assert_true(ctx2.flags_set.has(["offended", true]), "Failure must apply fail effects.")
	assert_false(ctx2.flags_set.has(["bribed", true]), "Failure must skip success effects.")


func test_validate_flags_persuasion_gaps() -> void:
	var engine := DialogueEngine.new()
	var dangling := _choice(&"try", "Try.", &"papers", &"speechcraft", 10, &"ghost")
	var bare := _choice(&"try2", "Try.", &"papers", &"speechcraft", 10, &"")
	var def := DialogueDefinition.new()
	def.id = &"v"
	def.start_node_id = &"greet"
	def.nodes = [
		_node(&"greet", "Guard", "Well?", [dangling, bare]),
		_node(&"papers", "Guard", "Fine.", [], true),
	] as Array[DialogueNode]
	var issues: Array = engine.validate_definition(def)
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("dangling_fail_branch"), "Bad fail targets must be flagged.")
	assert_true(kinds.has("check_without_fail"), "Checks without fail branches must be flagged.")


# ── Scene runner ─────────────────────────────────────────────────────────


func _make_runner(def: DialogueDefinition) -> DialogueSceneRunner:
	var runner := DialogueSceneRunner.new()
	var engine := DialogueEngine.new()
	engine.register_dialogue(def)
	runner.dialogue_engine = engine
	return runner


func test_scene_plays_with_cast_and_blocking() -> void:
	var runner := _make_runner(_scene_tree())
	var ctx := _TestContext.new()
	assert_true(runner.start(_make_scene(), ctx), "Full cast must start.")
	assert_eq(runner.current_speaker(), &"GuardCaptain", "Cast must override the speaker.")
	assert_eq(runner.get_blocked_actors(), [&"GuardCaptain", &"Sidekick", &"player"], "Cast must report blocked.")
	var result := runner.advance(&"to_b")
	assert_true(result.success, "Advance must work.")
	assert_eq(runner.current_speaker(), &"Sidekick", "Cast must follow nodes.")
	var fin := runner.advance(&"bye")
	assert_true(fin.is_complete, "Final choice must end the tree.")
	assert_false(runner.is_running(), "Runner must stop at tree end.")
	assert_eq(runner.get_blocked_actors(), [], "Blocked list must release.")


func test_scene_start_requires_cast() -> void:
	var runner := _make_runner(_scene_tree())
	runner.participant_provider = func(_parts: Array) -> Array: return [&"GuardCaptain"]
	assert_false(runner.start(_make_scene(), _TestContext.new()), "Missing cast must block.")
	assert_true(runner.last_error.contains("Sidekick"), "Error must name the missing.")
	assert_false(runner.is_running(), "Failed starts must not run.")


func test_scene_required_subset() -> void:
	var runner := _make_runner(_scene_tree())
	var scene := _make_scene()
	scene.required_participants = [&"GuardCaptain"]
	runner.participant_provider = func(_parts: Array) -> Array: return [&"GuardCaptain"]
	assert_true(runner.start(scene, _TestContext.new()), "Required subset must suffice.")


func test_scene_end_releases() -> void:
	var runner := _make_runner(_scene_tree())
	assert_true(runner.start(_make_scene(), _TestContext.new()))
	runner.end()
	assert_false(runner.is_running(), "End must stop.")
	assert_eq(runner.get_blocked_actors(), [], "End must release.")


func test_scene_advance_without_start_fails() -> void:
	var runner := _make_runner(_scene_tree())
	var result := runner.advance(&"to_b")
	assert_false(result.success, "Advance without start must fail.")
	assert_true(result.is_complete, "Failed advance must report completion.")


func test_greet_range() -> void:
	var scene := _make_scene()
	assert_true(DialogueSceneRunner.in_greet_range(scene, Vector3.ZERO, Vector3(0, 0, 2)), "Inside radius must greet.")
	assert_false(DialogueSceneRunner.in_greet_range(scene, Vector3.ZERO, Vector3(0, 0, 30)), "Outside radius must not greet.")
	scene.greet_radius = 0.0
	assert_false(DialogueSceneRunner.in_greet_range(scene, Vector3.ZERO, Vector3.ZERO), "Zero radius disables greet.")


func test_scene_save_restore() -> void:
	var runner := _make_runner(_scene_tree())
	assert_true(runner.start(_make_scene(), _TestContext.new()))
	runner.advance(&"to_b")
	var snap := runner.get_snapshot()
	var runner2 := _make_runner(_scene_tree())
	assert_true(runner2.restore_snapshot(snap, _make_scene(), _TestContext.new()), "Restore must resume.")
	assert_eq(runner2.current_speaker(), &"Sidekick", "Resume must restore position and cast.")
	assert_eq(runner2.get_blocked_actors().size(), 3, "Resume must restore blocking.")


func test_scene_restore_rejects_bad_data() -> void:
	var runner := _make_runner(_scene_tree())
	assert_false(runner.restore_snapshot({}, _make_scene(), _TestContext.new()), "Malformed snapshots must fail.")
	var other := DialogueScene.new()
	other.id = &"other"
	other.dialogue_id = &"missing_tree"
	assert_false(runner.restore_snapshot({"session": {}}, other, _TestContext.new()), "Unknown trees must fail.")


# ── DialogueSystem hosting ───────────────────────────────────────────────


func test_system_hosts_scene_and_overrides_speaker() -> void:
	DialogueSystem.register_dialogue(_scene_tree())
	DialogueSystem.register_scene(_make_scene())
	var view := DialogueSystem.start_scene(&"parley", _TestContext.new())
	assert_ne(view, null, "Scene must start.")
	assert_eq(view.speaker, &"GuardCaptain", "System views must carry the cast.")
	assert_eq(DialogueSystem.get_current_node().speaker, &"GuardCaptain", "Current node must carry the cast.")
	assert_eq(DialogueSystem.get_blocked_actors().size(), 3, "System must report blocking.")
	DialogueSystem.choose(&"to_b")
	assert_eq(DialogueSystem.get_current_node().speaker, &"Sidekick", "Cast must follow through the system.")
	DialogueSystem.stop_scene()
	assert_false(DialogueSystem.is_in_dialogue(), "Stop must clear the session.")


func test_system_greet_gates_on_range() -> void:
	DialogueSystem.register_dialogue(_scene_tree())
	DialogueSystem.register_scene(_make_scene())
	assert_ne(DialogueSystem.try_greet(&"parley", Vector3.ZERO, Vector3(0, 0, 1), _TestContext.new()), null, "Close greets must start.")
	DialogueSystem.stop_scene()
	assert_eq(DialogueSystem.try_greet(&"parley", Vector3.ZERO, Vector3(0, 0, 99)), null, "Far greets must not start.")
	assert_eq(DialogueSystem.try_greet(&"missing", Vector3.ZERO, Vector3.ZERO), null, "Unknown scenes must not start.")


func test_system_scene_save_load() -> void:
	DialogueSystem.register_dialogue(_scene_tree())
	DialogueSystem.register_scene(_make_scene())
	DialogueSystem.start_scene(&"parley", _TestContext.new())
	DialogueSystem.choose(&"to_b")
	var blob := DialogueSystem.save()
	assert_true(blob.has("active_scene"), "Running scenes must save as scenes.")
	DialogueSystem.end_dialogue()
	DialogueSystem.load_data(blob)
	assert_true(DialogueSystem.is_in_dialogue(), "Scene must resume from save.")
	assert_eq(DialogueSystem.get_current_node().speaker, &"Sidekick", "Resume must restore position and cast.")
	DialogueSystem.end_dialogue()
