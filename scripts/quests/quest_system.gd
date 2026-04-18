extends Node
## Autoload singleton that manages quest state across the game.
## Uses [QuestGraphEngine] for the core logic and integrates with the save system.


## Emitted when a quest is activated.
signal quest_activated(quest_id: StringName)
## Emitted when a quest is completed.
signal quest_completed(quest_id: StringName, xp_reward: int)
## Emitted when one or more quest nodes change state.
signal quest_updated(quest_id: StringName, activated_nodes: Array[StringName], completed_nodes: Array[StringName])


## The underlying quest engine.
var engine := QuestGraphEngine.new()


func _ready() -> void:
	add_to_group("savegame_gameinfo")


## Register a [QuestDefinition] resource with the engine.
func register_quest(definition: QuestDefinition) -> void:
	engine.register_quest(definition)


## Activate a quest by ID. Returns true on success.
## [annotation @rpc] — authority-only: only the server should activate quests.
@rpc("authority", "reliable")
func activate_quest(quest_id: StringName) -> bool:
	return activate_quest_with_params(quest_id, {})


## Activate a quest with template parameter overrides.
## [param params] is merged on top of the quest's default parameters.
## See [method QuestGraphEngine.activate_quest_with_params].
## [annotation @rpc] — authority-only: only the server should activate quests.
@rpc("authority", "reliable")
func activate_quest_with_params(quest_id: StringName, params: Dictionary = {}) -> bool:
	var result := engine.activate_quest_with_params(quest_id, params)
	if result:
		quest_activated.emit(quest_id)
	return result


## Get the status of a quest: "inactive", "active", or "completed".
func get_quest_status(quest_id: StringName) -> String:
	return engine.get_quest_status(quest_id)


## Get a copy of the full runtime state of a quest (or null if not registered).
func get_quest_state(quest_id: StringName) -> QuestGraphEngine.QuestRuntimeState:
	return engine.get_quest_state(quest_id)


## Fire a game event and let the engine advance any matching quest nodes.
## [annotation @rpc] — authority-only: the server drives quest progress.
@rpc("authority", "reliable")
func apply_event(event: QuestEvent) -> void:
	var results := engine.apply_event(event)
	for result: QuestGraphEngine.QuestEventResult in results:
		quest_updated.emit(result.quest_id, result.activated_node_ids, result.completed_node_ids)
		if result.quest_completed:
			quest_completed.emit(result.quest_id, result.xp_reward)


## Convenience: fire a kill event.
## [annotation @rpc] — any peer can report a kill; server processes it.
@rpc("any_peer", "call_local", "reliable")
func report_kill(target_id: StringName, amount: int = 1) -> void:
	apply_event(QuestEvent.new("kill", target_id, amount))


## Convenience: fire a pickup event.
## [annotation @rpc] — any peer can report a pickup; server processes it.
@rpc("any_peer", "call_local", "reliable")
func report_pickup(target_id: StringName, amount: int = 1) -> void:
	apply_event(QuestEvent.new("pickup", target_id, amount))


## Convenience: fire a talk event.
## [annotation @rpc] — any peer can report a talk; server processes it.
@rpc("any_peer", "call_local", "reliable")
func report_talk(target_id: StringName) -> void:
	apply_event(QuestEvent.new("talk", target_id, 1))


## Convenience: fire a custom event.
## [annotation @rpc] — any peer can report a custom event; server processes it.
@rpc("any_peer", "call_local", "reliable")
func report_custom(target_id: StringName, amount: int = 1) -> void:
	apply_event(QuestEvent.new("custom", target_id, amount))


## Validate a quest graph. Returns a [QuestGraphEngine.QuestValidationReport].
func validate_quest(quest_id: StringName) -> QuestGraphEngine.QuestValidationReport:
	return engine.validate_graph(quest_id)


## Get all registered quest IDs.
func get_registered_quest_ids() -> Array[StringName]:
	return engine.get_registered_quest_ids()


# ── Save integration ────────────────────────────────────────────────────────


func save() -> Dictionary:
	return engine.get_snapshot()


func load_data(data: Dictionary) -> void:
	engine.restore_snapshot(data)


func reset_data() -> void:
	engine.reset_all_state()
