class_name NavMaster
extends Node
## This is the manager for the [b]Granular Navigation System[/b].
## This is a singleton-like object that will find a path through the game's worlds. [br]
## [b]Granular navigation System[/b][br]
## This system is essentially a low-resolution navmesh that allows actors outside of the scene to continue walking around the worlds, so they will be where the player expects them to be.[br]
## The granular navigation system is split up into "worlds", corresponding to the "worlds" of the game. These are roughly analagous to "cells" in Bethesda games.
## Each [NavWorld] contains [NavNode]s as children that are laid out to match the physical space of a world.
## When NPCs are offscreen, instead of using a navmesh, they will attempt to go to their destination by following these nodes.
## This is done to improve performance. However, be sure not to have [i]too[/i] many entities using this at once, otherwise performance may suffer. 
## See project setting [code]skelerelams/granular_navigation_sim_distance[/code] to adjust how far away the actors have to be before they stop using this system and just stay idle.


static var instance:NavMaster
## Dictionary of references to the roots of KD trees.
var worlds:Dictionary = {}
## Portal edges that failed to connect because the destination world was not yet loaded.
## Each entry is a PortalEdge resource.
var _pending_portal_edges:Array = []
## Lookup table mapping formatted point name -> NavNode for connection persistence.
var _node_lookup:Dictionary = {}


func _ready() -> void:
	GameInfo.game_started.connect(load_all_networks.bind())
	instance = self
	add_to_group("savegame_other")


func calculate_path(start:NavPoint, end:NavPoint) -> Array[NavPoint]:
	var start_node:NavNode = nearest_point(start)
	var end_node:NavNode = nearest_point(end)
	
	# Binary min-heap for the open set, keyed by f_score.
	# Each element is [f_value, NavNode].
	var heap:Array = []
	var in_open:Dictionary = {} # NavNode -> true
	var closed_set:Dictionary = {} # NavNode -> true (replaces closed_list Array.has())
	
	var g_score:Dictionary = {start_node:0}
	var f_score:Dictionary = {start_node:_heuristic(start_node, end_node)}
	var came_from:Dictionary = {}
	
	_heap_push(heap, f_score[start_node], start_node)
	in_open[start_node] = true
	
	while not heap.is_empty():
		var current:NavNode = _heap_pop(heap)[1]
		in_open.erase(current)
		
		for c in current.connections:
			# if connection already closed, skip
			if closed_set.has(c):
				continue
			
			var tentative_g:float = g_score[current] + current.connections[c]
			
			# If we haven't seen this node or found a cheaper path
			if not g_score.has(c) or tentative_g < g_score[c]:
				came_from[c] = current
				g_score[c] = tentative_g
				
				# If connection is the end node, we found a path.
				if c == end_node:
					return _reconstruct_path(came_from, c)
				
				if not f_score.has(c):
					f_score[c] = _heuristic(c, end_node) + tentative_g
				else:
					f_score[c] = _heuristic(c, end_node) + tentative_g
				
				if not in_open.has(c):
					_heap_push(heap, f_score[c], c)
					in_open[c] = true
		
		closed_set[current] = true
	
	return []


## Push an element onto the binary min-heap. Each element is [f_value, NavNode].
static func _heap_push(heap:Array, f:float, node:NavNode) -> void:
	heap.append([f, node])
	# Sift up
	var i:int = heap.size() - 1
	while i > 0:
		var parent_idx:int = (i - 1) / 2
		if heap[i][0] < heap[parent_idx][0]:
			var tmp = heap[i]
			heap[i] = heap[parent_idx]
			heap[parent_idx] = tmp
			i = parent_idx
		else:
			break


## Pop the element with the smallest f_value from the binary min-heap.
static func _heap_pop(heap:Array) -> Array:
	if heap.size() == 1:
		return heap.pop_back()
	var result = heap[0]
	heap[0] = heap.pop_back()
	# Sift down
	var i:int = 0
	var size:int = heap.size()
	while true:
		var smallest:int = i
		var left:int = 2 * i + 1
		var right:int = 2 * i + 2
		if left < size and heap[left][0] < heap[smallest][0]:
			smallest = left
		if right < size and heap[right][0] < heap[smallest][0]:
			smallest = right
		if smallest != i:
			var tmp = heap[i]
			heap[i] = heap[smallest]
			heap[smallest] = tmp
			i = smallest
		else:
			break
	return result


