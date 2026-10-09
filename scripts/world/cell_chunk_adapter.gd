class_name CellChunkAdapter
extends SKChunkAdapter
## Mounts streamed cells: instantiates the payload scene as a child of the
## mount root, positioned at the cell center (author content around it).
## Empty payloads (wilderness/interiors) mount and unmount as no-ops.


## Scene-tree parent for mounted cells. Set by the owner (usually itself).
var mount_root: Node3D
## Cell edge length, mirroring the worldspace. Mounts position content at
## cell centers derived from it.
var cell_size: float = 256.0
## Mounted scene roots by chunk key.
var mounted: Dictionary = {}


func _init(parent: Node3D = null, size: float = 256.0) -> void:
	mount_root = parent
	cell_size = size


func mount(chunk: SKChunk) -> void:
	if mount_root == null or not is_instance_valid(mount_root):
		return
	unmount(chunk)
	var scene: PackedScene = (chunk.data as Dictionary).get("scene") if chunk.data is Dictionary else null
	if scene == null:
		return
	var node := scene.instantiate()
	var coords: Vector2i = (chunk.data as Dictionary).get("coords", chunk.coords)
	mount_root.add_child(node)
	if node is Node3D:
		(node as Node3D).position = Vector3((coords.x + 0.5) * cell_size, 0.0, (coords.y + 0.5) * cell_size)
	mounted[chunk.key] = node


func unmount(chunk: SKChunk) -> void:
	if not mounted.has(chunk.key):
		return
	var node: Node = mounted[chunk.key]
	mounted.erase(chunk.key)
	if node and is_instance_valid(node):
		node.queue_free()
