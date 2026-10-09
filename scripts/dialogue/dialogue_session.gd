class_name DialogueSession
extends RefCounted
## An active dialogue session. Created by [method DialogueEngine.create_session].
## Advances through a dialogue tree, evaluating conditions and applying effects.


var _definition: DialogueDefinition
var _context: DialogueContext
var _node_map: Dictionary # StringName -> DialogueNode
var _current_node_id: StringName
var _completed: bool = false
## Roll source for persuasion attempts. Override with a seeded instance
## for deterministic tests or replays.
var rng := RandomNumberGenerator.new()


## Whether this dialogue session has ended.
var is_complete: bool:
	get:
		return _completed


## Get the ID of the dialogue this session is running.
func get_dialogue_id() -> StringName:
	return _definition.id


func _init(definition: DialogueDefinition, context: DialogueContext, node_map: Dictionary) -> void:
	_definition = definition
	_context = context
	_node_map = node_map
	_current_node_id = definition.start_node_id


## Get the current node as a view with resolved choice availability.
func get_current_node() -> DialogueEngine.DialogueNodeView:
	if _current_node_id.is_empty():
		return null
	var node: DialogueNode = _node_map.get(_current_node_id)
	if not node:
		return null
	return _to_node_view(node)


## Select a choice by its ID. Returns a [DialogueEngine.DialogueAdvanceResult].
func choose(choice_id: StringName) -> DialogueEngine.DialogueAdvanceResult:
	var result := DialogueEngine.DialogueAdvanceResult.new()

	if _completed:
		result.success = false
		result.message = "Dialogue is already complete."
		result.is_complete = true
		result.current_node = null
		return result

	var node: DialogueNode = _node_map.get(_current_node_id) if not _current_node_id.is_empty() else null
	if not node:
		_completed = true
		_current_node_id = &""
		result.success = false
		result.message = "Dialogue node is missing."
		result.is_complete = true
		result.current_node = null
		return result

	# Find the choice
	var choice: DialogueChoice = null
	for c: DialogueChoice in node.choices:
		if c.id == choice_id:
			choice = c
			break

	if not choice:
		result.success = false
		result.message = "Choice '%s' not found." % choice_id
		result.is_complete = _completed
		result.current_node = _to_node_view(node)
		return result

	# Check conditions
	var blocked_by := _get_blocked_by_reason(choice)
	if not blocked_by.is_empty():
		result.success = false
		result.message = blocked_by
		result.is_complete = _completed
		result.current_node = _to_node_view(node)
		return result

	# Persuasion attempt: roll before anything applies.
	# Typed to match _apply_effect_list (untyped Arrays are rejected).
	var use_effects: Array[DialogueChoiceEffect] = choice.effects
	var target_id: StringName = choice.next_node_id
	var ends: bool = choice.ends_dialogue
	result.attempted = not choice.attempt_skill.is_empty()
	result.attempt_succeeded = true
	if result.attempted:
		result.attempt_succeeded = _roll_attempt(choice, node)
		if not result.attempt_succeeded:
			use_effects = choice.fail_effects
			target_id = choice.fail_next_node_id
			if target_id.is_empty():
				# Fizzle: stay on the current node, nothing applied.
				result.success = false
				result.message = "Persuasion failed."
				result.is_complete = _completed
				result.current_node = _to_node_view(node)
				return result

	# Apply effects
	_apply_effect_list(use_effects)

	# Determine whether dialogue ends
	var should_end: bool = ends or node.terminal or target_id.is_empty()
	if should_end:
		_completed = true
		_current_node_id = &""
		result.success = true
		result.message = "Dialogue complete."
		result.is_complete = true
		result.current_node = null
		return result

	# Advance to next node
	_current_node_id = target_id
	var next_node := get_current_node()
	if not next_node:
		_completed = true
		_current_node_id = &""
		result.success = false
		result.message = "Dialogue could not continue to next node."
		result.is_complete = true
		result.current_node = null
		return result

	result.success = true
	result.message = "Choice applied."
	result.is_complete = false
	result.current_node = next_node
	return result


## d100 roll under chance: 50 + skill − difficulty + disposition/5,
## clamped to 5..95 so attempts never auto-pass or auto-fail.
func _roll_attempt(choice: DialogueChoice, node: DialogueNode) -> bool:
	var skill := _context.get_skill_level(choice.attempt_skill)
	var disposition := _context.get_disposition(node.speaker)
	var chance := clampf(50.0 + float(skill) - float(choice.attempt_difficulty) + float(disposition) / 5.0, 5.0, 95.0)
	return rng.randf_range(0.0, 100.0) < chance


## Get a snapshot for saving session state.
func get_snapshot() -> DialogueEngine.DialogueSessionSnapshot:
	var snapshot := DialogueEngine.DialogueSessionSnapshot.new()
	snapshot.dialogue_id = _definition.id
	snapshot.current_node_id = _current_node_id
	snapshot.completed = _completed
	return snapshot


## Restore session state from a snapshot.
func restore_from_snapshot(snapshot: DialogueEngine.DialogueSessionSnapshot) -> void:
	_current_node_id = snapshot.current_node_id
	_completed = snapshot.completed


# ── Private helpers ─────────────────────────────────────────────────────────


func _to_node_view(node: DialogueNode) -> DialogueEngine.DialogueNodeView:
	var view := DialogueEngine.DialogueNodeView.new()
	view.id = node.id
	view.speaker = node.speaker
	view.text = node.text
	view.terminal = node.terminal
	view.voice_id = node.voice_id
	view.display_seconds = node.display_seconds

	for choice: DialogueChoice in node.choices:
		var cv := DialogueEngine.DialogueChoiceView.new()
		cv.id = choice.id
		cv.text = choice.text
		var blocked := _get_blocked_by_reason(choice)
		cv.is_available = blocked.is_empty()
		cv.blocked_by = blocked
		cv.attempt_skill = choice.attempt_skill
		cv.attempt_difficulty = choice.attempt_difficulty
		view.choices.append(cv)

	return view


func _get_blocked_by_reason(choice: DialogueChoice) -> String:
	if choice.conditions.is_empty():
		return ""
	var failed := DialogueConditions.first_failure(choice.conditions, _context)
	if failed == null:
		return ""
	return "Choice blocked by %s." % failed.type


func _evaluate_condition(condition: DialogueChoiceCondition) -> bool:
	return DialogueConditions.passes(condition, _context)


func _apply_effects(choice: DialogueChoice) -> void:
	_apply_effect_list(choice.effects)


func _apply_effect_list(effects: Array[DialogueChoiceEffect]) -> void:
	for effect: DialogueChoiceEffect in effects:
		match effect.type:
			"set_flag":
				_context.set_flag(effect.flag, effect.flag_value)
			"faction_delta":
				_context.adjust_faction_reputation(effect.faction_id, effect.amount)
			"emit_event":
				_context.emit_event(effect.event_id)
			"activate_quest":
				_context.activate_quest(effect.quest_id)
			"consume_item":
				_context.consume_item(effect.item_id, effect.quantity)
			"give_item":
				_context.give_item(effect.item_id, effect.quantity)
			"recruit_companion":
				if not CompanionSystem.recruit(effect.companion_id):
					push_warning("DialogueSession: recruit_companion failed for '%s'." % effect.companion_id)
			"dismiss_companion":
				if not CompanionSystem.dismiss(effect.companion_id):
					push_warning("DialogueSession: dismiss_companion failed for '%s'." % effect.companion_id)
			_:
				push_warning("DialogueSession: Unknown effect type '%s'." % effect.type)