func _reconstruct_path(came_from:Dictionary, current:NavNode) -> Array[NavPoint]:
	# potential optimization: Push back and then reverse?
	var path:Array[NavPoint] = [current.nav_point]
	while current in came_from:
		path.push_front(came_from[current].nav_point)
		current = came_from[current]
	return path


func _heuristic(a: NavNode, end:NavNode) -> float:
	# doing the heuristic in this way turns the AStar into Dijkstra unless the nodes are in the same world.
	# this is because, since the worlds are not really euclidean in relation to eachother, it's impossible to find accurate heuristic distances. So we just don't.
	# if we find this too inaccurate, we could keep track of connections between worlds and calculate out heuristics by measuring from door to door. But that's hard.
	if not a.world == end.world:
		return 1000
	else:
		# use squared as a small optimization
		return a.position.distance_squared_to(end.position)


## Retry any portal connections that failed during initial load because the
## destination world was not yet available. Call after all networks have been
## loaded or when a new world is dynamically added.
func _load():
	if _pending_portal_edges.is_empty():
		return
	var still_pending:Array = []
	for edge in _pending_portal_edges:
		var from_node = _find_node_for_portal(edge.portal_from)
		var to_node = _find_node_for_portal(edge.portal_to)
		if from_node and to_node:
			connect_nodes(from_node, to_node, 0)
		else:
			still_pending.append(edge)
	_pending_portal_edges = still_pending
	if not still_pending.is_empty():
		push_warning("NavMaster: %d portal connections still pending (worlds not loaded)." % still_pending.size())


## Find the NavNode corresponding to a NetworkPortal's position across all worlds.
func _find_node_for_portal(portal: NetworkPortal) -> NavNode:
	var key = portal
	if _node_lookup.has(key):
		return _node_lookup[key]
	# Fallback: search by position across all worlds
	for world_name in worlds:
		var node = nearest_point(NavPoint.new(world_name, portal.position))
		if node and node.position.distance_to(portal.position) < 0.1:
			return node
	return null


## Recursive descent for the nearest point algorithm.
func _walk_down(n:NavNode, goal:NavPoint, current_closest:NavNode) -> NavNode:
	# set current closest to this if the distance to goal is smaller
	if  n.position.distance_squared_to(goal.position) < current_closest.position.distance_squared_to(goal.position):
		current_closest = n
	# if no children, return current closest
	if not n.left_child and not n.right_child:
		return current_closest
	# make binary decision
	var is_left:bool = goal.position[n.dimension] < n.position[n.dimension]
	if is_left and n.left_child:
		return _walk_down(n.left_child, goal, current_closest)
	elif not is_left and n.right_child:
		return _walk_down(n.right_child, goal, current_closest)
	# if there's no child in the selected direction, return current closest
	else:
		return current_closest



## Find the nav node closest to a given point.
func nearest_point(pt:NavPoint) -> NavNode:
	if not worlds.has(pt.world):
		return null
	
	var world_node:NavWorld = worlds[pt.world]
	if not world_node.root:
		return null
	var root = world_node.root
	var current_closest:NavNode = root # root by default
	# walk down initially
	current_closest = _walk_down(root, pt, current_closest) # walk down the tree initially
	#walk back up the tree, searching other branches if necessary
	var walking_node:NavNode = current_closest
	while walking_node.parent_node is NavNode:
		var p = walking_node.parent_node as NavNode
		# Recursively search the other side of the splitting hyperplane if the distance between the query point and the splitting hyperplane is less than the distance between the query point and the closest node found so far
		if abs(p.position[p.dimension] - pt.position[p.dimension]) < walking_node.position.distance_to(current_closest.position):
			if p.left_child == walking_node and p.right_child:
				current_closest = _walk_down(p.right_child, pt, current_closest)
			elif p.right_child == walking_node and p.left_child:
				current_closest = _walk_down(p.left_child, pt, current_closest)
		walking_node = p
	
	return current_closest


