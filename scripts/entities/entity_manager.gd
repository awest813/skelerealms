class_name SKEntityManager
extends Node
## Manages entities in the game.
## Use [method add_entity] to spawn, [method get_entity] to fetch,
## [method remove_entity] to delete, and let [SaveSystem] handle persistence.

## The instance of the entity manager.
static var instance: SKEntityManager

var entities: Dictionary = {}
var disk_assets: Dictionary = {}
var regex: RegEx


func _init() -> void:
	instance = self


func _ready():
	regex = RegEx.new()
	regex.compile("([^\\/\n\\r]+)\\.t?scn")
	_cache_entities(ProjectSettings.get_setting("skelerealms/entities_path"))
	SkeleRealmsGlobal.entity_manager_loaded.emit()


## Gets an entity in the game. [br]
## This system follows a cascading pattern, and attempts to get entities by following the following steps. It will execute each step, and if it fails to get an entity, it will move onto the next one. [br]
## 1. Tries to get the entity from its internal hash table of entities. [br]
## 2. Checks the save file for persisted data and loads from disk. [br]
## 3. Attempts to load the entity from disk as a fresh instance. [br]
## Failing all of these, it will return [code]null[/code].
func get_entity(id: StringName) -> SKEntity:
	assert(id != &"", "get_entity called with empty id.")
	# stage 1: attempt find in cache
	if entities.has(id):
		(entities[id] as SKEntity).reset_stale_timer()
		return entities[id]
	# stage 2: Check in save file
	var potential_data = SaveSystem.entity_in_save(id)
	if potential_data.some():
		if not disk_assets.has(id):
			push_error("Entity '%s' found in save but has no disk asset." % id)
			return null
		var e:SKEntity = add_entity(ResourceLoader.load(disk_assets[id]))
		e.load_data(potential_data.unwrap())
		e.reset_stale_timer()
		return e
	# stage 3: check on disk
	if disk_assets.has(id):
		var e:SKEntity = add_entity(ResourceLoader.load(disk_assets[id]))
		e.generate() # generate, because the entity has never been seen before
		e.reset_stale_timer()
		return e 

	push_warning("Entity '%s' not found in cache, save, or disk." % id)
	return null


## Returns the disk asset path for an entity, or an empty string if not found.
func get_disk_data_for_entity(id: StringName) -> String:
	if disk_assets.has(id):
		return disk_assets[id]
	return ""


func _cache_entities(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_cache_entities("%s/%s" % [path, file_name])
			else:
				if ".remap" in file_name:
					file_name = file_name.trim_suffix(".remap")
				var result = regex.search(file_name)
				if result:
					disk_assets[result.get_string(1)] = "%s/%s" % [path, file_name]
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("SKEntityManager: Failed to open entities path '%s'." % path)


func _add_entity_raw(e: SKEntity) -> SKEntity:
	entities[e.name] = e
	add_child(e)
	return e


## ONLY call after save!!!
func _cleanup_stale_entities():
	for c in get_children():
		if (
			(c as SKEntity).stale_timer
			>= ProjectSettings.get_setting("skelerealms/entity_cleanup_timer")
		):
			remove_entity(c.name)


## Remove entity from the game.
func remove_entity(rid: StringName) -> void:
	if not entities.has(rid):
		push_warning("remove_entity: Entity '%s' not found." % rid)
		return
	entities[rid].queue_free()
	entities.erase(rid)


## Instantiate and register a new entity from a [PackedScene] template.
## For non-unique entities a random ID is generated automatically.
func add_entity(scene: PackedScene) -> SKEntity:
	if scene == null:
		push_error("add_entity: scene is null.")
		return null
	var e: SKEntity = scene.instantiate()
	if not e:
		push_error("add_entity: Scene at path '%s' did not produce a valid entity." % scene.resource_path)
		return null
	
	if not e.unique:
		var valid: bool = false 
		var new_id: String = ""
		while not valid:
			new_id = SKIDGenerator.generate_id()
			valid = not entities.has(new_id)
			e.generate.call_deferred()
		e.name = new_id
	return _add_entity_raw(e)
