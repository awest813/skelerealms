class_name ExampleChunkAdapter
extends SKChunkAdapter
## Example [SKChunkAdapter] that logs mount/unmount operations.
##
## Keeps a simple dictionary of "rendered handles" to illustrate the
## adapter lifecycle. Replace with real scene-tree operations in production.


## Tracks mounted chunk handles (key → render handle string).
var _mounted: Dictionary = {}


func mount(chunk: SKChunk) -> void:
	if not chunk.data:
		return
	var render_handle := "rendered:%s" % chunk.key
	_mounted[chunk.key] = render_handle
	push_warning("ExampleChunkAdapter: Mounted chunk %s" % chunk.key)


func unmount(chunk: SKChunk) -> void:
	_mounted.erase(chunk.key)
	push_warning("ExampleChunkAdapter: Unmounted chunk %s" % chunk.key)
