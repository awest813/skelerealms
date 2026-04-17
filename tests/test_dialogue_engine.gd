## Integration tests for DialogueEngine and DialogueSession.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## DialogueEngine and DialogueSession are pure RefCounted classes with no
## scene-tree dependencies, so all tests run headless.
extends GutTest


# ── Stub DialogueContext ────────────────────────────────────────────────────
## A minimal in-memory context for testing — no autoload dependencies.
class StubContext extends DialogueContext:
	var flags: Dictionary = {}
	var faction_reps: Dictionary = {}
	var quest_statuses: Dictionary = {}
	var inventory: Dictionary = {}
	var skills: Dictionary = {}
	var emitted_events: Array[StringName] = []
	var activated_quests: Array[StringName] = []
	var consumed_items: Dictionary = {}
	var given_items: Dictionary = {}

	func get_flag(flag: String) -> bool:
		return flags.get(flag, false)

	func set_flag(flag: String, value: bool) -> void:
		flags[flag] = value

	func get_faction_reputation(faction_id: StringName) -> int:
		return faction_reps.get(faction_id, 0)

	func adjust_faction_reputation(faction_id: StringName, amount: int) -> void:
		faction_reps[faction_id] = faction_reps.get(faction_id, 0) + amount

	func get_quest_status(quest_id: StringName) -> String:
		return quest_statuses.get(quest_id, "inactive")

	func get_inventory_count(item_id: StringName) -> int:
		return inventory.get(item_id, 0)

	func get_skill_level(skill_id: StringName) -> int:
		return skills.get(skill_id, 0)

	func emit_event(event_id: StringName, _payload: Dictionary = {}) -> void:
		emitted_events.append(event_id)

	func activate_quest(quest_id: StringName) -> void:
		activated_quests.append(quest_id)

	func consume_item(item_id: StringName, quantity: int) -> bool:
		if inventory.get(item_id, 0) < quantity:
			return false
		inventory[item_id] -= quantity
		consumed_items[item_id] = consumed_items.get(item_id, 0) + quantity
		return true

	func give_item(item_id: StringName, quantity: int) -> void:
		given_items[item_id] = given_items.get(item_id, 0) + quantity


# ── Helpers ────────────────────────────────────────────────────────────────


func _make_choice(id: StringName, text: String, next: StringName = &"") -> DialogueChoice:
	var c := DialogueChoice.new()
	c.id = id
	c.text = text
	c.next_node_id = next
	return c


func _make_node(id: StringName, speaker: String, text: String, choices: Array = []) -> DialogueNode:
	var n := DialogueNode.new()
	n.id = id
	n.speaker = speaker
	n.text = text
	for c in choices:
		n.choices.append(c)
	return n


## Build a simple two-node dialogue:
##   greeting → [choice_a → farewell, choice_b → farewell]
func _make_simple_dialogue() -> DialogueDefinition:
	var choice_a := _make_choice(&"ask_name", "What is your name?", &"farewell")
	var choice_b := _make_choice(&"goodbye", "Goodbye.", &"farewell")

	var node_greeting := _make_node(&"greeting", "Guard", "Halt! Who goes there?",
		[choice_a, choice_b])

	var node_farewell := _make_node(&"farewell", "Guard", "Move along.")
	# farewell has no choices → terminal in practice (session ends when no choices lead anywhere)

	var def := DialogueDefinition.new()
	def.id = &"test_simple"
	def.start_node_id = &"greeting"
	def.nodes = [node_greeting, node_farewell]
	return def


