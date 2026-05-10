class_name SKChunkManager
extends Node
## Manages asynchronous loading, mounting, and eviction of world chunks.
##
## Attach this node to the scene tree and call [method update] each frame
## (or on demand) with the current world position. The manager will:
## [br]- Create chunk records for positions within the preload radius
## [br]- Load chunk data via the configured [SKChunkSource]
## [br]- Mount/unmount chunks as they enter/leave the active radius via [SKChunkAdapter]
## [br]- Evict stale chunks that exceed [member max_cached_chunks]
## [br]
## For split-screen or co-op, call [method update_multi] with all origin positions so
## every player's neighbourhood is kept loaded simultaneously.
## [br]
## The system is engine-agnostic — plug in any [SKChunkSource] and [SKChunkAdapter].


## Emitted for every chunk lifecycle event. See [enum EventType].
signal chunk_event(type: String, chunk: SKChunk)

## Sentinel value used when searching for a minimum integer distance.
const _INT_MAX: int = 2147483647


## Size of each chunk in world units.
@export var chunk_size: float = 256.0
## Radius (in chunks) around the origin that are considered active and mounted.
@export var active_radius: int = 1
## Radius (in chunks) around the origin that are preloaded (must be >= active_radius).
@export var preload_radius: int = 2
## Maximum number of loaded chunks kept in memory before eviction.
@export var max_cached_chunks: int = 24
## Maximum number of chunks loading concurrently.
@export var load_concurrency: int = 4
## When true, chunks are selected within a circular (Euclidean) radius instead of a square grid.
## Inspired by Cellblock's distance-to-origin selection strategy; reduces chunk count by ~22 %.
@export var use_circular_radius: bool = false
## Maximum number of retry attempts after a failed load. Set to 0 to disable retries.
## Each retry is preceded by a [member retry_delay]-second pause.
@export var max_load_retries: int = 3
## Seconds to wait between consecutive load retry attempts.
@export var retry_delay: float = 1.0

## The chunk data source. Must be set before calling [method update].
var source: SKChunkSource
## Optional adapter for mounting/unmounting chunks in the scene.
var adapter: SKChunkAdapter

## All known chunks keyed by their string key.
var _chunks: Dictionary = {}
## Keys of chunks currently in the active radius.
var _active_keys: Dictionary = {}
## Keys of chunks currently in the preload radius.
var _preload_keys: Dictionary = {}
## Keys of chunks currently being loaded.
var _loading_keys: Dictionary = {}
## Cancel tokens for in-flight loads, keyed by chunk key.
var _cancel_tokens: Dictionary = {}


func _ready() -> void:
	_normalize_config()


## Updates the chunk grid around [param world_position].
## Call this each frame or whenever the origin moves significantly.
## Delegates to [method update_multi] with a single origin.
func update(world_position: Vector3) -> void:
	var origins: Array[Vector3] = [world_position]
	await update_multi(origins)


