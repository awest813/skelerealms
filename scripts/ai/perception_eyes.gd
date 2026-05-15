class_name EyesPerception
extends Node3D
## This handles seeing, and it attached to the head of the character.


## FOV is the field of view of the eyes, in degrees. The default value is 90 degrees.
@export var fov_h:float = 90
@export var fov_v:float = 90
@export var view_distance:float = 30
@export var light_level_threshold:float = 0.1
@export var perception_interval:float = 0.25

var light_probe:LightEstimation
var t:Timer


signal perceived(percieved:PerceptionData)
signal not_perceived(percieved:PerceptionData)


func _ready() -> void:
	t = Timer.new()
	add_child(t)
	t.start(perception_interval)
	t.timeout.connect(try_perception.bind())
	light_probe = $Probe


## Check if this can see a target
func check_sees_collider(pt:PhysicsBody3D) -> PerceptionData:
	if not is_inside_tree():
		return PerceptionData.new("", 0)
	# 1) See if target in range
	if global_position.distance_to(pt.global_position) > view_distance:
		return PerceptionData.new(_find_ref_id(pt), 0)
	# 2) See if direction to target within FOV (horizontal and vertical)
	var direction_to = (pt.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	# Horizontal FOV check using yaw
	var forward_xz = Vector3(forward.x, 0, forward.z).normalized()
	var dir_xz = Vector3(direction_to.x, 0, direction_to.z).normalized()
	var h_dot = forward_xz.dot(dir_xz)
	var h_threshold = cos(deg_to_rad(fov_h / 2.0))
	if h_dot < h_threshold:
		return PerceptionData.new(_find_ref_id(pt), 0)
	# Vertical FOV check using pitch
	var v_angle = asin(clampf(direction_to.y, -1.0, 1.0))
	var forward_pitch = asin(clampf(forward.y, -1.0, 1.0))
	if absf(v_angle - forward_pitch) > deg_to_rad(fov_v / 2.0):
		return PerceptionData.new(_find_ref_id(pt), 0)
	# 3) Raycast check
	await get_tree().physics_frame
	if not get_world_3d():
		return PerceptionData.new("", 0)
	var state = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(global_position, pt.global_position)
	var c = state.intersect_ray(q)
	if c: # if collider hit
		if not (c["collider"] == pt or (c["collider"] as Node).is_ancestor_of(pt)): # if collider hit is this or ancestor
			return PerceptionData.new(_find_ref_id(pt), 0)
	# 4) Calculate light level
	var light_level = await light_probe.get_light_level_for_point(pt.position)
	if light_level < light_level_threshold:
		return null
	# 5) Calculate percent of coverage with AABBs
	var coverage = _calculate_aabb_coverage(pt, state)
	if is_zero_approx(coverage):
		return PerceptionData.new(_find_ref_id(pt), 0)
	return PerceptionData.new(_find_ref_id(pt), light_level * coverage)


## Looks at a point and sees if it can see whatever it is. ID is blank if it doesn't hit an entity puppet.
func get_thing_under_sight(pt:NavPoint) -> PerceptionData:
	if not pt.world == GameInfo.world:
		return null
	# 1) See if target in range
	if position.distance_to(pt.position) > view_distance:
		return null
	# 2) See if direction to target within FOV (horizontal and vertical)
	var direction_to = (pt.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	# Horizontal FOV check using yaw
	var forward_xz = Vector3(forward.x, 0, forward.z).normalized()
	var dir_xz = Vector3(direction_to.x, 0, direction_to.z).normalized()
	var h_dot = forward_xz.dot(dir_xz)
	var h_threshold = cos(deg_to_rad(fov_h / 2.0))
	if h_dot < h_threshold:
		return null
	# Vertical FOV check using pitch
	var v_angle = asin(clampf(direction_to.y, -1.0, 1.0))
	var forward_pitch = asin(clampf(forward.y, -1.0, 1.0))
	if absf(v_angle - forward_pitch) > deg_to_rad(fov_v / 2.0):
		return null
	# 3) Raycast check
	await get_tree().physics_frame
	var state = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(global_position, pt.global_position)
	var c = state.intersect_ray(q)
	if not c: # if collider not hit
		return null
	var id = _find_ref_id(c["collider"])
	var light_level = await light_probe.get_light_level_for_point(pt.position)
	if light_level < light_level_threshold:
		return null
	return PerceptionData.new(id, light_level)


## Looks for a specific entity, and returns with the data. Null if not found.
func look_for_entity(refID:StringName) -> PerceptionData:
	var entity = SKEntityManager.instance.get_entity(refID)
	if entity:
		var pt = NavPoint.new(entity.world, entity.position)
		var res = await get_thing_under_sight(pt)
		if res:
			if res.object == refID:
				return res
	return null


## Try looking at everything in range.
func try_perception() -> void:
	var perception_targets = get_tree()\
		.get_nodes_in_group("perception_target")\
		.filter(func(x:Node):
#			if x.is_ancestor_of(self):
#				return false
#			print("""
#			Node: %s
#			Type: %s
#			Distance check: %s (%s) 
#			""" % [
#				x,
#				(x is CollisionShape3D or x is PhysicsBody3D),
#				(x as Node3D).global_position.distance_to(global_position) <= view_distance,
#				(x as Node3D).global_position.distance_to(global_position)
#			])
			return not x.is_ancestor_of(self) and\
			(x is CollisionShape3D or x is PhysicsBody3D) and \
			(x as Node3D).global_position.distance_to(global_position) <= view_distance
			)
	# Loop through targets and get check info.
	for target in perception_targets:
		var res = await check_sees_collider(target)
		if res.visibility > 0: # If we see it, emit signal
			perceived.emit(res)
			# print("percieved %s" % res)
		else:
			not_perceived.emit(res)


## Calculates the approximate AABB coverage of a target by raycasting sample
## points on the target's bounding box. Returns a value from 0.0 to 1.0.
func _calculate_aabb_coverage(target: PhysicsBody3D, state: PhysicsDirectSpaceState3D) -> float:
	# Try to get AABB from collision shapes or visual instances
	var aabb := AABB()
	var found_aabb := false
	for child in target.get_children():
		if child is CollisionShape3D and child.shape:
			var shape_aabb := child.shape.get_debug_mesh().get_aabb()
			shape_aabb.position += child.position
			if found_aabb:
				aabb = aabb.merge(shape_aabb)
			else:
				aabb = shape_aabb
				found_aabb = true
		elif child is VisualInstance3D:
			var vis_aabb := child.get_aabb()
			vis_aabb.position += child.position
			if found_aabb:
				aabb = aabb.merge(vis_aabb)
			else:
				aabb = vis_aabb
				found_aabb = true
	
	# Fallback: use a unit-sized AABB centered on the target
	if not found_aabb:
		aabb = AABB(target.global_position - Vector3(0.5, 0.5, 0.5), Vector3(1, 1, 1))
	else:
		# Transform AABB to global space
		aabb.position += target.global_position - target.position
	
	# Sample points on the AABB surface: center + 6 face centers = 7 points
	var sample_points: Array[Vector3] = []
	var center = aabb.get_center()
	sample_points.append(center)
	sample_points.append(Vector3(aabb.position.x, center.y, center.z)) # left face
	sample_points.append(Vector3(aabb.end.x, center.y, center.z)) # right face
	sample_points.append(Vector3(center.x, aabb.position.y, center.z)) # bottom face
	sample_points.append(Vector3(center.x, aabb.end.y, center.z)) # top face
	sample_points.append(Vector3(center.x, center.y, aabb.position.z)) # front face
	sample_points.append(Vector3(center.x, center.y, aabb.end.z)) # back face
	
	var hits := 0
	for sample_pt in sample_points:
		var ray_q = PhysicsRayQueryParameters3D.create(global_position, sample_pt)
		var result = state.intersect_ray(ray_q)
		if result:
			# Check if we hit the target itself, a child of the target, or a parent of the target
			var collider_node := result["collider"] as Node
			if collider_node == target or target.is_ancestor_of(collider_node):
				hits += 1
		else:
			# No hit means the ray passed through (point visible if nothing blocked)
			hits += 1
	
	return float(hits) / float(sample_points.size())


func _find_ref_id(n:Node) -> String:
	var check:Node = n.get_parent()
	while check.get_parent():
		if check is SKEntity:
			return (check as SKEntity).name
		check = check.get_parent()
	return ""


class PerceptionData:
	var object:String
	var visibility:float
	
	
	func _init(obj:String, vis:float) -> void:
		object = obj
		visibility = vis
