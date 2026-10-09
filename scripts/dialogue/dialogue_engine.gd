class_name DialogueEngine
extends RefCounted
## Manages dialogue definitions and creates dialogue sessions. Ported from Camelot's DialogueEngine.
## This is a pure-logic class with no Godot scene-tree dependencies.
## Use [DialogueSystem] (the autoload) for game integration.


## View of a dialogue choice, with availability info.
class DialogueChoiceView extends RefCounted:
	var id: StringName
	var text: String
	var is_available: bool
	var blocked_by: String # empty if available
	## Persuasion attempt advertised by this choice (&"" when none).
	var attempt_skill: StringName
	var attempt_difficulty: int = 0


## View of a dialogue node, with resolved choice availability.


## View of a dialogue node, with resolved choice availability.
class DialogueNodeView extends RefCounted:
	var id: StringName
	var speaker: String
	var text: String
	var terminal: bool
	var voice_id: StringName
	var display_seconds: float = 0.0
	var choices: Array[DialogueChoiceView] = []


## Result of advancing a dialogue session.
class DialogueAdvanceResult extends RefCounted:
	var success: bool
	var message: String
	var is_complete: bool
	var current_node: DialogueNodeView # null if dialogue ended
	## Whether the choice ran a persuasion attempt.
	var attempted: bool = false
	## Attempt outcome (meaningful only when attempted).
	var attempt_succeeded: bool = false


## Snapshot of a session for save/restore.
class DialogueSessionSnapshot extends RefCounted:
	var dialogue_id: StringName
	var current_node_id: StringName
	var completed: bool

	func serialize() -> Dictionary:
		return {
			"dialogue_id": dialogue_id,
			"current_node_id": current_node_id,
			"completed": completed,
		}

	static func deserialize(data: Dictionary) -> DialogueSessionSnapshot:
		var s := DialogueSessionSnapshot.new()
		s.dialogue_id = StringName(data.get("dialogue_id", ""))
		s.current_node_id = StringName(data.get("current_node_id", ""))
		s.completed = data.get("completed", false)
		return s


# ── Internal state ──────────────────────────────────────────────────────────

## dialogue_id -> DialogueDefinition
var _definitions: Dictionary[StringName, DialogueDefinition] = {}
## dialogue_id -> { node_id -> DialogueNode }
var _node_maps: Dictionary[StringName, Dictionary] = {}


# ── Public API ──────────────────────────────────────────────────────────────


## Register a dialogue definition. Validates the definition.
func register_dialogue(definition: DialogueDefinition) -> void:
	var node_map := _validate_definition(definition)
	_definitions[definition.id] = definition
	_node_maps[definition.id] = node_map


## Returns true if a dialogue definition is registered.
func has_dialogue(dialogue_id: StringName) -> bool:
	return _definitions.has(dialogue_id)


## Node ids of a registered dialogue, or [] when unknown.
## Used by scene validation without exposing the node map itself.
func get_node_ids(dialogue_id: StringName) -> Array:
	var node_map: Dictionary = _node_maps.get(dialogue_id, {})
	var ids: Array = []
	for node_id in node_map:
		ids.append(node_id)
	return ids


## Create a new dialogue session. The context provides game-state queries.
func create_session(dialogue_id: StringName, context: DialogueContext) -> DialogueSession:
	var definition: DialogueDefinition = _definitions.get(dialogue_id)
	var node_map: Dictionary = _node_maps.get(dialogue_id, {})
	if not definition or node_map.is_empty():
		push_error("DialogueEngine: Unknown dialogue id '%s'." % dialogue_id)
		return null
	return DialogueSession.new(definition, context, node_map)


# ── Validation ──────────────────────────────────────────────────────────────


## Validate a definition without registering it.
## Returns an Array of Dictionaries with keys [code]type[/code],
## [code]node_id[/code] ([StringName]) and [code]detail[/code] (String).
## An empty Array means the definition is valid. Used by the editor's
## Validate button; registration-time checks still report via push_error.
func validate_definition(definition: DialogueDefinition) -> Array:
	var issues: Array = []
	var seen := {}
	for node: DialogueNode in definition.nodes:
		if seen.has(node.id):
			issues.append({
				"type": "duplicate_node",
				"node_id": node.id,
				"detail": "Duplicate node id '%s'." % node.id,
			})
		seen[node.id] = true
	if not seen.has(definition.start_node_id):
		issues.append({
			"type": "missing_start",
			"node_id": definition.start_node_id,
			"detail": "Start node '%s' does not exist." % definition.start_node_id,
		})
	for node: DialogueNode in definition.nodes:
		var choice_ids := {}
		for choice: DialogueChoice in node.choices:
			if choice_ids.has(choice.id):
				issues.append({
					"type": "duplicate_choice",
					"node_id": node.id,
					"detail": "Duplicate choice id '%s'." % choice.id,
				})
			choice_ids[choice.id] = true
			if not choice.next_node_id.is_empty() and not seen.has(choice.next_node_id):
				issues.append({
					"type": "dangling_choice",
					"node_id": node.id,
					"detail": "Choice '%s' points to unknown node '%s'." % [choice.id, choice.next_node_id],
				})
			if not choice.fail_next_node_id.is_empty() and not seen.has(choice.fail_next_node_id):
				issues.append({
					"type": "dangling_fail_branch",
					"node_id": node.id,
					"detail": "Choice '%s' fails to unknown node '%s'." % [choice.id, choice.fail_next_node_id],
				})
			if not choice.attempt_skill.is_empty() and choice.fail_next_node_id.is_empty() and not node.terminal:
				issues.append({
					"type": "check_without_fail",
					"node_id": node.id,
					"detail": "Choice '%s' rolls persuasion with nowhere to go on failure." % choice.id,
				})
		if not node.terminal and node.choices.is_empty():
			issues.append({
				"type": "dead_end",
				"node_id": node.id,
				"detail": "Non-terminal node has no choices.",
			})
	return issues


func _validate_definition(definition: DialogueDefinition) -> Dictionary:
	var node_map := {}
	for node: DialogueNode in definition.nodes:
		if node_map.has(node.id):
			push_error("DialogueEngine: Duplicate node id '%s' in dialogue '%s'." % [node.id, definition.id])
		node_map[node.id] = node

	if not node_map.has(definition.start_node_id):
		push_error("DialogueEngine: Start node '%s' does not exist in dialogue '%s'." % [definition.start_node_id, definition.id])

	for node: DialogueNode in definition.nodes:
		var choice_ids := {}
		for choice: DialogueChoice in node.choices:
			if choice_ids.has(choice.id):
				push_error("DialogueEngine: Duplicate choice id '%s' in node '%s' of dialogue '%s'." % [choice.id, node.id, definition.id])
			choice_ids[choice.id] = true
			if not choice.next_node_id.is_empty() and not node_map.has(choice.next_node_id):
				push_error("DialogueEngine: Choice '%s' in node '%s' points to unknown node '%s' in dialogue '%s'." % [choice.id, node.id, choice.next_node_id, definition.id])

	return node_map
