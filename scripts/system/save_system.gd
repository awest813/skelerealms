extends Node
## The savegame system.
## This should be autoloaded.
##
## Save format (full snapshot with incremental merge):
## Each save is a complete snapshot of all tracked entities and systems.
## When saving, the new snapshot is merged on top of the most recent save so
## that entities not currently loaded still keep their persisted state.
## This is a "hybrid snapshot with deltas" approach — every file is a full
## snapshot, but building it reuses data from the prior save for entities that
## are off-screen.
##
## Save schema layout:
##   schema_version  — int, for forward-compatible migrations
##   game_info       — global game state (world time, continuity flags, quest/crime/dialogue state)
##   entity_data     — per-entity state keyed by RefID; each entry contains
##                     entity_data (position, rotation, world, form_id, unique) and
##                     components (keyed by component name)
##   other_data      — anything else registered via the "savegame_other" group
##   checksum        — FNV-1a integrity check


## The current save schema version. Increment when the save format changes.
const SAVE_SCHEMA_VERSION: int = 2

## Called when the savegame is complete.
## Use this to, for example, freeze the game until complete, or tell the netity manager to clean up stale entities.
signal save_complete
## Called when the loading process is complete. See [signal save_complete].
signal load_complete


## Registered migration functions. Key is the version to migrate FROM (int -> Callable).
## Each callable receives a Dictionary and returns the migrated Dictionary.
var _migrations: Dictionary[int, Callable] = {}

## Guard flag — true while a save is in progress.
## Prevents concurrent or re-entrant saves that could corrupt the file.
var _saving: bool = false


func _ready() -> void:
	# Register built-in migrations
	register_migration(1, _migrate_v1_to_v2)


## Register a migration that upgrades saves from [param from_version] to [code]from_version + 1[/code].
## The callable should accept a [Dictionary] and return the migrated [Dictionary].
func register_migration(from_version: int, migration: Callable) -> void:
	_migrations[from_version] = migration


## Save the game and write it to user://saves directory.
## [param slot_name]: optional name for the save slot (e.g. "quicksave", "slot_1").
## If empty, falls back to a datetime string.
## Returns without saving if a save is already in progress.
func save(slot_name: String = "") -> void:
	if _saving:
		push_warning("SaveSystem: save() called while a save is already in progress. Ignoring.")
		return
	_saving = true

	var save_data = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"game_info" : {}, # info about the game, like playtime, quests, etc
		"entity_data" : {}, # savegame info from entities
		"other_data" : {} # anything else
	}

	# collect savegame data from entities
	for sd in get_tree().get_nodes_in_group("savegame_entity"):
		save_data["entity_data"][sd.name] = sd.save()
	# collect savegame data from game info
	for sd in get_tree().get_nodes_in_group("savegame_gameinfo"):
		save_data["game_info"][sd.name] = sd.save()
	# collect anything else
	for sd in get_tree().get_nodes_in_group("savegame_other"):
		save_data["other_data"][sd.name] = sd.save()

	# attempt merge with old data, so we still keep the info about entities that aren't being tracked right now.
	var old_file = _get_most_recent_savegame() # my getting the most recent, which was also merged like this, we accumulate info
	if old_file.some(): # we will only merge if there is something to merge with
		var _old_file := FileAccess.open(old_file.unwrap(), FileAccess.READ)
		if not _old_file:
			push_warning("SaveSystem: Could not open previous save for merge: '%s'." % old_file.unwrap())
		else:
			var old_data:Dictionary = _deserialize(_old_file.get_as_text()) # deserialize old data
			old_data.merge(save_data, true) # merge, taking care to overwrite to keep info up to date
			save_data = old_data # bit funky but I'm lazy

	# Always stamp with current schema version after merge
	save_data["schema_version"] = SAVE_SCHEMA_VERSION

	var save_text:String = _serialize(save_data) # serialize

	# Compute and embed checksum (FNV-1a 32-bit)
	save_data["checksum"] = _compute_checksum(save_text)
	save_text = _serialize(save_data)

	DirAccess.make_dir_recursive_absolute("user://saves/")
	# Determine filename
	var file_name: String
	if slot_name.is_empty():
		file_name = "%s.dat" % Time.get_datetime_string_from_system().replace(":", "")
	else:
		file_name = "%s.dat" % slot_name

	# Write to a temporary file first, then rename to the final path.
	# This ensures a crash or error during writing cannot corrupt an existing
	# save file — the final .dat is only replaced once the write is complete.
	var tmp_name: String = file_name.replace(".dat", ".tmp")
	var file = FileAccess.open("user://saves/%s" % tmp_name, FileAccess.WRITE)
	if not file:
		push_error("SaveSystem: Failed to open tmp file for writing: 'user://saves/%s'." % tmp_name)
		_saving = false
		return
	file.store_string(save_text)
	var flush_ok := file.flush() == OK
	if not flush_ok:
		push_error("SaveSystem: flush() failed for 'user://saves/%s'." % tmp_name)
	file.close()

	# Atomically rename .tmp -> .dat, replacing any existing save for this slot.
	var dir := DirAccess.open("user://saves/")
	if not dir:
		push_error("SaveSystem: Failed to open saves directory for rename operation.")
		_saving = false
		return
	var err := dir.rename(tmp_name, file_name)
	if err != OK:
		push_error("SaveSystem: Failed to rename '%s' to '%s' (error %d)." % [tmp_name, file_name, err])
		_saving = false
		return

	_saving = false
	save_complete.emit()


