class_name SKChunk
extends RefCounted
## Represents a single chunk in the world grid.
##
## Holds chunk state including coordinates, loaded data, and lifecycle flags.
## Used by [SKChunkManager] to track chunk status through load/mount cycles.


## Unique string key derived from grid coordinates (e.g. "3,-2").
var key: String
## Grid coordinates of this chunk.
var coords: Vector2i
## Arbitrary chunk payload set by the [SKChunkSource] on load.
var data: Variant = null
## Whether data has been successfully loaded.
var is_loaded: bool = false
## Whether a load is currently in progress.
var is_loading: bool = false
## Whether the chunk has been mounted (made visible/active in the scene).
var is_mounted: bool = false
## Timestamp (msec) of the last time this chunk was touched by the manager.
var last_touched: int = 0
## Last load error, if any. Cleared on successful load.
var error: Variant = null


func _init(p_coords: Vector2i) -> void:
	coords = p_coords
	key = SKChunkUtils.to_chunk_key(p_coords)
	last_touched = Time.get_ticks_msec()