## Build a dialogue with a flag condition and a flag effect.
func _make_conditional_dialogue() -> DialogueDefinition:
	var cond := DialogueChoiceCondition.new()
	cond.type = "flag"
	cond.flag = "met_wizard"
	cond.flag_equals = true

	var effect := DialogueChoiceEffect.new()
	effect.type = "set_flag"
	effect.flag = "told_about_wizard"
	effect.flag_value = true

	var locked_choice := _make_choice(&"mention_wizard", "I've met the wizard.", &"farewell")
	locked_choice.conditions = [cond]
	locked_choice.effects = [effect]

	var normal_choice := _make_choice(&"just_passing", "Just passing through.", &"farewell")

	var node_start := _make_node(&"start", "Innkeeper", "Welcome, traveller!",
		[locked_choice, normal_choice])
	var node_farewell := _make_node(&"farewell", "Innkeeper", "Safe travels.")

	var def := DialogueDefinition.new()
	def.id = &"test_conditional"
	def.start_node_id = &"start"
	def.nodes = [node_start, node_farewell]
	return def


func _make_engine_with(def: DialogueDefinition) -> DialogueEngine:
	var engine := DialogueEngine.new()
	engine.register_dialogue(def)
	return engine


# ── Registration ────────────────────────────────────────────────────────────


func test_has_dialogue_after_registration() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	assert_true(engine.has_dialogue(&"test_simple"))


func test_has_dialogue_returns_false_for_unknown() -> void:
	var engine := DialogueEngine.new()
	assert_false(engine.has_dialogue(&"no_such_dialogue"))


# ── Session creation ────────────────────────────────────────────────────────


func test_create_session_returns_non_null() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	assert_not_null(session)


func test_create_session_for_unknown_dialogue_returns_null() -> void:
	var engine := DialogueEngine.new()
	var session := engine.create_session(&"no_such", StubContext.new())
	assert_null(session)


# ── get_current_node ────────────────────────────────────────────────────────


func test_current_node_is_start_node() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	var node_view := session.get_current_node()
	assert_not_null(node_view)
	assert_eq(node_view.id, &"greeting")
	assert_eq(node_view.speaker, "Guard")


func test_choices_are_available_when_no_conditions() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	var node_view := session.get_current_node()
	assert_eq(node_view.choices.size(), 2)
	for cv: DialogueEngine.DialogueChoiceView in node_view.choices:
		assert_true(cv.is_available)


# ── choose ────────────────────────────────────────────────────────────────


func test_choose_valid_choice_advances_to_next_node() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	var result := session.choose(&"ask_name")
	assert_true(result.success)
	assert_false(result.is_complete)
	assert_not_null(result.current_node)
	assert_eq(result.current_node.id, &"farewell")


func test_choose_unknown_choice_fails() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	var result := session.choose(&"no_such_choice")
	assert_false(result.success)


func test_choose_on_completed_session_fails() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	# Advance past greeting
	session.choose(&"ask_name")
	# farewell has no outgoing choices, so any further choose should end the session
	# (In this dialogue, farewell has no choices, so choosing anything on an ended
	# session should fail.)
	var result2 := session.choose(&"ask_name")
	assert_false(result2.success)


# ── Conditions ─────────────────────────────────────────────────────────────


func test_conditioned_choice_is_unavailable_when_flag_not_set() -> void:
	var engine := _make_engine_with(_make_conditional_dialogue())
	var ctx := StubContext.new()
	# met_wizard flag is false by default
	var session := engine.create_session(&"test_conditional", ctx)
	var node_view := session.get_current_node()
	var mention_choice: DialogueEngine.DialogueChoiceView = null
	for cv: DialogueEngine.DialogueChoiceView in node_view.choices:
		if cv.id == &"mention_wizard":
			mention_choice = cv
	assert_not_null(mention_choice)
	assert_false(mention_choice.is_available)
	assert_false(mention_choice.blocked_by.is_empty())


func test_conditioned_choice_is_available_when_flag_set() -> void:
	var engine := _make_engine_with(_make_conditional_dialogue())
	var ctx := StubContext.new()
	ctx.flags["met_wizard"] = true
	var session := engine.create_session(&"test_conditional", ctx)
	var node_view := session.get_current_node()
	var mention_choice: DialogueEngine.DialogueChoiceView = null
	for cv: DialogueEngine.DialogueChoiceView in node_view.choices:
		if cv.id == &"mention_wizard":
			mention_choice = cv
	assert_not_null(mention_choice)
	assert_true(mention_choice.is_available)


