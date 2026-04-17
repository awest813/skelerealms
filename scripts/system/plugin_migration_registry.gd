@tool
class_name PluginMigrationRegistry
extends RefCounted
## One-shot migrations for project-level state between plugin versions.
##
## This complements [SaveSystem]'s per-save migrations. [SaveSystem] handles
## migrating a player's save file. [PluginMigrationRegistry] handles migrating
## the project itself — renamed [code]ProjectSettings[/code] keys, removed
## defaults, and resource-schema changes that the plugin should apply once when
## the consumer upgrades the addon in-place.
##
## Usage: register a migration that upgrades FROM a given version string TO the
## next. Migrations are executed in order starting from the last-applied
## version (stored under [code]skelerealms/__installed_version[/code]) until
## [member current_version] is reached.
##
## Migrations are idempotent on re-run because the last-applied version is
## persisted after every successful step.
##
## [codeblock]
## var registry := PluginMigrationRegistry.new("beta 0.8")
## registry.register("beta 0.6", func():
##     ProjectSettings.set_setting("skelerealms/new_key", true))
## registry.register("beta 0.7", func():
##     ProjectSettings.set_setting("skelerealms/mods_path", "res://mods"))
## registry.run()
## [/codeblock]


const VERSION_KEY := "skelerealms/__installed_version"

## The version we're migrating TO. Usually the current plugin version.
var current_version: String

## Ordered list of (from_version, callable) pairs.
var _migrations: Array = []


func _init(target_version: String) -> void:
	current_version = target_version


## Register a migration that runs when the installed version equals [param from_version].
## The callable takes no arguments and returns nothing.
func register(from_version: String, migration: Callable) -> void:
	_migrations.append({"from": from_version, "call": migration})


## Run every pending migration in order.
## Returns true if at least one migration ran, false if the installed version
## already matches [member current_version].
func run() -> bool:
	var installed: String = ProjectSettings.get_setting(VERSION_KEY, "")
	if installed == current_version:
		return false

	if installed.is_empty():
		# First install — stamp the current version and skip migrations.
		_stamp_and_persist(current_version)
		return false

	var ran_any := false
	var current_cursor := installed
	for entry: Dictionary in _migrations:
		if entry["from"] != current_cursor:
			continue
		var fn: Callable = entry["call"]
		if fn.is_valid():
			fn.call()
			ran_any = true
		# After a migration runs, the installed version advances one step.
		# The NEXT migration's from_version must match, or the chain ends.
		current_cursor = _next_version_after(current_cursor)
		ProjectSettings.set_setting(VERSION_KEY, current_cursor)

	# Final stamp and single persist to project.godot.
	_stamp_and_persist(current_version)
	return ran_any


## Returns the from-version of the next registered migration after [param from].
## If there is no further registered step, returns [member current_version].
func _next_version_after(from: String) -> String:
	var found_current := false
	for entry: Dictionary in _migrations:
		if found_current:
			return entry["from"]
		if entry["from"] == from:
			found_current = true
	return current_version


func _stamp_and_persist(v: String) -> void:
	ProjectSettings.set_setting(VERSION_KEY, v)
	# Persist to project.godot so the upgrade sticks across editor restarts.
	ProjectSettings.save()
