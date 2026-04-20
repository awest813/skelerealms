class_name ExampleChunkSource
extends SKChunkSource
## Example [SKChunkSource] that generates deterministic procedural data.
##
## Produces a dictionary with [code]seed[/code], [code]tiles[/code] (16×16 grid),
## and [code]entities[/code] array for each chunk. Useful for testing the
## [SKChunkManager] pipeline without real assets.


func load_chunk(coords: Vector2i, cancelled: SKCancelToken = null) -> Variant:
	# Simulate a short async delay (30 ms).
	await Engine.get_main_loop().create_timer(0.03).timeout
	if cancelled and cancelled.is_cancelled:
		return null

	var seed_val := _hash_coords(coords.x, coords.y)

	var tiles: Array[Array] = []
	for y in 16:
		var row: Array[int] = []
		for x in 16:
			row.push_back(absi((seed_val + x * 13 + y * 7) % 4))
		tiles.push_back(row)

	var entities: Array[Dictionary] = [
		{
			"id": "crate-%d-%d" % [coords.x, coords.y],
			"x": 4,
			"y": 6,
			"type": "crate",
		}
	]

	return {
		"seed": seed_val,
		"tiles": tiles,
		"entities": entities,
	}


func unload_chunk(chunk: SKChunk) -> void:
	push_warning("ExampleChunkSource: Cleaned chunk %s" % chunk.key)


static func _hash_coords(x: int, y: int) -> int:
	return (x * 73856093) ^ (y * 19349663)