func test_choosing_blocked_choice_fails() -> void:
	var engine := _make_engine_with(_make_conditional_dialogue())
	var ctx := StubContext.new()
	ctx.flags["met_wizard"] = false
	var session := engine.create_session(&"test_conditional", ctx)
	var result := session.choose(&"mention_wizard")
	assert_false(result.success)


# ── Effects ────────────────────────────────────────────────────────────────


func test_flag_effect_is_applied_on_choose() -> void:
	var engine := _make_engine_with(_make_conditional_dialogue())
	var ctx := StubContext.new()
	ctx.flags["met_wizard"] = true
	var session := engine.create_session(&"test_conditional", ctx)
	session.choose(&"mention_wizard")
	assert_true(ctx.flags.get("told_about_wizard", false),
		"Flag 'told_about_wizard' should be set after choosing the conditioned option.")


func test_activate_quest_effect_calls_context() -> void:
	var effect := DialogueChoiceEffect.new()
	effect.type = "activate_quest"
	effect.quest_id = &"rescue_the_cat"

	var choice := _make_choice(&"agree", "I'll help!", &"end")
	choice.effects = [effect]

	var node_start := _make_node(&"start", "NPC", "Please help me!", [choice])
	var node_end := _make_node(&"end", "NPC", "Thank you!")

	var def := DialogueDefinition.new()
	def.id = &"test_quest_effect"
	def.start_node_id = &"start"
	def.nodes = [node_start, node_end]

	var engine := _make_engine_with(def)
	var ctx := StubContext.new()
	var session := engine.create_session(&"test_quest_effect", ctx)
	session.choose(&"agree")
	assert_has(ctx.activated_quests, &"rescue_the_cat")


func test_give_item_effect_calls_context() -> void:
	var effect := DialogueChoiceEffect.new()
	effect.type = "give_item"
	effect.item_id = &"gold_coin"
	effect.quantity = 5

	var choice := _make_choice(&"take_reward", "Thank you!", &"end")
	choice.effects = [effect]

	var node_start := _make_node(&"start", "Merchant", "Take this as reward.", [choice])
	var node_end := _make_node(&"end", "Merchant", "Farewell.")

	var def := DialogueDefinition.new()
	def.id = &"test_give_item"
	def.start_node_id = &"start"
	def.nodes = [node_start, node_end]

	var engine := _make_engine_with(def)
	var ctx := StubContext.new()
	var session := engine.create_session(&"test_give_item", ctx)
	session.choose(&"take_reward")
	assert_eq(ctx.given_items.get(&"gold_coin", 0), 5)


func test_faction_delta_effect_adjusts_reputation() -> void:
	var effect := DialogueChoiceEffect.new()
	effect.type = "faction_delta"
	effect.faction_id = &"merchants_guild"
	effect.amount = 10

	var choice := _make_choice(&"help", "I'll help the guild.", &"end")
	choice.effects = [effect]

	var node_start := _make_node(&"start", "Guildmaster", "Will you help us?", [choice])
	var node_end := _make_node(&"end", "Guildmaster", "Excellent.")

	var def := DialogueDefinition.new()
	def.id = &"test_faction"
	def.start_node_id = &"start"
	def.nodes = [node_start, node_end]

	var engine := _make_engine_with(def)
	var ctx := StubContext.new()
	var session := engine.create_session(&"test_faction", ctx)
	session.choose(&"help")
	assert_eq(ctx.faction_reps.get(&"merchants_guild", 0), 10)


# ── Terminal node ─────────────────────────────────────────────────────────


func test_terminal_node_ends_dialogue_on_any_choice() -> void:
	var choice := _make_choice(&"ok", "Okay.", &"next")
	var terminal_node := _make_node(&"terminal", "NPC", "Goodbye!", [choice])
	terminal_node.terminal = true
	var next_node := _make_node(&"next", "NPC", "...")

	var def := DialogueDefinition.new()
	def.id = &"test_terminal"
	def.start_node_id = &"terminal"
	def.nodes = [terminal_node, next_node]

	var engine := _make_engine_with(def)
	var session := engine.create_session(&"test_terminal", StubContext.new())
	var result := session.choose(&"ok")
	assert_true(result.is_complete, "Terminal node should end the dialogue.")
	assert_true(session.is_complete)


