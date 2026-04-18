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


## View of a dialogue node, with resolved choice availability.
class DialogueNodeView extends RefCounted:
	var id: StringName
	var speaker: String
	var text: String
	var terminal: bool
	var choices: Array[DialogueChoiceView] = []


## Result of advancing a dialogue session.
class DialogueAdvanceResult extends RefCounted:
	var success: bool
	var message: String
	var is_complete: bool
	var current_node: DialogueNodeView # null if dialogue ended


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


## Create a new dialogue session. The context provides game-state queries.
func create_session(dialogue_id: StringName, context: DialogueContext) -> DialogueSession:
	var definition: DialogueDefinition = _definitions.get(dialogue_id)
	var node_map: Dictionary = _node_maps.get(dialogue_id)
	if not definition or node_map == null:
		push_error("DialogueEngine: Unknown dialogue id '%s'." % dialogue_id)
		return null
	return DialogueSession.new(definition, context, node_map)


# ── Validation ──────────────────────────────────────────────────────────────


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
