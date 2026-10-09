class_name CellChunkSource
extends SKChunkSource
## SKChunkSource over a [WorldspaceDefinition]: grid coordinates resolve to
## cell scenes, loaded hitch-free on worker threads.
##
## Payload contract (the manager treats null as load ERROR, with retries):
## - {"scene": PackedScene, "cell_id": StringName, "coords": Vector2i} — a cell.
## - {} (empty dict) — nothing here: wilderness gaps and interior cells,
##   which doors load instead. Loads cleanly, mounts nothing.
## - null — real failure (bad path, corrupt scene). Retried, then reported.


var worldspace: WorldspaceDefinition


func _init(worldspace_definition: WorldspaceDefinition = null) -> void:
	worldspace = worldspace_definition


func load_chunk(coords: Vector2i, cancelled: SKCancelToken = null) -> Variant:
	if worldspace == null:
		return null
	var cell := worldspace.get_cell(coords)
	if cell == null or cell.interior or cell.scene_path.is_empty():
		return {}
	if cancelled and cancelled.is_cancelled:
		return null
	var error := ResourceLoader.load_threaded_request(cell.scene_path, "PackedScene", true)
	if error != OK:
		return null
	while true:
		if cancelled and cancelled.is_cancelled:
			return null
		match ResourceLoader.load_threaded_get_status(cell.scene_path):
			ResourceLoader.THREAD_LOAD_LOADED:
				break
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return null
			_:
				await Engine.get_main_loop().process_frame
	if cancelled and cancelled.is_cancelled:
		return null
	var scene := ResourceLoader.load_threaded_get(cell.scene_path) as PackedScene
	if scene == null or not scene.can_instantiate():
		return null
	return {"scene": scene, "cell_id": cell.id, "coords": coords}