func construct_tree(points:Array[NavPoint]):
	# this constructs a KD tree.
	
	# 1) sort into worlds
	var sorted_points:Dictionary = {}
	for n in points:
		# if point world not already created:
		if not sorted_points.has(n.world):
			# create sort array
			sorted_points[n.world] = []
		sorted_points[n.world].append(n) # then append
		
	# 2) for each world, select median point from random selection of nodes and add to tree.
	# the median is semi-important to try to make sure the tree isn't lopsided for faster and more accurate lookups.
	for w in sorted_points:
		var median:NavPoint
		# if >= 5 nodes in world, select random and find median
		if sorted_points[w].size() >= 5:
			# select 5 random points
			var selected:Array[NavPoint] = (func():
				var arr: Array[NavPoint] = []
				for i in range(5):
					arr.append(sorted_points[w].pick_random())
				return arr
			).call()
			# Find median point
			var middle_coords:Vector3 = selected.reduce(func(accum:Array, pt:NavPoint): # first we sum up the point coordinates
				accum[0] += pt.position.x
				accum[1] += pt.position.y
				accum[2] += pt.position.z
			).reduce(func(accum:Vector3, num:float): # then we divide each component
				accum[0] = num / 5
				accum[1] = num / 5
				accum[2] = num / 5
			)
			# then we sort by distance to center point. using quared to avoid a sqrt. Sort descending.
			selected.sort_custom(func(a:NavPoint, b:NavPoint): return middle_coords.distance_squared_to(a.position) > middle_coords.distance_squared_to(b.position))
			median = selected.pop_back()
		else: # else, accumulate all of them
			var arr_size = sorted_points[w].size()
			var middle_coords:Vector3 = sorted_points[w].reduce(func(accum:Array, pt:NavPoint): # first we sum up the point coordinates
				accum[0] += pt.position.x
				accum[1] += pt.position.y
				accum[2] += pt.position.z
			).reduce(func(accum:Vector3, num:float): # then we divide each component
				accum[0] = num / arr_size
				accum[1] = num / arr_size
				accum[2] = num / arr_size
			)
			# then we sort by distance to center point. using quared to avoid a sqrt. Sort descending.
			sorted_points[w].sort_custom(func(a:NavPoint, b:NavPoint): return middle_coords.distance_squared_to(a.position) > middle_coords.distance_squared_to(b.position))
			median = sorted_points[w].pop_back()
		# add median
		add_point(median.world, median.position)
	
	# 3) for each world, add all the rest of the points, going by the median.
	# A bit wasteful, maybe, As before, we want to keep the tree balanced.
	for w in sorted_points:
		var median:NavPoint
		while not sorted_points[w].size() == 0: # while loop here, because 1) gdscript doesnt like you editing an array while looping through it, and we want to empty the array anyway
			var arr_size = sorted_points[w].size()
			var middle_coords:Vector3 = sorted_points[w].reduce(func(accum:Array, pt:NavPoint): # first we sum up the point coordinates
				accum[0] += pt.position.x
				accum[1] += pt.position.y
				accum[2] += pt.position.z
			).reduce(func(accum:Vector3, num:float): # then we divide each component
				accum[0] = num / arr_size
				accum[1] = num / arr_size
				accum[2] = num / arr_size
			)
			# then we sort by distance to center point. using quared to avoid a sqrt. Sort descending.
			sorted_points[w].sort_custom(func(a:NavPoint, b:NavPoint): return middle_coords.distance_squared_to(a.position) > middle_coords.distance_squared_to(b.position))
			median = sorted_points[w].pop_back()
			# add median
			add_point(median.world, median.position)
	
	# Cache references to trees (worlds are now RefCounted, already in the worlds dictionary)
	pass


## Add a point to the tree
func add_point(world:String, pos:Vector3) -> NavNode:
	var world_node: NavWorld = worlds.get(world) as NavWorld
	# Add world if it doesnt already exist
	if not world_node:
		world_node = NavWorld.new()
		world_node.world = world
		worlds[world] = world_node
	
	return world_node.add_point(pos)


func connect_nodes(a:NavNode, b:NavNode, cost:float) -> void:
	a.connect_nodes(b, cost)
	b.connect_nodes(a, cost)