## Updates the chunk grid for multiple origins simultaneously.
## [br]All origin neighbourhoods are merged — useful for split-screen or co-op where
## each player drives their own loading zone. Loading priority is determined by the
## nearest distance from any origin, so chunks closest to any player load first.
func update_multi(origins: Array[Vector3]) -> void:
	_normalize_config()
	if origins.is_empty():
		_clear_origin_state()
		return

	var next_active_keys: Dictionary = {}
	var next_preload_keys: Dictionary = {}
	var all_preload_coords: Array[Vector2i] = []

	for world_pos: Vector3 in origins:
		var center := SKChunkUtils.world_to_chunk_coords(world_pos, chunk_size)
		var active_coords := _get_radius_coords(center, active_radius)
		var preload_coords := _get_radius_coords(center, preload_radius)

		for c in active_coords:
			next_active_keys[SKChunkUtils.to_chunk_key(c)] = true
		for c in preload_coords:
			var k := SKChunkUtils.to_chunk_key(c)
			if not next_preload_keys.has(k):
				next_preload_keys[k] = true
				all_preload_coords.push_back(c)

	# Sort combined preload coords by minimum Manhattan distance to any origin (closest first).
	all_preload_coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da_min: int = _INT_MAX
		var db_min: int = _INT_MAX
		for world_pos: Vector3 in origins:
			var center := SKChunkUtils.world_to_chunk_coords(world_pos, chunk_size)
			var da := absi(a.x - center.x) + absi(a.y - center.y)
			var db := absi(b.x - center.x) + absi(b.y - center.y)
			if da < da_min:
				da_min = da
			if db < db_min:
				db_min = db
		return da_min < db_min
	)

	# Ensure chunk records exist for everything in the preload radius.
	for coords in all_preload_coords:
		_ensure_chunk(coords)

	# Touch chunks that are still in the preload zone.
	for key: String in _chunks:
		if next_preload_keys.has(key):
			(_chunks[key] as SKChunk).last_touched = Time.get_ticks_msec()

	# Load any chunks that need data.
	await _load_needed_chunks(all_preload_coords)

	# Activate newly active chunks.
	for key: String in next_active_keys:
		if not _active_keys.has(key):
			var chunk: SKChunk = _chunks.get(key) as SKChunk
			if not chunk:
				continue
			_active_keys[key] = true
			_emit("activated", chunk)
			if chunk.is_loaded and not chunk.is_mounted:
				_mount_chunk(chunk)

	# Deactivate chunks that left the active radius.
	_deactivate_chunks_not_in(next_active_keys)

	# Refresh preload key set.
	_preload_keys = next_preload_keys.duplicate()

	# Evict excess cached chunks.
	_evict_cache()
	_prune_stale_unloaded_chunks()


## Tears down all chunks — unmounts, unloads, and clears internal state.
func dispose() -> void:
	# Cancel all in-flight loads.
	for key: String in _cancel_tokens:
		(_cancel_tokens[key] as SKCancelToken).cancel()

	# Unmount all mounted chunks.
	for chunk: SKChunk in _get_mounted_chunks():
		_unmount_chunk(chunk)

	# Unload all loaded chunks.
	for chunk: SKChunk in _get_loaded_chunks():
		_unload_chunk(chunk)

	for chunk: SKChunk in get_all_chunks():
		_reset_chunk_state(chunk)

	_active_keys.clear()
	_preload_keys.clear()
	_loading_keys.clear()
	_cancel_tokens.clear()
	_chunks.clear()


# ---------------------------------------------------------------------------
#  Public queries
# ---------------------------------------------------------------------------

## Returns the chunk overlapping the given world position, or null.
func get_chunk_at_world(world_pos: Vector3) -> SKChunk:
	var coords := SKChunkUtils.world_to_chunk_coords(world_pos, chunk_size)
	return _chunks.get(SKChunkUtils.to_chunk_key(coords)) as SKChunk


## Returns a chunk by its string key, or null.
func get_chunk_by_key(key: String) -> SKChunk:
	return _chunks.get(key) as SKChunk


## Returns all chunks whose data is loaded.
func get_loaded_chunks() -> Array[SKChunk]:
	return _get_loaded_chunks()


## Returns all chunks in the active radius.
func get_active_chunks() -> Array[SKChunk]:
	var result: Array[SKChunk] = []
	for key: String in _active_keys:
		var c: SKChunk = _chunks.get(key) as SKChunk
		if c:
			result.push_back(c)
	return result


## Returns all currently mounted chunks.
func get_mounted_chunks() -> Array[SKChunk]:
	return _get_mounted_chunks()


## Returns every chunk known to the manager, regardless of state.
## Useful for debug visualization and diagnostics.
func get_all_chunks() -> Array[SKChunk]:
	var result: Array[SKChunk] = []
	for key: String in _chunks:
		result.push_back(_chunks[key] as SKChunk)
	return result


## Clears a failed chunk's error state so the next update can try loading it again.
func retry_chunk(key: String) -> bool:
	var chunk: SKChunk = _chunks.get(key) as SKChunk
	if not chunk or chunk.is_loaded or chunk.is_loading or chunk.error == null:
		return false

	chunk.error = null
	chunk.retry_count = 0
	return true


## Clears a failed chunk's error state by world position.
func retry_chunk_at_world(world_pos: Vector3) -> bool:
	var coords := SKChunkUtils.world_to_chunk_coords(world_pos, chunk_size)
	return retry_chunk(SKChunkUtils.to_chunk_key(coords))


