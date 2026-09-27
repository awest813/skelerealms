class_name WorldLoader
extends Node
## Owns exactly one active world and commits only validated destinations.

var world_paths: Dictionary[String, String] = {}
var regex: RegEx
var loading_path: String
var last_load_progress: float = 0.0
var _previous_world_id: String = ""
var _destination_id: String = ""
var _request_active := false
var _committing := false
var _was_paused := false
var active_world_id: String = ""

signal begin_world_loading
signal world_loading_ready
signal load_scene_progess_updated(percent: float)
signal world_loading_failed(error_message: String)

func _enter_tree() -> void:
	if get_child_count() > 0:
		GameInfo.world = get_child(0).name
		active_world_id = str(GameInfo.world)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	regex = RegEx.new()
	regex.compile("([^\\/\n\\r]+)\\.t?scn")
	_cache_worlds(ProjectSettings.get_setting("skelerealms/worlds_path", "res://worlds"))

func _process(_delta: float) -> void:
	if not _request_active or _committing:
		return
	var progress := []
	match ResourceLoader.load_threaded_get_status(loading_path, progress):
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(loading_path) as PackedScene
			if scene == null or not scene.can_instantiate():
				_abort("Destination is not an instantiable scene: %s" % loading_path)
				return
			_committing = true
			_finish_load.call_deferred(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_abort("Could not load world: %s" % loading_path)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty() and last_load_progress != float(progress[0]):
				last_load_progress = float(progress[0])
				load_scene_progess_updated.emit(last_load_progress)

## Returns false if the request cannot begin. Completion is signalled separately.
func load_world(wid: String) -> bool:
	if _request_active or GameInfo.is_loading:
		return false
	if not world_paths.has(wid):
		world_loading_failed.emit("World not found: %s" % wid)
		return false
	_request_active = true
	_previous_world_id = active_world_id if not active_world_id.is_empty() else str(GameInfo.world)
	_destination_id = wid
	loading_path = world_paths[wid]
	last_load_progress = 0.0
	_was_paused = get_tree().paused
	GameInfo.is_loading = true
	GameInfo.pause_game(true)
	begin_world_loading.emit()
	GameInfo.game_loading.emit(wid)
	var error := ResourceLoader.load_threaded_request(loading_path, "PackedScene", true)
	if error != OK:
		_abort("Failed to request world '%s' (error %d)." % [wid, error])
		return false
	return true

func _finish_load(scene: PackedScene) -> void:
	var next_world := scene.instantiate()
	if next_world == null:
		_abort("Could not instantiate destination.")
		return
	_unload_world()
	GameInfo.world = StringName(_destination_id)
	active_world_id = _destination_id
	add_child(next_world)
	_end_request()
	load_scene_progess_updated.emit(1.0)
	world_loading_ready.emit()
	GameInfo.game_loaded.emit()

func _unload_world() -> void:
	for old_world in get_children():
		remove_child(old_world)
		old_world.queue_free()

func _end_request() -> void:
	_request_active = false
	_committing = false
	GameInfo.is_loading = false
	loading_path = ""
	if not _was_paused:
		GameInfo.unpause_game()

func _abort(error_message: String = "Unknown world loading error.") -> void:
	# The original world stays attached throughout preparation, so rollback
	# requires no instantiation and cannot duplicate the world.
	GameInfo.world = StringName(_previous_world_id)
	_end_request()
	world_loading_failed.emit(error_message)


## Searches the worlds directory and caches filepaths, matching them to their name
func _cache_worlds(path:String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if '.tscn.remap' in file_name:
				file_name = file_name.trim_suffix('.remap')
			if dir.current_is_dir(): # if is directory, cache subdirectory
				_cache_worlds("%s/%s" % [path, file_name])
			else: # if filename, cache filename
				var result = regex.search(file_name)
				if result:
					world_paths[result.get_string(1)] = "%s/%s" % [path, file_name]
			file_name = dir.get_next()
		dir.list_dir_end()
	
	else:
		push_warning("WorldLoader: Could not open directory '%s'." % path)