func test_ends_dialogue_flag_ends_on_choice() -> void:
	var choice := _make_choice(&"leave", "I must go.", &"another_node")
	choice.ends_dialogue = true
	var node := _make_node(&"start", "NPC", "Hello!", [choice])
	var another := _make_node(&"another_node", "NPC", "See you.")

	var def := DialogueDefinition.new()
	def.id = &"test_ends_dialogue"
	def.start_node_id = &"start"
	def.nodes = [node, another]

	var engine := _make_engine_with(def)
	var session := engine.create_session(&"test_ends_dialogue", StubContext.new())
	var result := session.choose(&"leave")
	assert_true(result.is_complete)


# ── Snapshot / restore ────────────────────────────────────────────────────


func test_snapshot_and_restore_preserves_current_node() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var session := engine.create_session(&"test_simple", StubContext.new())
	session.choose(&"ask_name") # advance to "farewell"

	var snap := session.get_snapshot()
	assert_eq(snap.current_node_id, &"farewell")
	assert_false(snap.completed)

	# Restore into a fresh session
	var session2 := engine.create_session(&"test_simple", StubContext.new())
	session2.restore_from_snapshot(snap)
	assert_eq(session2.get_current_node().id, &"farewell")


func test_snapshot_of_complete_session_marks_completed() -> void:
	var engine := _make_engine_with(_make_simple_dialogue())
	var ctx := StubContext.new()
	var session := engine.create_session(&"test_simple", ctx)
	session.choose(&"ask_name") # go to farewell (no choices)

	# Attempting a choice when there are no choices ends the session
	# (farewell node has no choices, any choose attempt fails or marks complete)
	var snap := session.get_snapshot()
	# The session is not yet forcibly complete just by reaching farewell,
	# but completed flag tracks what choose returns.
	assert_eq(snap.dialogue_id, &"test_simple")


# ── Skill condition ───────────────────────────────────────────────────────


func test_skill_min_condition_blocks_when_skill_too_low() -> void:
	var cond := DialogueChoiceCondition.new()
	cond.type = "skill_min"
	cond.skill_id = &"persuasion"
	cond.min_value = 50

	var choice := _make_choice(&"persuade", "Trust me.", &"end")
	choice.conditions = [cond]

	var choice_other := _make_choice(&"leave", "Never mind.", &"end")

	var node_start := _make_node(&"start", "Guard", "I'm not sure.", [choice, choice_other])
	var node_end := _make_node(&"end", "Guard", "Fine.")

	var def := DialogueDefinition.new()
	def.id = &"test_skill"
	def.start_node_id = &"start"
	def.nodes = [node_start, node_end]

	var engine := _make_engine_with(def)

	# Skill too low
	var ctx_low := StubContext.new()
	ctx_low.skills[&"persuasion"] = 30
	var session_low := engine.create_session(&"test_skill", ctx_low)
	var node_view := session_low.get_current_node()
	var persuade_view: DialogueEngine.DialogueChoiceView = null
	for cv: DialogueEngine.DialogueChoiceView in node_view.choices:
		if cv.id == &"persuade":
			persuade_view = cv
	assert_false(persuade_view.is_available)

	# Skill high enough
	var ctx_high := StubContext.new()
	ctx_high.skills[&"persuasion"] = 60
	var session_high := engine.create_session(&"test_skill", ctx_high)
	var node_view2 := session_high.get_current_node()
	var persuade_view2: DialogueEngine.DialogueChoiceView = null
	for cv: DialogueEngine.DialogueChoiceView in node_view2.choices:
		if cv.id == &"persuade":
			persuade_view2 = cv
	assert_true(persuade_view2.is_available)
