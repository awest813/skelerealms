class_name SKChunkAdapter
extends RefCounted
## Abstract base class for mounting and unmounting chunks in the scene.
##
## Subclass this and override [method mount] and [method unmount] to
## handle visual representation — instantiating scene nodes, terrain meshes,
## or any engine-specific rendering for a loaded chunk.


## Called when a chunk enters the active radius and its data is loaded.
## Use this to add nodes to the scene tree, create meshes, etc.
func mount(_chunk: SKChunk) -> void:
	push_error("SKChunkAdapter.mount() not implemented.")


## Called when a chunk leaves the active radius.
## Use this to remove scene nodes and free visual resources.
func unmount(_chunk: SKChunk) -> void:
	push_error("SKChunkAdapter.unmount() not implemented.")
