class_name SpawnTrackerManager
extends Node
## Manages persistence of [NPCSpawnPoint.spawn_tracker] across save/load cycles.
## Registers with the [code]savegame_other[/code] group so the save system
## automatically serializes and restores spawn state.


static var instance: SpawnTrackerManager


func _ready() -> void:
	name = "SpawnTrackerManager"
	instance = self
	add_to_group("savegame_other")


## Serialize the spawn tracker dictionary for the save system.
## Keys are converted to strings because JSON does not support integer keys.
func save() -> Dictionary:
	var data := {}
	for key in NPCSpawnPoint.spawn_tracker:
		data[str(key)] = NPCSpawnPoint.spawn_tracker[key]
	return {"spawn_tracker": data}


## Restore spawn tracker state from a save file.
func load_data(data: Dictionary) -> void:
	NPCSpawnPoint.spawn_tracker.clear()
	var tracker_data: Dictionary = data.get("spawn_tracker", {})
	for key in tracker_data:
		NPCSpawnPoint.spawn_tracker[int(key)] = tracker_data[key]


## Reset spawn tracker to empty (new game or missing save entry).
func reset_data() -> void:
	NPCSpawnPoint.spawn_tracker.clear()
