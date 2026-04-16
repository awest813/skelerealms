extends Node
## The savegame system.
## This should be autoloaded.


## The current save schema version. Increment when the save format changes.
const SAVE_SCHEMA_VERSION: int = 1

## Called when the savegame is complete.
## Use this to, for example, freeze the game until complete, or tell the netity manager to clean up stale entities.
signal save_complete
## Called when the loading process is complete. See [signal save_complete].
signal load_complete


## Registered migration functions. Key is the version to migrate FROM (int -> Callable).
## Each callable receives a Dictionary and returns the migrated Dictionary.
var _migrations: Dictionary = {}


## Register a migration that upgrades saves from [param from_version] to [code]from_version + 1[/code].
## The callable should accept a [Dictionary] and return the migrated [Dictionary].
func register_migration(from_version: int, migration: Callable) -> void:
	_migrations[from_version] = migration


## Save the game and write it to user://saves directory.
## [param slot_name]: optional name for the save slot (e.g. "quicksave", "slot_1").
## If empty, falls back to a datetime string.
func save(slot_name: String = ""):
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
		var old_data:Dictionary = _deserialize(FileAccess.open(old_file.unwrap(), FileAccess.READ).get_as_text()) # deserialize old data
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
	# Create savegame file
	var file = FileAccess.open("user://saves/%s" % file_name, FileAccess.WRITE)
	file.store_string(save_text)
	# I think these two are redundant but I wanna be safe
	file.flush()
	file.close()
	save_complete.emit()


## Load the most recent savegame, if applicable.
func load_most_recent():
	var most_recent = _get_most_recent_savegame()
	# only load most recent if there are some
	if most_recent.some():
		load_game(most_recent.unwrap())


## Load a game from a filepath.
func load_game(path:String):
	var file = FileAccess.open(path, FileAccess.READ) # open file
	var data_blob:String = file.get_as_text() # read file
	var save_data:Dictionary = _deserialize(data_blob) # parse data

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

	# Reset to default state if it doesn't have an entry in the save data
	for e in SKEntityManager.instance.entities:
		if not save_data["entity_data"].has(e):
			SKEntityManager.instance.entities[e].reset_data()
	# load entity data - loop through all data, get entity (spawning it if it isn't there), call load
	for data in save_data["entity_data"]:
		SKEntityManager.instance.get_entity(data).load_data(save_data["entity_data"][data])

	# load game info data
	for si in get_tree().get_nodes_in_group("savegame_gameinfo"):
		if save_data["game_info"].has(si.name):
			si.load_data(save_data["game_info"][si.name])
		else:
			si.reset_data()

	# load others data
	for so in get_tree().get_nodes_in_group("savegame_other"):
		if save_data["other_data"].has(so.name):
			so.load_data(save_data["other_data"][so.name])
		else:
			so.reset_data()


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
	var deserialized_data:Dictionary = _deserialize(FileAccess.open(most_recent.unwrap(), FileAccess.READ).get_as_text())
	if deserialized_data["entity_data"].has(ref_id):
		# if the data has it, return the blob
		return Option.from(deserialized_data["entity_data"][ref_id])
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
