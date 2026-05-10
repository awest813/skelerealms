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
	# Move far enough that some chunks leave the active radius.
	await mgr.update(Vector3(2560, 0, 2560))
	assert_true(adp.unmount_count > 0, "Some chunks should have been unmounted.")


func test_update_multi_empty_origins_unmounts_active_chunks() -> void:
	var adp := _TestAdapter.new()
	var mgr := _make_manager(null, adp)
	await mgr.update(Vector3(0, 0, 0))
	assert_true(mgr.get_mounted_chunks().size() > 0)

	var origins: Array[Vector3] = []
	await mgr.update_multi(origins)
	assert_eq(mgr.get_active_chunks().size(), 0)
	assert_eq(mgr.get_mounted_chunks().size(), 0)
	assert_true(adp.unmount_count > 0, "Empty origins should deactivate mounted chunks.")


func test_preload_radius_normalizes_to_active_radius() -> void:
	var mgr := _make_manager()
	mgr.active_radius = 1
	mgr.preload_radius = 0

	await mgr.update(Vector3(0, 0, 0))
	assert_eq(mgr.preload_radius, 1)
	assert_eq(mgr.get_loaded_chunks().size(), 9,
		"Active chunks should still load when preload_radius is configured too small.")


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


# ── Circular radius ───────────────────────────────────────────────────────────


func test_circle_coords_around_radius_0() -> void:
	var coords := SKChunkUtils.circle_coords_around(Vector2i(5, 5), 0)
	assert_eq(coords.size(), 1)
	assert_eq(coords[0], Vector2i(5, 5))


func test_circle_coords_around_radius_1() -> void:
	var coords := SKChunkUtils.circle_coords_around(Vector2i(0, 0), 1)
	# Euclidean radius 1: only coords with x²+y² ≤ 1 qualify → diamond of 5.
	assert_eq(coords.size(), 5, "Radius-1 circle should contain 5 coords (diamond).")
	assert_true(coords.has(Vector2i(0, 0)))
	assert_true(coords.has(Vector2i(1, 0)))
	assert_true(coords.has(Vector2i(-1, 0)))
	assert_true(coords.has(Vector2i(0, 1)))
	assert_true(coords.has(Vector2i(0, -1)))
	assert_false(coords.has(Vector2i(1, 1)), "Diagonal corners should be excluded from radius-1 circle.")


func test_circle_coords_fewer_than_square() -> void:
	var center := Vector2i(0, 0)
	var radius := 3
	var circle := SKChunkUtils.circle_coords_around(center, radius)
	var square := SKChunkUtils.square_coords_around(center, radius)
	assert_true(circle.size() < square.size(),
		"Circle radius should produce fewer coords than square at the same radius.")


func test_circular_radius_manager() -> void:
	var mgr := _make_manager()
	mgr.use_circular_radius = true
	mgr.active_radius = 1
	mgr.preload_radius = 1
	await mgr.update(Vector3(0, 0, 0))
	# Circular radius=1 yields 5 chunks (diamond), not 9 (3×3 square).
	assert_eq(mgr.get_loaded_chunks().size(), 5,
		"Circular radius=1 should load 5 chunks, not 9.")


# ── Load retry ────────────────────────────────────────────────────────────────


class _FailingSource extends SKChunkSource:
	## Fails the first [member fail_count] load attempts, then succeeds.
	var fail_count: int = 2
	var _call_count: int = 0
	func load_chunk(_coords: Vector2i, _cancelled: SKCancelToken = null) -> Variant:
		_call_count += 1
		if _call_count <= fail_count:
			return null
		return {"ok": true}


class _AlwaysFailSource extends SKChunkSource:
	func load_chunk(_coords: Vector2i, _cancelled: SKCancelToken = null) -> Variant:
		return null


class _CountingFailSource extends SKChunkSource:
	var load_count: int = 0
	func load_chunk(_coords: Vector2i, _cancelled: SKCancelToken = null) -> Variant:
		load_count += 1
		return null


func test_retry_succeeds_after_failures() -> void:
	# Source fails the first 2 calls, succeeds on the 3rd.
	var src := _FailingSource.new()
	src.fail_count = 2
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 3
	mgr.retry_delay = 0.0
	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_not_null(chunk)
	assert_true(chunk.is_loaded, "Chunk should be loaded after retries succeed.")
	assert_null(chunk.error, "Chunk error should be null on successful retry.")
	assert_eq(chunk.retry_count, 0, "retry_count should reset to 0 on success.")


