class_name NavWorld
extends RefCounted
## A world of the granular navigation system.
## Uses RefCounted instead of Node for memory efficiency — no scene tree
## overhead per world.


const dimension = 0

var world:String
## Root of the KD-tree for this world. Null when empty.
var root:NavNode


func add_point(pos:Vector3) -> NavNode:
	# if we have no root, create one
	if not root:
		var new_n = NavNode.new()
		new_n.position = pos # set position
		new_n.dimension = 0
		new_n.world = world
		new_n.node_name = NavMaster.format_point_name(pos, world)
		root = new_n
		return new_n
	#else, tell the root to add one
	return root.add_nav_node(pos)


## Gets closest point in world to a position.
func get_closest_point(pos:Vector3) -> NavNode:
	if not root:
		return null
	else:
		return root.get_closest_point(pos)
