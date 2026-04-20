class_name SKChunkSource
extends RefCounted
## Abstract base class for loading chunk data.
##
## Subclass this and override [method load_chunk] to provide chunk data
## from any source (procedural generation, disk, network, etc.).
## Optionally override [method unload_chunk] to clean up resources.


## Loads data for the chunk at the given grid coordinates.
## [param coords] Grid position of the chunk to load.
## [param cancelled] A [RefCounted] flag object — check [code]cancelled.flag[/code]
## to detect early cancellation during long loads.
## Returns the loaded data (any Variant).
func load_chunk(_coords: Vector2i, _cancelled: SKCancelToken = null) -> Variant:
	push_error("SKChunkSource.load_chunk() not implemented.")
	return null


## Called when a chunk is being fully unloaded from memory.
## Override to release external resources tied to this chunk.
func unload_chunk(_chunk: SKChunk) -> void:
	pass
