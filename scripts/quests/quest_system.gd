extends Node
## Autoload singleton that manages quest state across the game.
## Uses [QuestGraphEngine] for the core logic and integrates with the save system.


## Emitted when a quest is activated.
signal quest_activated(quest_id: StringName)
## Emitted when a quest is completed.
signal quest_completed(quest_id: StringName, xp_reward: int)
## Emitted when a quest fails (terminal, no XP).
signal quest_failed(quest_id: StringName)
## Emitted when one or more quest nodes change state.
signal quest_updated(quest_id: StringName, activated_nodes: Array[StringName], completed_nodes: Array[StringName])


## The underlying quest engine.
var engine := QuestGraphEngine.new()


func _ready() -> void:
	add_to_group("savegame_gameinfo")
	engine.entity_finder = _default_entity_finder


## Register a [QuestDefinition] resource with the engine.
func register_quest(definition: QuestDefinition) -> void:
	engine.register_quest(definition)


## Remove a quest entirely (failed radiant rollback, mod removal).
func unregister_quest(quest_id: StringName) -> void:
	engine.unregister_quest(quest_id)


## Activate a quest by ID. Returns true on success.
## [annotation @rpc] — authority-only: only the server should activate quests.
@rpc("authority", "reliable")
func activate_quest(quest_id: StringName) -> bool:
	return activate_quest_with_params(quest_id, {})


## Activate a quest with template parameter overrides.
## [param params] is merged on top of the quest's default parameters.
## Alias slots fill from the player's world and position automatically.
## See [method QuestGraphEngine.activate_quest_with_params].
## [annotation @rpc] — authority-only: only the server should activate quests.
@rpc("authority", "reliable")
func activate_quest_with_params(quest_id: StringName, params: Dictionary = {}) -> bool:
	var result := engine.activate_quest_with_params(quest_id, params, _player_context())
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
		elif result.quest_failed:
			quest_failed.emit(result.quest_id)
	# The Story Manager sees every quest event. Disable via
	# RadiantSystem.auto_forward for fully manual dispatch.
	if RadiantSystem.auto_forward:
		RadiantSystem.notify_event(event)


## Move an active quest to a journal stage. Returns "advanced",
## "completed", "failed", or "" when nothing happened (unknown quest,
## inactive quest, or unknown stage). Emits journal refresh signals.
## [annotation @rpc] — authority-only: only the server should set stages.
@rpc("authority", "reliable")
func set_stage(quest_id: StringName, index: int) -> String:
	var outcome := engine.set_stage(quest_id, index)
	if outcome == "":
		return outcome
	quest_updated.emit(quest_id, [], [])
	if outcome == "completed":
		quest_completed.emit(quest_id, engine.get_quest_xp(quest_id))
	elif outcome == "failed":
		quest_failed.emit(quest_id)
	return outcome


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


## Journal view for UI: name, status, current stage, objectives with
## done-flags, and the full log. See [QuestGraphEngine.get_journal].
func get_journal(quest_id: StringName) -> Dictionary:
	return engine.get_journal(quest_id)


## One-line current objective for HUD use ("" when nothing is current).
func get_current_objective(quest_id: StringName) -> String:
	return engine.get_current_objective(quest_id)


## Get all registered quest IDs.
func get_registered_quest_ids() -> Array[StringName]:
	return engine.get_registered_quest_ids()


## Get the live entity ref filling an alias, or &"" when unknown/unfilled.
## Useful for journal text ("Find: Grok") and map markers.
func resolve_alias(quest_id: StringName, alias_id: StringName) -> StringName:
	return engine.get_alias_ref(quest_id, alias_id)


## Get a copy of all filled alias refs for a quest (alias_id -> entity ref).
func get_alias_refs(quest_id: StringName) -> Dictionary:
	return engine.get_alias_refs(quest_id)


## Default alias entity finder, backed by SKEntityManager.
## Applies the engine-supplied filter (must_be_npc, required_coven,
## required_form, exclude_ids, world) and returns candidate dicts with
## ref, position, world, and form keys. Entities are considered in
## registry order, so first-match picks are deterministic.
func _default_entity_finder(filter: Dictionary) -> Array:
	var out: Array = []
	var manager := SKEntityManager.instance
	if manager == null:
		return out
	var world: StringName = filter.get("world", &"")
	for ref in manager.entities:
		var e: SKEntity = manager.entities[ref]
		if e == null or not is_instance_valid(e):
			continue
		if world != &"" and e.world != world:
			continue
		if bool(filter.get("must_be_npc", false)) and not e.has_component("NPCComponent"):
			continue
		var form: StringName = filter.get("required_form", &"")
		if form != &"" and e.form_id != form:
			continue
		var coven: StringName = filter.get("required_coven", &"")
		if coven != &"":
			var cc := e.get_component("CovensComponent")
			if cc == null or not (cc as CovensComponent).covens.has(coven):
				continue
		var excluded: Array = filter.get("exclude_ids", [])
		if excluded.has(ref):
			continue
		out.append({
			"ref": ref,
			"position": e.position,
			"world": e.world,
			"form": e.form_id,
		})
	return out


## Build alias-fill context for the player: current world and position.
## Falls back to origin-less defaults headless (no camera / puppet yet).
func _player_context() -> Dictionary:
	var ctx := {"world": GameInfo.world, "player_position": Vector3.ZERO}
	var origin: Node3D = GameInfo.world_origin
	if origin != null and is_instance_valid(origin):
		ctx["player_position"] = (origin as Node3D).global_position
	return ctx


# ── Save integration ────────────────────────────────────────────────────────


func save() -> Dictionary:
	return engine.get_snapshot()


func load_data(data: Dictionary) -> void:
	engine.restore_snapshot(data)


func reset_data() -> void:
	engine.reset_all_state()
