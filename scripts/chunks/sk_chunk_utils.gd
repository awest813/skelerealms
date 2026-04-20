class_name SKChunkUtils
extends RefCounted
## Static utility functions for chunk coordinate math.
##
## Provides conversions between world positions, chunk grid coordinates,
## and string keys used by [SKChunkManager].


## Converts grid coordinates to a string key (e.g. Vector2i(3, -2) → "3,-2").
static func to_chunk_key(coords: Vector2i) -> String:
	return "%d,%d" % [coords.x, coords.y]


## Converts a string key back to grid coordinates.
static func from_chunk_key(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(parts[0].to_int(), parts[1].to_int())


## Converts a world-space position to chunk grid coordinates.
static func world_to_chunk_coords(world_pos: Vector3, chunk_size: float) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / chunk_size),
		floori(world_pos.z / chunk_size)
	)


## Returns all grid coordinates in a square of the given radius around center.
static func square_coords_around(center: Vector2i, radius: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			coords.push_back(Vector2i(x, y))
	return coords


## Sorts coordinates by Manhattan distance from center (closest first).
static func sort_coords_by_distance(coords: Array[Vector2i], center: Vector2i) -> Array[Vector2i]:
	var result := coords.duplicate()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x - center.x) + absi(a.y - center.y)
		var db := absi(b.x - center.x) + absi(b.y - center.y)
		return da < db
	)
	return result
