class_name DialogueSession
extends RefCounted
## An active dialogue session. Created by [method DialogueEngine.create_session].
## Advances through a dialogue tree, evaluating conditions and applying effects.


var _definition: DialogueDefinition
var _context: DialogueContext
var _node_map: Dictionary # StringName -> DialogueNode
var _current_node_id: StringName
var _completed: bool = false


## Whether this dialogue session has ended.
var is_complete: bool:
	get:
		return _completed


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

	# Apply effects
	_apply_effects(choice)

	# Determine whether dialogue ends
	var should_end: bool = choice.ends_dialogue or node.terminal or choice.next_node_id.is_empty()
	if should_end:
		_completed = true
		_current_node_id = &""
		result.success = true
		result.message = "Dialogue complete."
		result.is_complete = true
		result.current_node = null
		return result

	# Advance to next node
	_current_node_id = choice.next_node_id
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


## Get a snapshot for saving session state.
func get_snapshot() -> DialogueEngine.DialogueSessionSnapshot:
	var snapshot := DialogueEngine.DialogueSessionSnapshot.new()
	snapshot.dialogue_id = _definition.id
	snapshot.current_node_id = _current_node_id
	snapshot.completed = _completed
	return snapshot


# ── Private helpers ─────────────────────────────────────────────────────────


func _to_node_view(node: DialogueNode) -> DialogueEngine.DialogueNodeView:
	var view := DialogueEngine.DialogueNodeView.new()
	view.id = node.id
	view.speaker = node.speaker
	view.text = node.text
	view.terminal = node.terminal

	for choice: DialogueChoice in node.choices:
		var cv := DialogueEngine.DialogueChoiceView.new()
		cv.id = choice.id
		cv.text = choice.text
		var blocked := _get_blocked_by_reason(choice)
		cv.is_available = blocked.is_empty()
		cv.blocked_by = blocked
		view.choices.append(cv)

	return view


func _get_blocked_by_reason(choice: DialogueChoice) -> String:
	if choice.conditions.is_empty():
		return ""
	for condition: DialogueChoiceCondition in choice.conditions:
		if not _evaluate_condition(condition):
			return "Choice blocked by %s." % condition.type
	return ""


func _evaluate_condition(condition: DialogueChoiceCondition) -> bool:
	match condition.type:
		"flag":
			return _context.get_flag(condition.flag) == condition.flag_equals
		"faction_min":
			return _context.get_faction_reputation(condition.faction_id) >= condition.min_value
		"quest_status":
			return _context.get_quest_status(condition.quest_id) == condition.quest_status
		"has_item":
			return _context.get_inventory_count(condition.item_id) >= condition.min_quantity
		"skill_min":
			return _context.get_skill_level(condition.skill_id) >= condition.min_value
		_:
			return false


func _apply_effects(choice: DialogueChoice) -> void:
	for effect: DialogueChoiceEffect in choice.effects:
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
