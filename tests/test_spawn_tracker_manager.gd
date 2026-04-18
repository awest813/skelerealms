## Unit tests for SpawnTrackerManager.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Verifies that SpawnTrackerManager correctly persists, restores, and resets
## the NPCSpawnPoint.spawn_tracker dictionary, including the int↔string key
## conversion required for JSON compatibility.
extends GutTest


# ── Helpers ────────────────────────────────────────────────────────────────


## A fresh SpawnTrackerManager wired into the scene tree.
var _manager: SpawnTrackerManager


func before_each() -> void:
	NPCSpawnPoint.spawn_tracker.clear()
	_manager = SpawnTrackerManager.new()
	add_child_autofree(_manager)


func after_each() -> void:
	NPCSpawnPoint.spawn_tracker.clear()


# ── save() ─────────────────────────────────────────────────────────────────


func test_save_returns_empty_spawn_tracker_when_no_spawns() -> void:
	var data: Dictionary = _manager.save()
	assert_true(data.has("spawn_tracker"))
	assert_eq((data["spawn_tracker"] as Dictionary).size(), 0)


func test_save_converts_int_keys_to_strings() -> void:
	NPCSpawnPoint.spawn_tracker[42] = true
	NPCSpawnPoint.spawn_tracker[99] = true

	var data: Dictionary = _manager.save()
	var tracker: Dictionary = data["spawn_tracker"]

	assert_true(tracker.has("42"), "Integer key 42 should be saved as string '42'.")
	assert_true(tracker.has("99"), "Integer key 99 should be saved as string '99'.")
	assert_eq(tracker.size(), 2)


func test_save_preserves_values() -> void:
	NPCSpawnPoint.spawn_tracker[1] = true
	var data: Dictionary = _manager.save()
	assert_eq(data["spawn_tracker"]["1"], true)


# ── load_data() ────────────────────────────────────────────────────────────


func test_load_data_restores_entries_as_int_keys() -> void:
	var data := {"spawn_tracker": {"10": true, "20": true}}
	_manager.load_data(data)

	assert_true(NPCSpawnPoint.spawn_tracker.has(10), "Key '10' should be restored as int 10.")
	assert_true(NPCSpawnPoint.spawn_tracker.has(20), "Key '20' should be restored as int 20.")
	assert_eq(NPCSpawnPoint.spawn_tracker.size(), 2)


func test_load_data_clears_existing_entries_first() -> void:
	NPCSpawnPoint.spawn_tracker[999] = true
	_manager.load_data({"spawn_tracker": {"5": true}})

	assert_false(NPCSpawnPoint.spawn_tracker.has(999),
		"Pre-existing key 999 should be cleared on load.")
	assert_true(NPCSpawnPoint.spawn_tracker.has(5))


func test_load_data_handles_missing_spawn_tracker_key() -> void:
	NPCSpawnPoint.spawn_tracker[7] = true
	_manager.load_data({})  # no "spawn_tracker" key

	assert_eq(NPCSpawnPoint.spawn_tracker.size(), 0,
		"Missing save key should result in an empty tracker.")


# ── reset_data() ───────────────────────────────────────────────────────────


func test_reset_data_clears_all_entries() -> void:
	NPCSpawnPoint.spawn_tracker[1] = true
	NPCSpawnPoint.spawn_tracker[2] = true
	_manager.reset_data()

	assert_eq(NPCSpawnPoint.spawn_tracker.size(), 0,
		"reset_data should clear the entire spawn tracker.")


# ── round-trip ─────────────────────────────────────────────────────────────


func test_save_then_load_round_trip() -> void:
	NPCSpawnPoint.spawn_tracker[100] = true
	NPCSpawnPoint.spawn_tracker[200] = true

	var saved: Dictionary = _manager.save()
	NPCSpawnPoint.spawn_tracker.clear()
	_manager.load_data(saved)

	assert_true(NPCSpawnPoint.spawn_tracker.has(100))
	assert_true(NPCSpawnPoint.spawn_tracker.has(200))
	assert_eq(NPCSpawnPoint.spawn_tracker.size(), 2)
