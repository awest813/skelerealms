class_name WorldspaceDefinition
extends Resource
## An exterior worldspace: a grid of streaming [CellDefinition] cells plus
## the tuning that governs its streaming radius and actor distances.
## Interiors are separate worlds reached through doors, not cells here.


## Unique ID, e.g. &"tundra_exterior".
@export var id: StringName
## Cell edge length in metres. All cells in a worldspace share it.
@export var cell_size: float = 256.0
## The cells that make up this worldspace.
@export var cells: Array[CellDefinition] = []
## Cell the player arrives in (spawn, fast travel, debugging).
@export var entry_cell: StringName
## Radius in cells kept mounted around the player.
@export var active_radius: int = 1
## Radius in cells preloaded around the player (>= active_radius).
@export var preload_radius: int = 2
## Actor fade distance applied while this worldspace is current.
@export var actor_fade_distance: float = 100.0


## Cell at grid coordinates, or null (wilderness or unmapped).
func get_cell(coords: Vector2i) -> CellDefinition:
	for cell: CellDefinition in cells:
		if cell.grid_position == coords:
			return cell
	return null


## World-space center of a grid cell (content authoring origin).
func cell_center(coords: Vector2i) -> Vector3:
	return Vector3((coords.x + 0.5) * cell_size, 0.0, (coords.y + 0.5) * cell_size)


## Structural sanity. Returns issue dicts {type, detail}. Empty means sound.
func validate() -> Array:
	var issues: Array = []
	if cell_size <= 0.0:
		issues.append({"type": "bad_cell_size", "detail": "Worldspace '%s' needs cell_size above zero." % id})
	var by_id := {}
	var by_grid := {}
	for cell: CellDefinition in cells:
		if by_id.has(cell.id):
			issues.append({"type": "duplicate_cell", "detail": "Duplicate cell id '%s'." % cell.id})
		by_id[cell.id] = true
		var key := "%d,%d" % [cell.grid_position.x, cell.grid_position.y]
		if by_grid.has(key):
			issues.append({"type": "overlapping_cells", "detail": "Cells share grid position %s." % key})
		by_grid[key] = true
		if cell.scene_path.is_empty():
			issues.append({"type": "missing_scene", "detail": "Cell '%s' names no scene." % cell.id})
	if not entry_cell.is_empty() and not by_id.has(entry_cell):
		issues.append({"type": "bad_entry_cell", "detail": "Entry cell '%s' does not exist." % entry_cell})
	if active_radius < 0 or preload_radius < active_radius:
		issues.append({"type": "bad_radii", "detail": "Need 0 <= active_radius <= preload_radius."})
	return issues
