class_name DialogueSceneRunner
extends RefCounted
## Performs a [DialogueScene]: drives its backing tree through a session
## while pinning the cast, reporting blocked actors, and persisting.
## Pure logic — no scene-tree access. Presence checks and positions arrive
## through injected callables so tests can stub the world.


## (participants: Array) -> Array of present actor refs.
## Defaults to everyone present; games override with entity/proximity queries.
var participant_provider: Callable = func(participants: Array) -> Array: return participants
## Dialogue engine used to create the backing session. Set by the owner.
var dialogue_engine: DialogueEngine
## Human-readable reason the last start failed.
var last_error: String = ""

var _scene: DialogueScene
var _session: DialogueSession
var _running := false


## Whether a scene performance is currently running.
func is_running() -> bool:
	return _running


## The scene being performed, or null.
func get_scene() -> DialogueScene:
	return _scene


## The live backing session (shared with DialogueSystem hosting).
func get_session() -> DialogueSession:
	return _session


## Start performing a scene. Returns false (with last_error set) when the
## backing dialogue is unknown or required participants are missing.
func start(scene: DialogueScene, context: DialogueContext) -> bool:
	last_error = ""
	if scene == null:
		last_error = "No scene provided."
		return false
	if dialogue_engine == null or not dialogue_engine.has_dialogue(scene.dialogue_id):
		last_error = "Scene '%s' needs unknown dialogue '%s'." % [scene.id, scene.dialogue_id]
		return false
	var required: Array = scene.required_participants if not scene.required_participants.is_empty() else scene.participants
	var present: Array = participant_provider.call(scene.participants)
	var missing := PackedStringArray()
	for actor in required:
		if not present.has(actor):
			missing.append(str(actor))
	if not missing.is_empty():
		last_error = "Scene '%s' missing participants: %s." % [scene.id, ", ".join(missing)]
		return false
	var session := dialogue_engine.create_session(scene.dialogue_id, context)
	if session == null:
		last_error = "Scene '%s' could not start its dialogue." % scene.id
		return false
	_scene = scene
	_session = session
	_running = true
	return true


## Advance the backing session by one choice.
func advance(choice_id: StringName) -> DialogueEngine.DialogueAdvanceResult:
	var result := DialogueEngine.DialogueAdvanceResult.new()
	if not _running or _session == null:
		result.success = false
		result.message = "No scene is running."
		result.is_complete = true
		return result
	result = _session.choose(choice_id)
	if result.is_complete:
		_running = false
	return result


## Current node view with the scene cast applied, or null.
func current_view() -> DialogueEngine.DialogueNodeView:
	if not _running or _session == null:
		return null
	var view := _session.get_current_node()
	if view and _scene and _scene.cast.has(view.id):
		view.speaker = _scene.cast[view.id]
	return view


## Who speaks the current line (cast override first, authored speaker fallback).
func current_speaker() -> String:
	var view := current_view()
	return view.speaker if view else ""


## Actors the game layer should hold (freeze packages, face the speaker).
## The full participant list while running, empty otherwise.
func get_blocked_actors() -> Array:
	if not _running or _scene == null:
		return []
	return _scene.participants.duplicate()


## Stop the performance early. Blocked actors release.
func end() -> void:
	_running = false


## Pure proximity check for auto-greets. Radius <= 0 never triggers.
static func in_greet_range(scene: DialogueScene, from_pos: Vector3, to_pos: Vector3) -> bool:
	if scene == null or scene.greet_radius <= 0.0:
		return false
	return from_pos.distance_to(to_pos) <= scene.greet_radius


## Snapshot for saving: scene id plus the backing session snapshot.
func get_snapshot() -> Dictionary:
	if _scene == null or _session == null:
		return {}
	return {
		"scene_id": str(_scene.id),
		"session": _session.get_snapshot().serialize(),
	}


## Resume from a snapshot. Needs the scene def, a context, and an engine
## with the backing dialogue registered. Returns false when anything is missing.
func restore_snapshot(data: Dictionary, scene: DialogueScene, context: DialogueContext) -> bool:
	last_error = ""
	var session_data: Dictionary = data.get("session", {})
	if scene == null or session_data.is_empty():
		last_error = "Scene snapshot is malformed."
		return false
	if dialogue_engine == null or not dialogue_engine.has_dialogue(scene.dialogue_id):
		last_error = "Scene '%s' needs unknown dialogue '%s'." % [scene.id, scene.dialogue_id]
		return false
	var session := dialogue_engine.create_session(scene.dialogue_id, context)
	if session == null:
		last_error = "Scene '%s' could not resume its dialogue." % scene.id
		return false
	var snapshot := DialogueEngine.DialogueSessionSnapshot.deserialize(session_data)
	session.restore_from_snapshot(snapshot)
	if snapshot.completed:
		return false
	_scene = scene
	_session = session
	_running = true
	return true
