extends Node
## Autoload singleton that discovers and loads [ModManifest] resources.
##
## On game-start the loader scans the directory configured by
## [code]skelerealms/mods_path[/code] (default [code]res://mods[/code])
## for [code].tres[/code] / [code].res[/code] files that are [ModManifest]
## resources, then calls [method load_mod] for each one found.
##
## Mods can also be loaded programmatically at any time by calling
## [method load_mod] directly with a [ModManifest] resource.


## IDs of all successfully loaded mods.
var loaded_mods: Array[StringName] = []

## Emitted after a mod has been fully applied.
signal mod_loaded(mod_id: StringName, mod_name: String)


func _ready() -> void:
	GameInfo.game_started.connect(_load_all_mods)


## Scan [code]skelerealms/mods_path[/code] and load every manifest found.
func _load_all_mods() -> void:
	var mods_path: String = ProjectSettings.get_setting(
		"skelerealms/mods_path", "res://mods"
	)
	_scan_directory(mods_path)


## Recursively scan [param path] for mod manifest resources.
func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := "%s/%s" % [path, file_name]
		if '.remap' in file_name:
			file_name = file_name.trim_suffix('.remap')
			full_path = "%s/%s" % [path, file_name]
		if dir.current_is_dir():
			_scan_directory(full_path)
		else:
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var res := load(full_path)
				if res is ModManifest:
					load_mod(res as ModManifest)
		file_name = dir.get_next()
	dir.list_dir_end()


## Apply all content declared in [param manifest] to the running game.
##
## This is safe to call more than once; manifests with a [member ModManifest.mod_id]
## that has already been loaded are silently skipped.
func load_mod(manifest: ModManifest) -> void:
	if manifest.mod_id == &"":
		push_warning("ModLoader: skipping manifest with empty mod_id ('%s')" % manifest.mod_name)
		return

	if loaded_mods.has(manifest.mod_id):
		push_warning("ModLoader: mod '%s' already loaded — skipping" % manifest.mod_id)
		return

	# Register covens
	for coven: Coven in manifest.covens:
		CovenSystem.add_coven(coven)

	# Apply coven opinion overrides
	for override: CovenOpinionOverride in manifest.coven_opinion_overrides:
		CovenSystem.change_opinion(override.coven_id, override.target_coven_id, override.delta)

	# Register quests
	for quest: QuestDefinition in manifest.quests:
		QuestSystem.register_quest(quest)

	# Register dialogues
	for dialogue: DialogueDefinition in manifest.dialogues:
		DialogueSystem.register_dialogue(dialogue)

	loaded_mods.append(manifest.mod_id)
	mod_loaded.emit(manifest.mod_id, manifest.mod_name)
