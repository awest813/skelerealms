## Unit tests for SKChunkManager and related chunk utilities.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## These tests exercise chunk coordinate math, key conversion, chunk lifecycle
## (create, load, mount, unmount, unload), cache eviction, and concurrency
## limiting without requiring real world assets.
extends GutTest


# ── SKChunkUtils ─────────────────────────────────────────────────────────────


func test_to_chunk_key() -> void:
	assert_eq(SKChunkUtils.to_chunk_key(Vector2i(3, -2)), "3,-2")
	assert_eq(SKChunkUtils.to_chunk_key(Vector2i(0, 0)), "0,0")


func test_from_chunk_key() -> void:
	assert_eq(SKChunkUtils.from_chunk_key("3,-2"), Vector2i(3, -2))
	assert_eq(SKChunkUtils.from_chunk_key("0,0"), Vector2i(0, 0))


func test_round_trip_key() -> void:
	var original := Vector2i(-7, 42)
	var key := SKChunkUtils.to_chunk_key(original)
	var result := SKChunkUtils.from_chunk_key(key)
	assert_eq(result, original, "Round-trip through key conversion should preserve coords.")


func test_world_to_chunk_coords() -> void:
	# Positive position
	var c := SKChunkUtils.world_to_chunk_coords(Vector3(300, 0, 500), 256.0)
	assert_eq(c, Vector2i(1, 1))
	# Negative position
	var c2 := SKChunkUtils.world_to_chunk_coords(Vector3(-1, 0, -1), 256.0)
	assert_eq(c2, Vector2i(-1, -1))
	# Exact boundary
	var c3 := SKChunkUtils.world_to_chunk_coords(Vector3(256, 0, 0), 256.0)
	assert_eq(c3, Vector2i(1, 0))


func test_square_coords_around_radius_0() -> void:
	var coords := SKChunkUtils.square_coords_around(Vector2i(5, 5), 0)
	assert_eq(coords.size(), 1)
	assert_eq(coords[0], Vector2i(5, 5))


func test_square_coords_around_radius_1() -> void:
	var coords := SKChunkUtils.square_coords_around(Vector2i(0, 0), 1)
	# 3×3 = 9 coords
	assert_eq(coords.size(), 9)
	assert_true(coords.has(Vector2i(-1, -1)))
	assert_true(coords.has(Vector2i(1, 1)))
	assert_true(coords.has(Vector2i(0, 0)))


func test_sort_coords_by_distance() -> void:
	var center := Vector2i(0, 0)
	var coords: Array[Vector2i] = [Vector2i(2, 0), Vector2i(0, 0), Vector2i(1, 0)]
	var sorted := SKChunkUtils.sort_coords_by_distance(coords, center)
	assert_eq(sorted[0], Vector2i(0, 0), "Center should be first (distance 0).")
	assert_eq(sorted[1], Vector2i(1, 0), "Distance 1 should come second.")
	assert_eq(sorted[2], Vector2i(2, 0), "Distance 2 should come last.")


# ── SKChunk ──────────────────────────────────────────────────────────────────


func test_chunk_init() -> void:
	var chunk := SKChunk.new(Vector2i(3, -2))
	assert_eq(chunk.key, "3,-2")
	assert_eq(chunk.coords, Vector2i(3, -2))
	assert_false(chunk.is_loaded)
	assert_false(chunk.is_loading)
	assert_false(chunk.is_mounted)
	assert_null(chunk.data)
	assert_null(chunk.error)
	assert_true(chunk.last_touched > 0)


# ── SKCancelToken ────────────────────────────────────────────────────────────


func test_cancel_token() -> void:
	var token := SKCancelToken.new()
	assert_false(token.is_cancelled)
	token.cancel()
	assert_true(token.is_cancelled)
	# Calling cancel again is safe.
	token.cancel()
	assert_true(token.is_cancelled)


# ── SKChunkManager (lifecycle) ───────────────────────────────────────────────


class _TestSource extends SKChunkSource:
	var load_count: int = 0
	var unload_count: int = 0
	func load_chunk(coords: Vector2i, _cancelled: SKCancelToken = null) -> Variant:
		load_count += 1
		return {"coords_x": coords.x, "coords_y": coords.y}
	func unload_chunk(_chunk: SKChunk) -> void:
		unload_count += 1


