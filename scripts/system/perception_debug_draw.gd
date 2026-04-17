class_name PerceptionDebugDraw
extends Node3D
## Runtime visualization of NPC perception (field-of-view cones and detection markers).
## For every active NPC whose puppet has an [EyesPerception] node, draws:
## [br]
## • A horizontal FOV arc showing the viewing angle and range.
## • Boundary rays at the left and right edges of the cone.
## • A cross marker at each tracked entity's last-known position, coloured by
##   visibility: red = actively visible, yellow = tracked but invisible.
## • A faint line from the eye origin to each tracked entity's last-known position.
## [br]
## Add this node to your scene. Toggle with [member toggle_key] (default F12).


## Colour for the FOV boundary arc and rays.
@export var fov_color: Color = Color(0.3, 0.75, 1.0, 0.65)
## Colour when an entity is actively visible (visibility > 0).
@export var detected_color: Color = Color(1.0, 0.2, 0.2, 0.9)
## Colour when an entity is tracked but currently invisible.
@export var tracked_color: Color = Color(1.0, 0.85, 0.2, 0.65)
## Key to toggle overlay.
@export var toggle_key: Key = KEY_F12
## Seconds between mesh rebuilds.
@export var rebuild_interval: float = 0.1
## Number of line segments used for the horizontal FOV arc.
@export var arc_segments: int = 20

var _mesh_instance: MeshInstance3D
var _imesh: ImmediateMesh
var _timer: float = 0.0


func _ready() -> void:
	_imesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _imesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = mat

	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey \
			and (event as InputEventKey).keycode == toggle_key \
			and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		visible = not visible
		if not visible:
			_imesh.clear_surfaces()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if rebuild_interval > 0.0 and _timer < rebuild_interval:
		return
	_timer = 0.0
	_redraw()


func _redraw() -> void:
	_imesh.clear_surfaces()
	if not is_instance_valid(SKEntityManager.instance):
		return

	_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for entity_id: StringName in SKEntityManager.instance.entities:
		var entity: SKEntity = SKEntityManager.instance.entities[entity_id]
		var npc: NPCComponent = entity.get_component("NPCComponent") as NPCComponent
		if not npc or not is_instance_valid(npc._puppet):
			continue

		var eyes: EyesPerception = _find_eyes(npc._puppet)
		if not eyes:
			continue

		_draw_fov_cone(eyes)
		_draw_perception_markers(npc, eyes.global_position)
	_imesh.surface_end()


## Recursively search a node's subtree for an [EyesPerception] node.
func _find_eyes(node: Node) -> EyesPerception:
	if node is EyesPerception:
		return node as EyesPerception
	for child in node.get_children():
		var found: EyesPerception = _find_eyes(child)
		if found:
			return found
	return null


func _draw_fov_cone(eyes: EyesPerception) -> void:
	var origin: Vector3 = eyes.global_position
	var forward: Vector3 = -eyes.global_transform.basis.z
	var half_h: float = deg_to_rad(eyes.fov_h * 0.5)
	var dist: float = eyes.view_distance

	# ── Horizontal FOV arc ──
	var prev: Vector3 = Vector3.ZERO
	for i in range(arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		var angle: float = lerpf(-half_h, half_h, t)
		var dir: Vector3 = forward.rotated(Vector3.UP, angle).normalized()
		var pt: Vector3 = origin + dir * dist
		_imesh.surface_set_color(fov_color)
		if i > 0:
			_imesh.surface_add_vertex(prev)
			_imesh.surface_set_color(fov_color)
			_imesh.surface_add_vertex(pt)
		prev = pt

	# ── Left boundary ray ──
	_imesh.surface_set_color(fov_color)
	_imesh.surface_add_vertex(origin)
	_imesh.surface_set_color(fov_color)
	_imesh.surface_add_vertex(origin + forward.rotated(Vector3.UP, -half_h).normalized() * dist)

	# ── Right boundary ray ──
	_imesh.surface_set_color(fov_color)
	_imesh.surface_add_vertex(origin)
	_imesh.surface_set_color(fov_color)
	_imesh.surface_add_vertex(origin + forward.rotated(Vector3.UP, half_h).normalized() * dist)


func _draw_perception_markers(npc: NPCComponent, eye_origin: Vector3) -> void:
	for tracked_id: StringName in npc.perception_memory:
		var entry: Dictionary = npc.perception_memory[tracked_id]
		var vis: float = entry.get(&"visibility", 0.0)
		var last_pos: Vector3 = entry.get(&"last_seen_position", eye_origin)
		var col: Color = detected_color if vis > 0.0 else tracked_color

		# ── Cross marker at last-known position ──
		const ARM: float = 0.4
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(-ARM, 0.0, 0.0))
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(ARM, 0.0, 0.0))

		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(0.0, -ARM, 0.0))
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(0.0, ARM, 0.0))

		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(0.0, 0.0, -ARM))
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(last_pos + Vector3(0.0, 0.0, ARM))

		# ── Faint line from eye to last-known position ──
		var fade := Color(col.r, col.g, col.b, 0.3)
		_imesh.surface_set_color(fade)
		_imesh.surface_add_vertex(eye_origin)
		_imesh.surface_set_color(fade)
		_imesh.surface_add_vertex(last_pos)
