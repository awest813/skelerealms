@tool
class_name Network
extends Resource
## This is the network graph itself, containing nodes and edges.


## The points in this network.
@export var points:Array[NetworkPoint] = []
## The edges in this network.
@export var edges:Array[NetworkEdge] = []
## This dictionary contains an array (value) of edges that involve a point (key).
@export var edge_map:Dictionary[NetworkPoint, Array[NetworkEdge]] = {}
## The portals this network has.
@export var portals:Array[NetworkPortal] = []
## Connections between worlds
@export var portal_edges:Array[PortalEdge] = []

signal redraw


## Add a point to this network.
func add_point(pt:Vector3, portal:bool = false) -> NetworkPoint:
	# Create edge
	var new_point = NetworkPortal.new(pt) if portal else NetworkPoint.new(pt)
	# Initialize map entry
	edge_map[new_point] = []
	# Add to points
	points.append(new_point)
	if portal:
		portals.append(new_point)

	redraw.emit()
	return new_point


## Remove a point from the network and all associated connections. See [method dissolve_point].
func remove_point(pt:NetworkPoint) -> void:
	points.erase(pt)
	if pt is NetworkPortal:
		portals.erase(pt)
	
	var edges = edge_map[pt].duplicate()
	# Remove all edges involving this node
	for edge in edges:
		remove_edge(edge)
	# Erase all entries in edge map.
	edge_map.erase(pt)
	edges.clear()

	redraw.emit()


## Dissolve a point in the network, connecting all nodes it was connected to together. See [method remove_point].
func dissolve_point(pt:NetworkPoint) -> void:
	# Just delete the node if there is 0 or 1 connections, since there's nothing to dissolve
	if edge_map[pt].size() <= 1:
		remove_point(pt)
		return
	# The nodes this point was connected to and their costs, so we can connect them to each other.
	var to_connect = []
	var edge_costs:Dictionary = {} # NetworkPoint -> cost from pt to that point
	# Loop through edges and get the other point and cost.
	for edge in edge_map[pt]:
		var other = edge.point_a if edge.point_b == pt else edge.point_b
		to_connect.append(other)
		edge_costs[other] = edge.cost
	# Remove the point and associated connections
	remove_point(pt)
	# For unique pairs of to connect, connect edge with combined cost
	for pair in _find_unique_pairs(to_connect):
		var cost_a:float = edge_costs.get(pair[0], 1.0)
		var cost_b:float = edge_costs.get(pair[1], 1.0)
		add_edge(pair[0], pair[1], cost_a + cost_b)
	
	redraw.emit()


## Merge two points together and reconnect all connections.
func merge_points(a:NetworkPoint, b:NetworkPoint) -> NetworkPoint:
	# Create a new node from the average of 2 points
	var new_node = add_point((a.position + b.position)/2)
	# Track other edges to reconnect to the new node, with their costs
	var to_connect:Array[Dictionary] = []

	# Add other side of edges for a
	for edge in edge_map[a]:
		var other = edge.point_a if edge.point_b == a else edge.point_b
		# Skip connections to other node we are merging
		if other == b:
			continue
		to_connect.append({"point": other, "cost": edge.cost})
	# Add other side of edges for b
	for edge in edge_map[b]:
		var other = edge.point_a if edge.point_b == b else edge.point_b
		# Skip connections to other node we are merging
		if other == a:
			continue
		to_connect.append({"point": other, "cost": edge.cost})
	
	remove_point(a)
	remove_point(b)

	# Reconnect everything using distance-based cost from new node
	for entry in to_connect:
		var dist_cost:float = new_node.position.distance_to(entry["point"].position)
		add_edge(new_node, entry["point"], dist_cost)

	redraw.emit()
	return new_node


## Add an edge to this network.
func add_edge(a:NetworkPoint, b:NetworkPoint, cost:float = 1, bidirectional:bool = true) -> NetworkEdge:
	# return if it's bidirectional and an edge already exists connecting these nodes
	if bidirectional and find_edge(a, b):
		return null
	# Create edge
	var edge = NetworkEdge.new(a, b, cost, bidirectional)
	# Add this edge to the edge map

	# Add edge maps if they dont exist
	if not edge_map.has(a):
		edge_map[a] = []

	edge_map[a].append(edge)

	if not edge_map.has(b):
		edge_map[b] = []

	edge_map[b].append(edge)
	# Add to edges
	edges.append(edge)

	redraw.emit()
	return edge


## Remove an edge from the network.
func remove_edge(edge:NetworkEdge) -> void:
	# Erase edge map entry on both sides
	edge_map[edge.point_a].erase(edge)
	edge_map[edge.point_b].erase(edge)
	# Erase from edge database
	edges.erase(edge)

	redraw.emit()


## Find an edge that contains both points. Returns null if none found.
func find_edge(a:NetworkPoint, b:NetworkPoint) -> NetworkEdge:
	for edge in edge_map[a]:
		if edge.point_a == a and edge.point_b == b:
			return edge
		if edge.point_a == b and edge.point_b == a:
			return edge

	return null


# Subdivide an edge into a node in the middle of two points, with two edges connecting all 3 nodes.
func subdivide_edge(edge:NetworkEdge) -> NetworkPoint:
	# Add a new node in between them
	var new_node = add_point((edge.point_a.position + edge.point_b.position)/2)

	# Get other connections and original cost
	var pt_a = edge.point_a
	var pt_b = edge.point_b
	var half_cost:float = edge.cost / 2.0
	
	remove_edge(edge) # remove the subdivided edge

	# Reconnect with half the original cost each
	add_edge(new_node, pt_a, half_cost)
	add_edge(new_node, pt_b, half_cost)

	redraw.emit()
	return new_node


## Find all unique pairs of an array
func _find_unique_pairs(arr:Array):
	# this sucks lol
	var pairs = {}

	for i in range(arr.size() - 1):
		for j in range(i + 1, arr.size()):
			var pair = [arr[i], arr[j]]
			pair.sort_custom(func(a:NetworkPoint, b:NetworkPoint): return a.position.distance_squared_to(Vector3()) > b.position.distance_squared_to(Vector3())) # make sure [a, b] and [b, a] is the same thing
			pairs[pair] = 1
	
	return pairs.keys()