# ---------------------------------------------------------------------------
#  Internals
# ---------------------------------------------------------------------------

## Returns coordinates within the configured radius shape around [param center].
## Uses circular (Euclidean) selection when [member use_circular_radius] is true,
## otherwise a square grid — matching Cellblock's configurable-shape approach.
func _get_radius_coords(center: Vector2i, radius: int) -> Array[Vector2i]:
	var raw: Array[Vector2i] = (
		SKChunkUtils.circle_coords_around(center, radius)
		if use_circular_radius
		else SKChunkUtils.square_coords_around(center, radius)
	)
	return SKChunkUtils.sort_coords_by_distance(raw, center)


func _normalize_config() -> void:
	if chunk_size <= 0.0:
		push_warning("SKChunkManager.chunk_size must be greater than 0; clamping to 1.0.")
		chunk_size = 1.0
	active_radius = maxi(active_radius, 0)
	preload_radius = maxi(preload_radius, active_radius)
	max_cached_chunks = maxi(max_cached_chunks, 0)
	load_concurrency = maxi(load_concurrency, 1)
	max_load_retries = maxi(max_load_retries, 0)
	retry_delay = maxf(retry_delay, 0.0)


func _clear_origin_state() -> void:
	_deactivate_chunks_not_in({})
	_preload_keys.clear()
	_evict_cache()
	_prune_stale_unloaded_chunks()


func _deactivate_chunks_not_in(next_active_keys: Dictionary) -> void:
	var to_deactivate: Array[String] = []
	for key: String in _active_keys:
		if not next_active_keys.has(key):
			to_deactivate.push_back(key)
	for key in to_deactivate:
		var chunk: SKChunk = _chunks.get(key) as SKChunk
		_active_keys.erase(key)
		if not chunk:
			continue
		_emit("deactivated", chunk)
		if chunk.is_mounted:
			_unmount_chunk(chunk)


func _ensure_chunk(coords: Vector2i) -> SKChunk:
	var key := SKChunkUtils.to_chunk_key(coords)
	if _chunks.has(key):
		return _chunks[key] as SKChunk
	var chunk := SKChunk.new(coords)
	_chunks[key] = chunk
	_emit("created", chunk)
	return chunk


func _load_needed_chunks(coords_list: Array[Vector2i]) -> void:
	var queue: Array[SKChunk] = []
	for coords in coords_list:
		var chunk: SKChunk = _chunks.get(SKChunkUtils.to_chunk_key(coords)) as SKChunk
		if chunk and not chunk.is_loaded and not chunk.is_loading and chunk.error == null:
			queue.push_back(chunk)

	# Spawn up to load_concurrency workers pulling from the shared queue.
	var worker_count := mini(load_concurrency, queue.size())

	var workers: Array = []
	for i in worker_count:
		workers.push_back(_load_worker(queue))
	# Wait for all workers to finish (each is a coroutine).
	for w in workers:
		await w


func _load_worker(queue: Array[SKChunk]) -> void:
	while queue.size() > 0:
		var chunk: SKChunk = queue.pop_front()
		if not chunk:
			return
		await _load_chunk(chunk)


func _load_chunk(chunk: SKChunk) -> void:
	if chunk.is_loaded or chunk.is_loading or _loading_keys.has(chunk.key):
		return

	chunk.is_loading = true
	chunk.error = null
	_loading_keys[chunk.key] = true
	_emit("load-start", chunk)

	var token := SKCancelToken.new()
	_cancel_tokens[chunk.key] = token

	var result: Variant = null
	var load_error: Variant = null
	var attempts: int = 0

	# Retry loop: attempt the load, backing off between failures.
	while true:
		result = null
		load_error = null

		if source:
			# GDScript coroutines cannot catch errors from await, so we treat a
			# null result after a non-cancelled load as an error heuristic.
			result = await source.load_chunk(chunk.coords, token)
			if token.is_cancelled:
				chunk.is_loading = false
				_loading_keys.erase(chunk.key)
				_cancel_tokens.erase(chunk.key)
				return
			if result == null:
				load_error = "load_chunk returned null for %s" % chunk.key
		else:
			load_error = "No SKChunkSource configured for %s" % chunk.key

		if load_error == null:
			break  # successful load

		attempts += 1
		chunk.retry_count = attempts
		if max_load_retries > 0 and attempts <= max_load_retries:
			# Wait before retrying.
			await Engine.get_main_loop().create_timer(retry_delay).timeout
			if token.is_cancelled:
				chunk.is_loading = false
				_loading_keys.erase(chunk.key)
				_cancel_tokens.erase(chunk.key)
				return
			_emit("load-retry", chunk)
		else:
			break  # retries disabled or exhausted

	if load_error != null:
		chunk.error = load_error
		chunk.retry_count = attempts
		_emit("load-error", chunk)
	else:
		chunk.retry_count = 0
		chunk.data = result
		chunk.is_loaded = true
		chunk.last_touched = Time.get_ticks_msec()
		_emit("loaded", chunk)

		if _active_keys.has(chunk.key) and not chunk.is_mounted:
			_mount_chunk(chunk)

	chunk.is_loading = false
	_loading_keys.erase(chunk.key)
	_cancel_tokens.erase(chunk.key)