class _TestAdapter extends SKChunkAdapter:
	var mount_count: int = 0
	var unmount_count: int = 0
	func mount(_chunk: SKChunk) -> void:
		mount_count += 1
	func unmount(_chunk: SKChunk) -> void:
		unmount_count += 1


func _make_manager(src: SKChunkSource = null, adp: SKChunkAdapter = null) -> SKChunkManager:
	var mgr := SKChunkManager.new()
	mgr.chunk_size = 256.0
	mgr.active_radius = 1
	mgr.preload_radius = 1
	mgr.max_cached_chunks = 24
	mgr.load_concurrency = 4
	mgr.source = src if src else _TestSource.new()
	mgr.adapter = adp if adp else _TestAdapter.new()
	add_child(mgr)
	return mgr


func test_update_creates_chunks() -> void:
	var mgr := _make_manager()
	await mgr.update(Vector3(120, 0, 160))
	# active_radius=1 → 3×3 = 9 chunks
	assert_eq(mgr.get_loaded_chunks().size(), 9,
		"Should load 9 chunks for active_radius=1")


func test_update_mounts_active_chunks() -> void:
	var adp := _TestAdapter.new()
	var mgr := _make_manager(null, adp)
	await mgr.update(Vector3(120, 0, 160))
	assert_eq(mgr.get_mounted_chunks().size(), 9)
	assert_eq(adp.mount_count, 9)


func test_update_unmounts_on_move() -> void:
	var adp := _TestAdapter.new()
	var mgr := _make_manager(null, adp)
	await mgr.update(Vector3(0, 0, 0))
	var first_mounted := mgr.get_mounted_chunks().size()
	# Move far enough that some chunks leave the active radius.
	await mgr.update(Vector3(2560, 0, 2560))
	assert_true(adp.unmount_count > 0, "Some chunks should have been unmounted.")


func test_dispose_clears_state() -> void:
	var src := _TestSource.new()
	var adp := _TestAdapter.new()
	var mgr := _make_manager(src, adp)
	await mgr.update(Vector3(0, 0, 0))
	assert_true(mgr.get_loaded_chunks().size() > 0)
	mgr.dispose()
	assert_eq(mgr.get_loaded_chunks().size(), 0)
	assert_eq(mgr.get_mounted_chunks().size(), 0)
	assert_eq(mgr.get_active_chunks().size(), 0)
	assert_true(adp.unmount_count > 0)
	assert_true(src.unload_count > 0)


func test_get_chunk_at_world() -> void:
	var mgr := _make_manager()
	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_not_null(chunk)
	assert_eq(chunk.coords, Vector2i(0, 0))


func test_get_chunk_by_key() -> void:
	var mgr := _make_manager()
	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_by_key("0,0")
	assert_not_null(chunk)
	assert_eq(chunk.key, "0,0")


func test_chunk_event_signal_fires() -> void:
	var mgr := _make_manager()
	var events: Array[String] = []
	mgr.chunk_event.connect(func(type: String, _chunk: SKChunk) -> void:
		events.push_back(type)
	)
	await mgr.update(Vector3(0, 0, 0))
	assert_true(events.has("created"), "Should emit 'created' events.")
	assert_true(events.has("load-start"), "Should emit 'load-start' events.")
	assert_true(events.has("loaded"), "Should emit 'loaded' events.")
	assert_true(events.has("activated"), "Should emit 'activated' events.")
	assert_true(events.has("mounted"), "Should emit 'mounted' events.")


# ── Cache eviction ───────────────────────────────────────────────────────────


func test_cache_eviction() -> void:
	var src := _TestSource.new()
	var adp := _TestAdapter.new()
	var mgr := _make_manager(src, adp)
	mgr.max_cached_chunks = 9  # exactly one update's worth for radius=1

	# Load first position.
	await mgr.update(Vector3(0, 0, 0))
	assert_eq(mgr.get_loaded_chunks().size(), 9)

	# Move far away — old chunks become eviction candidates.
	await mgr.update(Vector3(10000, 0, 10000))
	# Should have evicted old chunks to stay at or below max.
	assert_true(mgr.get_loaded_chunks().size() <= mgr.max_cached_chunks + 9,
		"Loaded chunks should respect max_cached_chunks after eviction.")
	assert_true(src.unload_count > 0, "Some chunks should have been unloaded.")
