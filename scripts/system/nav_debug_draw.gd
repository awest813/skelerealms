class_name NavDebugDraw
extends Node3D
## Runtime visualization of the granular navigation graph.
## Draws NavNode connections for all loaded worlds as coloured line segments
## using [ImmediateMesh].
## [br]
## • Same-world edges are drawn in [member edge_color].
## • Cross-world portal edges are drawn in [member portal_color].
## [br]
## Add this node to your scene. Toggle with [member toggle_key] (default F11).
## [b]Note:[/b] set a long [member rebuild_interval] or disable this node in
## production builds to avoid unnecessary per-frame mesh rebuilds.


## Colour for edges within the current world.
@export var edge_color: Color = Color(0.2, 0.85, 0.2, 0.85)
## Colour for cross-world portal edges.
@export var portal_color: Color = Color(0.9, 0.55, 0.1, 0.9)
## Key to toggle overlay.
@export var toggle_key: Key = KEY_F11
## Seconds between mesh rebuilds. Set to 0.0 for every-frame updates.
@export var rebuild_interval: float = 1.0

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


## Force an immediate redraw of the navigation graph.
func _redraw() -> void:
	_imesh.clear_surfaces()
	if not is_instance_valid(NavMaster.instance):
		return

	var current_world: String = ""
	if is_instance_valid(GameInfo):
		current_world = GameInfo.world

	var visited: Dictionary = {}
	_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for world_name: String in NavMaster.instance.worlds:
		var nav_world: NavWorld = NavMaster.instance.worlds[world_name]
		if nav_world.root:
			_walk_node(nav_world.root, current_world, visited)
	_imesh.surface_end()


func _walk_node(node: NavNode, current_world: String, visited: Dictionary) -> void:
	if visited.has(node):
		return
	visited[node] = true

	for other: NavNode in node.connections:
		var col: Color
		if node.world == current_world and other.world == current_world:
			col = edge_color
		else:
			col = portal_color
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(node.position)
		_imesh.surface_set_color(col)
		_imesh.surface_add_vertex(other.position)

	if node.left_child:
		_walk_node(node.left_child, current_world, visited)
	if node.right_child:
		_walk_node(node.right_child, current_world, visited)
