class_name SKMapManager
extends Node
## Autoload-compatible manager for named world-space map markers.
##
## Tracks points of interest (doors, quest objectives, custom pins) and
## emits signals when they change so compass widgets and map UIs can refresh.
##
## Register as an autoload in your project or instantiate manually.
##
## ## Marker Categories
## - **door** — added automatically when a [Door] node calls [method register_door]
## - **quest** — managed by your quest integration code via [method add_marker]
## - **poi** — hand-placed points of interest
## - **custom** — anything else
##
## ## Basic usage
## ```gdscript
## SKMapManager.add_marker(&"cave_entrance", Vector3(10, 0, -50), &"poi",
##     "Dark Cave", GameInfo.world)
## SKMapManager.remove_marker(&"cave_entrance")
## ```


## Data for a single map marker.
class MapMarker:
	## Unique identifier.
	var id: StringName
	## World-space position of the marker.
	var position: Vector3
	## Category tag (e.g. &"door", &"quest", &"poi").
	var category: StringName
	## Human-readable label shown in the UI.
	var label: String
	## The world this marker belongs to.
	var world: StringName
	## Optional icon identifier for the UI layer.
	var icon: StringName

	func _init(
		p_id: StringName,
		p_position: Vector3,
		p_category: StringName,
		p_label: String,
		p_world: StringName,
		p_icon: StringName = &"",
	) -> void:
		id = p_id
		position = p_position
		category = p_category
		label = p_label
		world = p_world
		icon = p_icon


## All registered markers (id → MapMarker).
var _markers: Dictionary[StringName, MapMarker] = {}

## Emitted when a marker is added or updated.
signal marker_added(marker: MapMarker)
## Emitted when a marker is removed.
signal marker_removed(id: StringName)
## Emitted when all markers have been cleared.
signal markers_cleared


## Add or update a marker.
func add_marker(
	id: StringName,
	position: Vector3,
	category: StringName,
	label: String,
	world: StringName,
	icon: StringName = &"",
) -> void:
	var m := MapMarker.new(id, position, category, label, world, icon)
	_markers[id] = m
	marker_added.emit(m)


## Remove a marker by id. Does nothing if not found.
func remove_marker(id: StringName) -> void:
	if not _markers.has(id):
		return
	_markers.erase(id)
	marker_removed.emit(id)


## Remove all markers matching a category.
func remove_markers_by_category(category: StringName) -> void:
	var to_remove: Array[StringName] = []
	for id: StringName in _markers:
		if _markers[id].category == category:
			to_remove.append(id)
	for id in to_remove:
		remove_marker(id)


## Remove all markers for a specific world.
func remove_markers_for_world(world: StringName) -> void:
	var to_remove: Array[StringName] = []
	for id: StringName in _markers:
		if _markers[id].world == world:
			to_remove.append(id)
	for id in to_remove:
		remove_marker(id)


## Clear all markers.
func clear_markers() -> void:
	_markers.clear()
	markers_cleared.emit()


## Return all markers for the current world.
func get_markers_for_current_world() -> Array[MapMarker]:
	return get_markers_for_world(GameInfo.world)


## Return all markers for a given world.
func get_markers_for_world(world: StringName) -> Array[MapMarker]:
	var out: Array[MapMarker] = []
	for m: MapMarker in _markers.values():
		if m.world == world:
			out.append(m)
	return out


## Return all markers of a given category (across all worlds).
func get_markers_by_category(category: StringName) -> Array[MapMarker]:
	var out: Array[MapMarker] = []
	for m: MapMarker in _markers.values():
		if m.category == category:
			out.append(m)
	return out


## Return a single marker by id, or null if not found.
func get_marker(id: StringName) -> MapMarker:
	return _markers.get(id, null)


## Update the position of an existing marker (e.g. a moving objective).
func update_position(id: StringName, position: Vector3) -> void:
	if not _markers.has(id):
		return
	_markers[id].position = position
	marker_added.emit(_markers[id])


## Convenience: register a Door node as a marker.
## Called automatically by [Door] nodes in [method Door._ready] if the manager is present.
func register_door(door_id: StringName, position: Vector3, label: String, world: StringName) -> void:
	add_marker(door_id, position, &"door", label, world, &"door")