## Build a series of KD Trees from [Netowrk]s. Dictionary assumes the key is the world name, and the value is the network.
func _load_from_networks(data:Dictionary):
	# NavNode/NavWorld are now RefCounted (not scene tree Nodes), eliminating
	# per-object Godot Node overhead.  A further optimization to packed arrays
	# with integer indices is possible but deferred for readability.
	# use dictionary to hold the point and the new node it contains, to avoid duplicates and to have lookups later
	var added_nodes = {}
	var edges = []
	var portals = []
	var portal_edges = []
	# add each point from each network
	for world in data:
		edges.append_array(data[world].edges)
		portals.append_array(data[world].portals)
		portal_edges.append_array(data[world].portal_edges)
		
		for point in data[world].points + data[world].portals:
			var node = add_point(world, point.position)
			added_nodes[point] = node
			# Register in lookup table for connection persistence
			_node_lookup[point] = node
	# then go back and connect edges and portals, using the dictionary as a lookup
	for edge in edges:
		connect_nodes(added_nodes[edge.point_a], added_nodes[edge.point_b], edge.cost)
	for edge in portal_edges:
		if added_nodes.has(edge.portal_from) and added_nodes.has(edge.portal_to):
			connect_nodes(added_nodes[edge.portal_from], added_nodes[edge.portal_to], 0)
		else:
			# Store for later retry when the connecting world is loaded
			_pending_portal_edges.append(edge)
			push_warning("NavMaster: Portal connection deferred. Connecting world not yet loaded.")


func _load_from_disk(path:String, networks:Dictionary, regex:RegEx) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if '.tres.remap' in file_name:
				file_name = file_name.trim_suffix('.remap')
			if dir.current_is_dir(): # if is directory, cache subdirectory
				_load_from_disk(file_name, networks, regex)
			else: # if filename, cache filename
				var result = regex.search(file_name)
				if result:
					networks[result.get_string(1) as StringName] = load("%s/%s" % [path, file_name])
			file_name = dir.get_next()
		dir.list_dir_end()


func load_all_networks() -> void:
	var networks = {}
	var path = ProjectSettings.get_setting("skelerealms/networks_path")
	var regex = RegEx.new()
	regex.compile("([^\\/\n\\r]+).tres")
	
	_load_from_disk(path, networks, regex)
	_load_from_networks(networks)
	# Retry any portal connections that were deferred
	_load()


static func format_point_name(pt:Vector3, world:StringName) -> String:
	return ("%s-%s" % [world, pt]).replace(".", "_")


## Save connection data for persistence across sessions.
## Serializes all NavNode connections as an array of edge dictionaries.
func save() -> Dictionary:
	var connection_data:Array = []
	for world_name in worlds:
		var world_node:NavWorld = worlds[world_name]
		if not world_node.root:
			continue
		_collect_connections(world_node.root, connection_data, world_name, {})
	return {"connections": connection_data}


## Recursively collect connection data from the KD-tree.
func _collect_connections(node:NavNode, out:Array, world:String, visited:Dictionary) -> void:
	if not node:
		return
	if visited.has(node):
		return
	visited[node] = true
	for other:NavNode in node.connections:
		# Avoid duplicates: only record if this node's name sorts before the other
		if node.node_name < other.node_name:
			out.append({
				"from_world": world,
				"from_pos": [node.position.x, node.position.y, node.position.z],
				"to_world": other.world,
				"to_pos": [other.position.x, other.position.y, other.position.z],
				"cost": node.connections[other],
			})
	if node.left_child:
		_collect_connections(node.left_child, out, world, visited)
	if node.right_child:
		_collect_connections(node.right_child, out, world, visited)


## Load saved connection data and apply to the current KD-tree.
func load_data(data:Dictionary) -> void:
	var connection_data:Array = data.get("connections", [])
	for entry in connection_data:
		var from_world:String = entry.get("from_world", "")
		var from_pos_arr:Array = entry.get("from_pos", [0, 0, 0])
		var from_pos := Vector3(from_pos_arr[0], from_pos_arr[1], from_pos_arr[2])
		var to_world:String = entry.get("to_world", "")
		var to_pos_arr:Array = entry.get("to_pos", [0, 0, 0])
		var to_pos := Vector3(to_pos_arr[0], to_pos_arr[1], to_pos_arr[2])
		var cost:float = entry.get("cost", 1.0)
		
		var from_node = nearest_point(NavPoint.new(from_world, from_pos))
		var to_node = nearest_point(NavPoint.new(to_world, to_pos))
		if from_node and to_node:
			# Only apply if not already connected
			if not from_node.connections.has(to_node):
				connect_nodes(from_node, to_node, cost)


## Reset connection state. Called when loading a save that has no entry for this node.
func reset_data() -> void:
	pass  # Connections will be rebuilt from Network resources on next load
