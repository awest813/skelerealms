extends Node
## Autoload singleton that manages dialogue definitions and active sessions.
## Uses [DialogueEngine] for the core logic and integrates with the save system.


## Emitted when a dialogue session starts.
signal dialogue_started(dialogue_id: StringName, speaker: String)
## Emitted when a dialogue session ends.
signal dialogue_ended(dialogue_id: StringName)
## Emitted when a dialogue choice is made.
signal choice_made(dialogue_id: StringName, choice_id: StringName)


## The underlying dialogue engine.
var engine := DialogueEngine.new()
## The currently active session, if any.
var active_session: DialogueSession


func _ready() -> void:
	add_to_group("savegame_gameinfo")


## Register a [DialogueDefinition] resource with the engine.
func register_dialogue(definition: DialogueDefinition) -> void:
	engine.register_dialogue(definition)


## Returns true if a dialogue definition is registered.
func has_dialogue(dialogue_id: StringName) -> bool:
	return engine.has_dialogue(dialogue_id)


## Start a dialogue session. Returns the initial [DialogueEngine.DialogueNodeView], or null on failure.
## Pass a custom [DialogueContext] subclass to override game-state queries.
func start_dialogue(dialogue_id: StringName, context: DialogueContext = null) -> DialogueEngine.DialogueNodeView:
	if not context:
		context = DialogueContext.new()
	var session := engine.create_session(dialogue_id, context)
	if not session:
		return null
	active_session = session
	var node := session.get_current_node()
	if node:
		dialogue_started.emit(dialogue_id, node.speaker)
	return node


## Make a choice in the active session. Returns a [DialogueEngine.DialogueAdvanceResult].
func choose(choice_id: StringName) -> DialogueEngine.DialogueAdvanceResult:
	if not active_session:
		var result := DialogueEngine.DialogueAdvanceResult.new()
		result.success = false
		result.message = "No active dialogue session."
		result.is_complete = true
		result.current_node = null
		return result

	var result := active_session.choose(choice_id)
	if result.success:
		choice_made.emit(active_session.get_dialogue_id(), choice_id)
	if result.is_complete:
		dialogue_ended.emit(active_session.get_dialogue_id())
		active_session = null
	return result


## Get the current node view of the active session (or null).
func get_current_node() -> DialogueEngine.DialogueNodeView:
	if not active_session:
		return null
	return active_session.get_current_node()


## End the active session early.
## [annotation @rpc] — any peer can end a dialogue session.
@rpc("any_peer", "call_local", "reliable")
func end_dialogue() -> void:
	if active_session:
		dialogue_ended.emit(active_session.get_dialogue_id())
		active_session = null


## Whether a dialogue session is currently active.
func is_in_dialogue() -> bool:
	return active_session != null


# ── Save integration ────────────────────────────────────────────────────────


func save() -> Dictionary:
	var data := {}
	if active_session:
		data["active_session"] = active_session.get_snapshot().serialize()
	return data


func load_data(data: Dictionary) -> void:
	if data.has("active_session"):
		# We can restore the session snapshot but the session itself needs the
		# definition to be registered. Store the snapshot so consumers can
		# resume if needed.
		var snapshot := DialogueEngine.DialogueSessionSnapshot.deserialize(data["active_session"])
		if engine.has_dialogue(snapshot.dialogue_id) and not snapshot.completed:
			var context := DialogueContext.new()
			active_session = engine.create_session(snapshot.dialogue_id, context)
			active_session.restore_from_snapshot(snapshot)


func reset_data() -> void:
	active_session = null