func test_retry_exhausted_sets_error() -> void:
	var src := _AlwaysFailSource.new()
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 2
	mgr.retry_delay = 0.0
	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_not_null(chunk)
	assert_false(chunk.is_loaded, "Chunk should not be loaded after exhausting retries.")
	assert_not_null(chunk.error, "Chunk should have an error after exhausting retries.")
	# 3 total attempts: 1 initial + 2 retries → retry_count = 3.
	assert_eq(chunk.retry_count, 3,
		"retry_count should equal total attempts (1 initial + max_load_retries).")


func test_retry_disabled_on_zero() -> void:
	var src := _AlwaysFailSource.new()
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 0
	mgr.retry_delay = 0.0
	var events: Array[String] = []
	mgr.chunk_event.connect(func(type: String, _chunk: SKChunk) -> void:
		events.push_back(type)
	)
	await mgr.update(Vector3(0, 0, 0))
	assert_false(events.has("load-retry"), "No retry events should fire when max_load_retries=0.")


func test_retry_count_resets_on_dispose() -> void:
	var src := _AlwaysFailSource.new()
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 1
	mgr.retry_delay = 0.0
	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_true(chunk.retry_count > 0, "retry_count should be non-zero after failures.")
	mgr.dispose()
	# After dispose the chunk object still exists in our local reference.
	assert_eq(chunk.retry_count, 0, "retry_count should reset to 0 on dispose.")


func test_failed_chunk_does_not_retry_every_update() -> void:
	var src := _CountingFailSource.new()
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 0
	mgr.retry_delay = 0.0

	await mgr.update(Vector3(0, 0, 0))
	await mgr.update(Vector3(0, 0, 0))
	assert_eq(src.load_count, 1,
		"Chunks in error state should not reload every update without an explicit retry.")


func test_retry_chunk_allows_failed_chunk_to_load_again() -> void:
	var src := _FailingSource.new()
	src.fail_count = 1
	var mgr := _make_manager(src, null)
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 0
	mgr.retry_delay = 0.0

	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_not_null(chunk)
	assert_false(chunk.is_loaded)
	assert_not_null(chunk.error)
	assert_true(mgr.retry_chunk_at_world(Vector3(0, 0, 0)))

	await mgr.update(Vector3(0, 0, 0))
	assert_true(chunk.is_loaded, "Explicit retry should allow a failed chunk to load again.")
	assert_null(chunk.error)


func test_missing_source_sets_load_error() -> void:
	var mgr := SKChunkManager.new()
	mgr.active_radius = 0
	mgr.preload_radius = 0
	mgr.max_load_retries = 0
	mgr.retry_delay = 0.0
	add_child(mgr)

	await mgr.update(Vector3(0, 0, 0))
	var chunk := mgr.get_chunk_at_world(Vector3(0, 0, 0))
	assert_not_null(chunk)
	assert_false(chunk.is_loaded, "Chunks should not be marked loaded without a source.")
	assert_not_null(chunk.error, "Missing source should surface as a load error.")


# ── Multi-origin ──────────────────────────────────────────────────────────────


func test_update_multi_merges_origins() -> void:
	var mgr := _make_manager()
	mgr.active_radius = 0
	mgr.preload_radius = 0
	# Two origins far apart; with radius=0 each contributes exactly 1 chunk.
	var origins: Array[Vector3] = [Vector3(0, 0, 0), Vector3(10240, 0, 10240)]
	await mgr.update_multi(origins)
	assert_not_null(mgr.get_chunk_at_world(Vector3(0, 0, 0)),
		"Chunk around first origin should be loaded.")
	assert_not_null(mgr.get_chunk_at_world(Vector3(10240, 0, 10240)),
		"Chunk around second origin should be loaded.")
	assert_eq(mgr.get_loaded_chunks().size(), 2,
		"With radius=0 and two distinct origins, exactly 2 chunks should be loaded.")


func test_update_delegates_to_update_multi() -> void:
	# Calling update() and update_multi() with the same position should produce
	# identical chunk sets.
	var mgr1 := _make_manager()
	var mgr2 := _make_manager()
	await mgr1.update(Vector3(128, 0, 128))
	var origins: Array[Vector3] = [Vector3(128, 0, 128)]
	await mgr2.update_multi(origins)
	assert_eq(
		mgr1.get_loaded_chunks().size(),
		mgr2.get_loaded_chunks().size(),
		"update() and update_multi([pos]) should load the same number of chunks."
	)


# ── get_all_chunks ────────────────────────────────────────────────────────────


func test_get_all_chunks() -> void:
	var mgr := _make_manager()
	await mgr.update(Vector3(0, 0, 0))
	var all_chunks := mgr.get_all_chunks()
	assert_true(all_chunks.size() > 0, "get_all_chunks should return at least one chunk.")
	# Every chunk returned by get_loaded_chunks must appear in get_all_chunks.
	for c: SKChunk in mgr.get_loaded_chunks():
		assert_true(all_chunks.has(c), "get_all_chunks must contain every loaded chunk.")
