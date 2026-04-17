class_name NavNode
extends RefCounted
## A single navigation node in the granular navigation system.
## Uses RefCounted instead of Node3D for memory efficiency — no scene tree
## overhead per navigation point.


## The connections/edges this node has to other nodes. [br]
## The structure of this dictionary is: [br]
## [Codeblock]
## connected_node:NavNode, cost:float
## [/Codeblock]
var connections: Dictionary = {}
var dimension:int
var world:String
var left_child:NavNode
var right_child:NavNode
## Explicit parent reference (replaces Node.get_parent() from the old Node3D hierarchy).
var parent_node:NavNode
## Position in the world (replaces Node3D.position).
var position:Vector3
## Human-readable identifier (replaces Node.name).
var node_name:String
var nav_point:NavPoint:
	get:
		return NavPoint.new(world, position)


func add_nav_node(pos:Vector3) -> NavNode:
	# figure out if the dimension is less or greater than ourselves.
	# equal is treated as greater.
	var is_left:bool = pos[dimension] < position[dimension]
	if is_left:
		# if our left child exists, tell it to add the node.
		if left_child:
			return left_child.add_nav_node(pos)
		else:
			var new_n = NavNode.new()
			new_n.position = pos # set position
			new_n.dimension = (dimension + 1) % 3 # set dimension and wrap to 3 dimensions
			new_n.world = world
			new_n.node_name = NavMaster.format_point_name(pos, world)
			new_n.parent_node = self
			left_child = new_n
			return new_n
	else:
		if right_child:
			return right_child.add_nav_node(pos)
		else:
			var new_n = NavNode.new()
			new_n.position = pos
			new_n.dimension = (dimension + 1) % 3
			new_n.world = world
			new_n.node_name = NavMaster.format_point_name(pos, world)
			new_n.parent_node = self
			right_child = new_n
			return new_n


func get_closest_point(pos:Vector3) -> NavNode:
	var split_dim:int = dimension
	var is_left:bool = pos[split_dim] < position[split_dim]
	
	if is_left:
		if left_child: # if we have a left child, call it instead, 
			return left_child.get_closest_point(pos)
		else: # else it's this
			return self
	else:
		if right_child:
			return right_child.get_closest_point(pos)
		else:
			return self


func connect_nodes(other:NavNode, cost:float) -> void:
	connections[other] = cost