## Load the most recent savegame, if applicable.
func load_most_recent() -> void:
	var most_recent = _get_most_recent_savegame()
	# only load most recent if there are some
	if most_recent.some():
		load_game(most_recent.unwrap())


## Load a game from a filepath.
func load_game(path:String) -> void:
	var file = FileAccess.open(path, FileAccess.READ) # open file
	if not file:
		push_error("SaveSystem: Failed to open save file '%s'." % path)
		return
	var data_blob:String = file.get_as_text() # read file
	var save_data:Dictionary = _deserialize(data_blob) # parse data
	if save_data.is_empty():
		push_error("SaveSystem: Failed to parse save file '%s'." % path)
		return

	# Validate checksum if present
	if save_data.has("checksum"):
		var stored_checksum: String = save_data["checksum"]
		# Recompute without the checksum field
		var check_data: Dictionary = save_data.duplicate(true)
		check_data.erase("checksum")
		var actual_checksum := _compute_checksum(_serialize(check_data))
		if actual_checksum != stored_checksum:
			push_warning("SaveSystem: Checksum mismatch for '%s'. Save may be corrupted (expected %s, got %s)." % [path, stored_checksum, actual_checksum])

	# Apply migrations if needed
	save_data = _apply_migrations(save_data)

	var entity_data:Dictionary = save_data.get("entity_data", {})
	var game_info_data:Dictionary = save_data.get("game_info", {})
	var other_data:Dictionary = save_data.get("other_data", {})

	# Reset to default state if it doesn't have an entry in the save data
	for e in SKEntityManager.instance.entities:
		if not entity_data.has(e):
			SKEntityManager.instance.entities[e].reset_data()
	# load entity data - loop through all data, get entity (spawning it if it isn't there), call load
	for data in entity_data:
		var entity = SKEntityManager.instance.get_entity(data)
		if entity:
			entity.load_data(entity_data[data])
		else:
			push_warning("SaveSystem: Entity '%s' found in save but could not be loaded." % data)

	# load game info data
	for si in get_tree().get_nodes_in_group("savegame_gameinfo"):
		if game_info_data.has(si.name):
			si.load_data(game_info_data[si.name])
		else:
			si.reset_data()

	# load others data
	for so in get_tree().get_nodes_in_group("savegame_other"):
		if other_data.has(so.name):
			so.load_data(other_data[so.name])
		else:
			so.reset_data()

	load_complete.emit()


## Load a named save slot. Convenience wrapper around [method load_game].
func load_slot(slot_name: String) -> bool:
	var path := "user://saves/%s.dat" % slot_name
	if not FileAccess.file_exists(path):
		return false
	load_game(path)
	return true


## List all save files. Returns an array of filenames (without path prefix).
func list_saves() -> Array[String]:
	var saves: Array[String] = []
	if not DirAccess.dir_exists_absolute("user://saves/"):
		return saves
	saves.append_array(DirAccess.get_files_at("user://saves/"))
	return saves


