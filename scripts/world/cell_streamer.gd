class_name CellStreamer
extends Node3D
## Owns streaming for one exterior worldspace: a chunk manager fed by cell
## scenes, radius updates around the player, and the worldspace's actor
## fade-distance policy (applied on start, restored on stop).
##
## Add one as a child of the worldspace root scene. Interiors stay
## door-loaded through WorldLoader — the source skips interior cells and
## wilderness gaps mount as no-ops.


## Currently streamed worldspace, if any.
var worldspace: WorldspaceDefinition
## Previous fade distance, restored by stop().
var _previous_fade_distance: float = -1.0

var _manager: SKChunkManager


func _init() -> void:
	_manager = SKChunkManager.new()
	add_child(_manager)


## Begin streaming a worldspace: configure radii, install the cell
## source/adapter, and apply its fade policy.
func start(space: WorldspaceDefinition) -> void:
	stop()
	worldspace = space
	_manager.chunk_size = space.cell_size
	_manager.active_radius = space.active_radius
	_manager.preload_radius = space.preload_radius
	_manager.source = CellChunkSource.new(space)
	_manager.adapter = CellChunkAdapter.new(self, space.cell_size)
	_previous_fade_distance = float(ProjectSettings.get_setting("skelerealms/actor_fade_distance", 100.0))
	ProjectSettings.set_setting("skelerealms/actor_fade_distance", space.actor_fade_distance)
	if SKEntityManager.instance:
		SKEntityManager.instance.invalidate_fade_cache()


## Refresh the streaming grid around a world position. Awaits loads.
func update_origin(world_position: Vector3) -> void:
	if worldspace == null or _manager == null:
		return
	await _manager.update(world_position)


## Cell ids currently mounted (streamed-in exteriors).
func loaded_cells() -> Array:
	var ids: Array = []
	for chunk in _manager.get_mounted_chunks():
		var cell_id: StringName = (chunk.data as Dictionary).get("cell_id", &"") if chunk.data is Dictionary else &""
		if cell_id != &"":
			ids.append(cell_id)
	return ids


## Stop streaming: dispose the grid and restore the previous fade policy.
func stop() -> void:
	if _manager:
		_manager.dispose()
	if _previous_fade_distance >= 0.0:
		ProjectSettings.set_setting("skelerealms/actor_fade_distance", _previous_fade_distance)
		_previous_fade_distance = -1.0
		if SKEntityManager.instance:
			SKEntityManager.instance.invalidate_fade_cache()
	worldspace = null


func _exit_tree() -> void:
	stop()
