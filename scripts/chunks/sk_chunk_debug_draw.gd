class_name SKChunkDebugDraw
extends Node3D
## Runtime visualization of the chunk loading grid.
##
## Draws chunk boundaries as coloured axis-aligned rectangles on the XZ plane
## using [ImmediateMesh], colour-coded by chunk lifecycle state.
## [br]
## • [member error_color] — load failed
## [br]• [member mounted_color] — loaded and mounted (active in the scene)
## [br]• [member loaded_color] — loaded but not yet mounted
## [br]• [member loading_color] — load in progress
## [br]• [member pending_color] — created, waiting for load
## [br]
## Add this node to your scene, assign [member chunk_manager] in the Inspector,
## then toggle visibility with [member toggle_key] (default [kbd]F8[/kbd]).
## [br]
## [b]Note:[/b] Disable or remove this node in production builds to avoid
## unnecessary per-frame mesh rebuilds.


## The [SKChunkManager] to visualize. Must be assigned before the overlay is shown.
@export var chunk_manager: SKChunkManager
## Keyboard shortcut to toggle the overlay on/off.
@export var toggle_key: Key = KEY_F8
## Seconds between mesh rebuilds. Set to [code]0.0[/code] for every-frame updates.
@export var rebuild_interval: float = 0.5
## Y height at which chunk rectangles are drawn.
@export var draw_y: float = 1.0

@export_group("Colors")
## Color for chunks whose last load attempt failed.
@export var error_color: Color = Color(0.9, 0.1, 0.1, 0.9)
## Color for chunks that are loaded and mounted in the scene.
@export var mounted_color: Color = Color(0.1, 0.9, 0.2, 0.9)
## Color for chunks that are loaded but not yet mounted.
@export var loaded_color: Color = Color(0.2, 0.5, 0.9, 0.9)
## Color for chunks whose load is currently in progress.
@export var loading_color: Color = Color(0.9, 0.7, 0.1, 0.9)
## Color for chunks that are created but not yet loading.
@export var pending_color: Color = Color(0.5, 0.5, 0.5, 0.5)

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


## Force an immediate redraw of the chunk grid overlay.
func redraw() -> void:
	_redraw()


func _redraw() -> void:
	_imesh.clear_surfaces()
	if not is_instance_valid(chunk_manager):
		return

	var all_chunks: Array[SKChunk] = chunk_manager.get_all_chunks()
	if all_chunks.is_empty():
		return

	var size: float = chunk_manager.chunk_size

	_imesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for chunk: SKChunk in all_chunks:
		var col := _color_for_chunk(chunk)
		var x0 := chunk.coords.x * size
		var x1 := x0 + size
		var z0 := chunk.coords.y * size
		var z1 := z0 + size
		var y := draw_y
		# Draw the four edges of the chunk rectangle.
		_line(Vector3(x0, y, z0), Vector3(x1, y, z0), col)
		_line(Vector3(x1, y, z0), Vector3(x1, y, z1), col)
		_line(Vector3(x1, y, z1), Vector3(x0, y, z1), col)
		_line(Vector3(x0, y, z1), Vector3(x0, y, z0), col)
	_imesh.surface_end()


func _color_for_chunk(chunk: SKChunk) -> Color:
	if chunk.error != null:
		return error_color
	if chunk.is_mounted:
		return mounted_color
	if chunk.is_loaded:
		return loaded_color
	if chunk.is_loading:
		return loading_color
	return pending_color


func _line(a: Vector3, b: Vector3, col: Color) -> void:
	_imesh.surface_set_color(col)
	_imesh.surface_add_vertex(a)
	_imesh.surface_set_color(col)
	_imesh.surface_add_vertex(b)