## Check if an entity is accounted for in the save system. Returns the save data blob if there is, else none.
## Use sparingly; could get memory intensive.
func entity_in_save(ref_id:String) -> Option:
	var most_recent = _get_most_recent_savegame() # get most recent filepath
	# if there was no recent save, it isn't here
	if not most_recent.some():
		return Option.none()
	# deserialize
	var _save_file := FileAccess.open(most_recent.unwrap(), FileAccess.READ)
	if not _save_file:
		push_warning("SaveSystem: Could not open save file for entity lookup: '%s'." % most_recent.unwrap())
		return Option.none()
	var deserialized_data:Dictionary = _deserialize(_save_file.get_as_text())
	if not deserialized_data:
		return Option.none()
	var entity_data:Dictionary = deserialized_data.get("entity_data", {})
	if entity_data.has(ref_id):
		# if the data has it, return the blob
		return Option.from(entity_data[ref_id])
	else:
		# else, it's not here.
		return Option.none()


## Gets the filepath for the most recent savegame. It is sorted by file modification time.
func _get_most_recent_savegame() -> Option:
	if not DirAccess.dir_exists_absolute("user://saves/"):
		return Option.none()

	var dir_files:Array[String] = []
	dir_files.append_array(DirAccess.get_files_at("user://saves/"))
	# if no saves, we got none
	if dir_files.is_empty():
		return Option.none()
	# sort by modified time
	dir_files.sort_custom(func(a:String, b:String): return FileAccess.get_modified_time("user://saves/%s" % a) < FileAccess.get_modified_time("user://saves/%s" % b))
	var most_recent_file:String = dir_files.pop_back()
	# format
	return Option.from("user://saves/%s" % most_recent_file)


## Turn the save game blob into a string.
## You can change this to use whatever system you want. By default, it uses JSON because that comes with Godot.
func _serialize(data:Dictionary) -> String:
	return JSON.stringify(data, "\t" if ProjectSettings.get_setting("skelerealms/savegame_indents") else "", true, true)


## Turn a string into a data blob.
## Like with [method _serialize], you can write your own.
func _deserialize(text:String) -> Dictionary:
	return JSON.parse_string(text)


## Apply registered migrations to bring a save up to [constant SAVE_SCHEMA_VERSION].
func _apply_migrations(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema_version", 0)
	while version < SAVE_SCHEMA_VERSION:
		if _migrations.has(version):
			data = _migrations[version].call(data)
		version += 1
		data["schema_version"] = version
	return data


## Compute a FNV-1a 32-bit checksum for corruption detection.
func _compute_checksum(text: String) -> String:
	var hash_val: int = 0x811c9dc5
	for i in range(text.length()):
		hash_val = hash_val ^ text.unicode_at(i)
		# Multiply by FNV prime, keeping 32-bit unsigned
		hash_val = (hash_val * 0x01000193) & 0xFFFFFFFF
	# Format as zero-padded 8-char hex string
	return "%08x" % hash_val


## Migrate a v1 save to v2.
## v1 stored entity position/unique as raw Variant values that became strings
## after JSON round-trip. v2 stores position as [x,y,z] array, rotation as
## [x,y,z,w] array, and adds form_id.
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
	var entity_data: Dictionary = data.get("entity_data", {})
	for entity_id in entity_data:
		var entry: Dictionary = entity_data[entity_id]
		if not entry.has("entity_data"):
			continue
		var ed: Dictionary = entry["entity_data"]

		# Convert position from string "(x, y, z)" to [x, y, z] array
		if ed.has("position") and ed["position"] is String:
			var pos_str: String = ed["position"]
			# Strip parentheses and parse
			pos_str = pos_str.replace("(", "").replace(")", "").strip_edges()
			var parts := pos_str.split(",")
			if parts.size() >= 3:
				ed["position"] = [parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(), parts[2].strip_edges().to_float()]

		# Convert unique from string "true"/"false" to bool
		if ed.has("unique") and ed["unique"] is String:
			ed["unique"] = ed["unique"].to_lower() == "true"

		# Add rotation if missing (identity quaternion)
		if not ed.has("rotation"):
			ed["rotation"] = [0.0, 0.0, 0.0, 1.0]

		# Add form_id if missing
		if not ed.has("form_id"):
			ed["form_id"] = ""

	# Migrate game_info key type: v1 used StringName &"world_time", v2 uses "world_time"
	var game_info: Dictionary = data.get("game_info", {})
	for node_name in game_info:
		var node_data: Dictionary = game_info[node_name]
		# If world_time was stored under a StringName key, re-key it as a string
		if node_data.has(&"world_time") and not node_data.has("world_time"):
			node_data["world_time"] = node_data[&"world_time"]
			node_data.erase(&"world_time")

	return data
