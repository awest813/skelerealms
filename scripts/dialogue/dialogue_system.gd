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
## The running scene performance, if any. Its session IS active_session.
var active_scene: DialogueSceneRunner
## Scene registry: scene_id -> DialogueScene. Survives resets like dialogue defs.
var scenes: Dictionary = {}
## Presence check handed to scene runners: (participants: Array) -> Array
## of present actor refs. Defaults to everyone present; games override
## with entity/proximity queries.
var scene_participant_provider: Callable = func(participants: Array) -> Array: return participants


func _ready() -> void:
	add_to_group("savegame_gameinfo")


## Register a [DialogueDefinition] resource with the engine.
func register_dialogue(definition: DialogueDefinition) -> void:
	engine.register_dialogue(definition)


## Register a [DialogueScene] for performances and greet checks.
func register_scene(scene: DialogueScene) -> void:
	scenes[scene.id] = scene


## Returns true if a scene is registered.
func has_scene(scene_id: StringName) -> bool:
	return scenes.has(scene_id)


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
		active_scene = null
	return result


## Get the current node view of the active session (or null).
## Inside a scene, the speaker carries the scene cast override.
func get_current_node() -> DialogueEngine.DialogueNodeView:
	if not active_session:
		return null
	var view := active_session.get_current_node()
	if view and active_scene and active_scene.is_running():
		view.speaker = active_scene.current_speaker()
	return view


## End the active session early.
## [annotation @rpc] — any peer can end a dialogue session.
@rpc("any_peer", "call_local", "reliable")
func end_dialogue() -> void:
	if active_session:
		dialogue_ended.emit(active_session.get_dialogue_id())
		active_session = null
	active_scene = null


## Start performing a registered scene. The scene's session becomes the
## active session, so choose()/save()/end_dialogue() keep working unchanged.
## Replaces any running conversation. Returns the opening view, or null.
func start_scene(scene_id: StringName, context: DialogueContext = null) -> DialogueEngine.DialogueNodeView:
	if not scenes.has(scene_id):
		push_error("DialogueSystem: Unknown scene '%s'." % scene_id)
		return null
	if not context:
		context = DialogueContext.new()
	if active_session:
		end_dialogue()
	var runner := DialogueSceneRunner.new()
	runner.dialogue_engine = engine
	runner.participant_provider = scene_participant_provider
	if not runner.start(scenes[scene_id], context):
		push_error("DialogueSystem: %s" % runner.last_error)
		return null
	active_scene = runner
	active_session = runner.get_session()
	var view := runner.current_view()
	if view:
		dialogue_started.emit(scene_id, view.speaker)
	return view


## Abort the running scene, if any. Aborts the conversation too.
func stop_scene() -> void:
	if active_scene:
		active_scene.end()
		active_scene = null
	end_dialogue()


## Actors the game layer should hold while a scene runs (else []).
func get_blocked_actors() -> Array:
	if active_scene and active_scene.is_running():
		return active_scene.get_blocked_actors()
	return []


## Proximity-greet a registered scene: starts it when the two positions
## are within the scene's greet radius. Returns the opening view, or null.
func try_greet(scene_id: StringName, player_pos: Vector3, actor_pos: Vector3, context: DialogueContext = null) -> DialogueEngine.DialogueNodeView:
	if not scenes.has(scene_id):
		return null
	if not DialogueSceneRunner.in_greet_range(scenes[scene_id], player_pos, actor_pos):
		return null
	return start_scene(scene_id, context)


## Whether a dialogue session is currently active.
func is_in_dialogue() -> bool:
	return active_session != null


# ── Save integration ────────────────────────────────────────────────────────


func save() -> Dictionary:
	var data := {}
	if active_scene and active_scene.is_running():
		data["active_scene"] = active_scene.get_snapshot()
	elif active_session:
		data["active_session"] = active_session.get_snapshot().serialize()
	return data


func load_data(data: Dictionary) -> void:
	if data.has("active_scene"):
		# Scene performances restore through their runner so the cast,
		# blocking, and session resume together.
		var scene_snap: Dictionary = data["active_scene"]
		var scene: DialogueScene = scenes.get(StringName(scene_snap.get("scene_id", "")))
		if scene:
			var runner := DialogueSceneRunner.new()
			runner.dialogue_engine = engine
			runner.participant_provider = scene_participant_provider
			var context := DialogueContext.new()
			if runner.restore_snapshot(scene_snap, scene, context):
				active_scene = runner
				active_session = runner.get_session()
				return
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
	active_scene = null