func _mount_chunk(chunk: SKChunk) -> void:
	if not adapter or chunk.is_mounted or not chunk.is_loaded:
		return
	_emit("mount-start", chunk)
	adapter.mount(chunk)
	chunk.is_mounted = true
	_emit("mounted", chunk)


func _unmount_chunk(chunk: SKChunk) -> void:
	if not adapter or not chunk.is_mounted:
		return
	_emit("unmount-start", chunk)
	adapter.unmount(chunk)
	chunk.is_mounted = false
	_emit("unmounted", chunk)


func _unload_chunk(chunk: SKChunk) -> void:
	if not chunk.is_loaded:
		return

	if chunk.is_mounted:
		_unmount_chunk(chunk)

	if _cancel_tokens.has(chunk.key):
		(_cancel_tokens[chunk.key] as SKCancelToken).cancel()
		_cancel_tokens.erase(chunk.key)

	if source:
		source.unload_chunk(chunk)

	chunk.data = null
	chunk.is_loaded = false
	chunk.error = null
	chunk.retry_count = 0
	_emit("unloaded", chunk)


func _reset_chunk_state(chunk: SKChunk) -> void:
	chunk.data = null
	chunk.is_loaded = false
	chunk.is_loading = false
	chunk.is_mounted = false
	chunk.error = null
	chunk.retry_count = 0


func _evict_cache() -> void:
	var loaded := _get_loaded_chunks()
	if loaded.size() <= max_cached_chunks:
		return

	# Build list of eviction candidates: loaded but not active, not preloading, not loading.
	var victims: Array[SKChunk] = []
	for chunk in loaded:
		if not _active_keys.has(chunk.key) \
			and not _preload_keys.has(chunk.key) \
			and not chunk.is_loading:
			victims.push_back(chunk)

	# Evict oldest-touched first.
	victims.sort_custom(func(a: SKChunk, b: SKChunk) -> bool:
		return a.last_touched < b.last_touched
	)

	while _get_loaded_chunks().size() > max_cached_chunks and victims.size() > 0:
		var victim: SKChunk = victims.pop_front()
		if victim:
			_unload_chunk(victim)


func _prune_stale_unloaded_chunks() -> void:
	var to_remove: Array[String] = []
	for key: String in _chunks:
		var chunk: SKChunk = _chunks[key] as SKChunk
		if chunk \
			and not chunk.is_loaded \
			and not chunk.is_loading \
			and not _active_keys.has(key) \
			and not _preload_keys.has(key):
			to_remove.push_back(key)

	for key in to_remove:
		_chunks.erase(key)


func _get_loaded_chunks() -> Array[SKChunk]:
	var result: Array[SKChunk] = []
	for key: String in _chunks:
		var c: SKChunk = _chunks[key] as SKChunk
		if c.is_loaded:
			result.push_back(c)
	return result


func _get_mounted_chunks() -> Array[SKChunk]:
	var result: Array[SKChunk] = []
	for key: String in _chunks:
		var c: SKChunk = _chunks[key] as SKChunk
		if c.is_mounted:
			result.push_back(c)
	return result


func _emit(type: String, chunk: SKChunk) -> void:
	chunk_event.emit(type, chunk)
