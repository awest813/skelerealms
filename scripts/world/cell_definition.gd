class_name CellDefinition
extends Resource
## One streaming cell of an exterior worldspace: a grid square whose scene
## loads and unloads around the player. Interiors are NOT streamed — they
## stay door-loaded through WorldLoader. Author cell content around the
## cell center; the adapter places it at center automatically.


## Unique ID within the worldspace, e.g. &"tundra_0_1".
@export var id: StringName
## Scene instanced when this cell mounts.
@export var scene_path: String
## Grid position. With cell size S, this cell covers
## [gx*S, (gx+1)*S) by [gy*S, (gy+1)*S) on the XZ plane.
@export var grid_position: Vector2i
## Interiors never stream (always loaded through doors instead).
@export var interior: bool = false
