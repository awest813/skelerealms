## Integration tests for world streaming (WS-A cells over the chunk pipeline).
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


class _ManagerFixture extends SKEntityManager:
	func _ready() -> void:
		pass


class _EntityFixture extends SKEntity:
	func _process(_delta: float) -> void:
		pass

	func get_component(type: String) -> SKEntityComponent:
		return get_node_or_null(type) as SKEntityComponent


const CELL_DIR := "user://audit_cells"
const CELL_PATH := "user://audit_cells/cell.tscn"

var _manager: SKEntityManager
var _old_fade: Variant = null
var _had_fade := false


func before_each() -> void:
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)
	_had_fade = ProjectSettings.has_setting("skelerealms/actor_fade_distance")
	_old_fade = ProjectSettings.get_setting("skelerealms/actor_fade_distance", 100.0)


func after_each() -> void:
	if _had_fade:
		ProjectSettings.set_setting("skelerealms/actor_fade_distance", _old_fade)
	else:
		ProjectSettings.set_setting("skelerealms/actor_fade_distance", null)
	_rm_rf(CELL_DIR)


func _rm_rf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for dir_name in DirAccess.get_directories_at(path):
		_rm_rf(path.path_join(dir_name))
	DirAccess.remove_absolute(path)


# ── Fixture builders ─────────────────────────────────────────────────────


func _cell(id: StringName, x: int, y: int, interior := false, scene := "") -> CellDefinition:
	var cell := CellDefinition.new()
	cell.id = id
	cell.scene_path = scene
	cell.grid_position = Vector2i(x, y)
	cell.interior = interior
	return cell


func _worldspace() -> WorldspaceDefinition:
	var ws := WorldspaceDefinition.new()
	ws.id = &"test_reach"
	ws.cell_size = 100.0
	ws.active_radius = 1
	ws.preload_radius = 2
	ws.actor_fade_distance = 250.0
	ws.entry_cell = &"c_1_1"
	var cells: Array[CellDefinition] = []
	for cx in range(3):
		for cy in range(3):
			cells.append(_cell(StringName("c_%d_%d" % [cx, cy]), cx, cy, false, CELL_PATH))
	ws.cells = cells
	return ws


func _write_cell_scene() -> void:
	DirAccess.make_dir_recursive_absolute(CELL_DIR)
	var root := Node3D.new()
	root.name = "TestCell"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10, 10, 10)
	mesh.mesh = box
	root.add_child(mesh)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, CELL_PATH)
	root.free()


# ── Cell and worldspace validation ───────────────────────────────────────


func test_worldspace_validate() -> void:
	var ws := _worldspace()
	assert_eq(ws.validate(), [], "Sound grids validate clean.")
	assert_eq(ws.cell_center(Vector2i(1, 1)), Vector3(150, 0, 150), "Centers derive from grid.")
	assert_eq(ws.get_cell(Vector2i(9, 9)), null, "Unmapped coords yield null.")
	var dup := _worldspace()
	dup.cells.append(_cell(&"c_0_0", 5, 5, false, CELL_PATH))
	var dup_issues: Array = dup.validate()
	assert_eq(dup_issues.size(), 1, "Duplicate ids collapse to one issue.")
	assert_eq(str(dup_issues[0]["type"]), "duplicate_cell", "Issue must be typed.")
	var overlap := _worldspace()
	overlap.cells.append(_cell(&"clone", 1, 1))
	assert_eq(str(overlap.validate()[0]["type"]), "overlapping_cells", "Grid collisions must be flagged.")
	var noscene := _worldspace()
	noscene.cells[0].scene_path = ""
	assert_eq(str(noscene.validate()[0]["type"]), "missing_scene", "Sceneless cells must be flagged.")
	var badentry := _worldspace()
	badentry.entry_cell = &"nowhere"
	assert_eq(str(badentry.validate()[0]["type"]), "bad_entry_cell", "Bad entries must be flagged.")
	var badsize := _worldspace()
	badsize.cell_size = 0.0
	assert_eq(str(badsize.validate()[0]["type"]), "bad_cell_size", "Bad sizes must be flagged.")
	var badradii := _worldspace()
	badradii.active_radius = 3
	assert_eq(str(badradii.validate()[0]["type"]), "bad_radii", "Bad radii must be flagged.")


# ── Chunk source ─────────────────────────────────────────────────────────


func test_source_maps_cells_and_skips_interiors() -> void:
	_write_cell_scene()
	var ws := _worldspace()
	ws.cells.append(_cell(&"cave", 5, 5, true, CELL_PATH))
	var source := CellChunkSource.new(ws)
	var hit: Dictionary = await source.load_chunk(Vector2i(1, 1), null)
	assert_eq(String(hit.get("cell_id", "")), "c_1_1", "Grid coords must resolve cells.")
	assert_true((hit.get("scene") as PackedScene).can_instantiate(), "Payloads must carry scenes.")
	assert_eq(await source.load_chunk(Vector2i(9, 9), null), {}, "Wilderness must load clean and empty.")
	assert_eq(await source.load_chunk(Vector2i(5, 5), null), {}, "Interiors must not stream.")
	assert_eq(await CellChunkSource.new(null).load_chunk(Vector2i(0, 0), null), null, "Missing worldspace must fail.")
	var broken := _worldspace()
	broken.cells.append(_cell(&"broken", 7, 7, false, "res://no_such_cell.tscn"))
	assert_eq(await CellChunkSource.new(broken).load_chunk(Vector2i(7, 7), null), null, "Bad scene paths must fail.")


func test_source_honors_cancel() -> void:
	_write_cell_scene()
	var source := CellChunkSource.new(_worldspace())
	var token := SKCancelToken.new()
	token.cancel()
	assert_eq(await source.load_chunk(Vector2i(0, 0), token), null, "Cancelled loads must abort.")


# ── Chunk adapter ────────────────────────────────────────────────────────


func test_adapter_mounts_at_centers() -> void:
	_write_cell_scene()
	var root := Node3D.new()
	add_child_autofree(root)
	var adapter := CellChunkAdapter.new(root, 100.0)
	var chunk := SKChunk.new(Vector2i(2, 3))
	chunk.data = {"scene": load(CELL_PATH) as PackedScene, "coords": Vector2i(2, 3)}
	adapter.mount(chunk)
	assert_eq(root.get_child_count(), 1, "Mount must instantiate.")
	assert_eq((root.get_child(0) as Node3D).position, Vector3(250, 0, 350), "Mounts must sit on cell centers.")
	adapter.unmount(chunk)
	await get_tree().process_frame
	assert_eq(root.get_child_count(), 0, "Unmount must free.")
	adapter.unmount(chunk)
	var empty := SKChunk.new(Vector2i(9, 9))
	empty.data = {}
	adapter.mount(empty)
	assert_eq(root.get_child_count(), 0, "Empty payloads must mount nothing.")
	var orphan := CellChunkAdapter.new(null, 100.0)
	orphan.mount(chunk)
	assert_true(true, "Rootless adapters must not crash.")


# ── Streamer integration ─────────────────────────────────────────────────


func test_streamer_mounts_and_evicts_grid() -> void:
	_write_cell_scene()
	ProjectSettings.set_setting("skelerealms/actor_fade_distance", 100.0)
	var streamer := CellStreamer.new()
	add_child_autofree(streamer)
	var ws := _worldspace()
	streamer.start(ws)
	await streamer.update_origin(Vector3(150, 0, 150))
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: Array = streamer.loaded_cells()
	assert_eq(loaded.size(), 9, "Active radius 1 must mount nine cells.")
	assert_true(loaded.has(&"c_1_1"), "Center cell must mount.")
	streamer.update_origin(Vector3(5000, 0, 5000))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(streamer.loaded_cells().size(), 0, "Far origins must evict everything.")
	streamer.stop()


func test_streamer_applies_fade_policy() -> void:
	_write_cell_scene()
	ProjectSettings.set_setting("skelerealms/actor_fade_distance", 100.0)
	var e := _EntityFixture.new()
	e.name = &"extra"
	_manager._add_entity_raw(e)
	e._actor_fade_dist_sq = 999.0
	var streamer := CellStreamer.new()
	add_child_autofree(streamer)
	streamer.start(_worldspace())
	assert_eq(ProjectSettings.get_setting("skelerealms/actor_fade_distance"), 250.0, "Entry must apply the fade policy.")
	assert_eq(e._actor_fade_dist_sq, -1.0, "Entry must invalidate warm caches.")
	e._actor_fade_dist_sq = 999.0
	streamer.stop()
	assert_eq(ProjectSettings.get_setting("skelerealms/actor_fade_distance"), 100.0, "Exit must restore the policy.")
	assert_eq(e._actor_fade_dist_sq, -1.0, "Exit must invalidate again.")


func test_manager_fade_invalidation() -> void:
	var e := _EntityFixture.new()
	e.name = &"extra"
	_manager._add_entity_raw(e)
	e._actor_fade_dist_sq = 42.0
	_manager.invalidate_fade_cache()
	assert_eq(e._actor_fade_dist_sq, -1.0, "Caches must reset.")


# ── World validation ─────────────────────────────────────────────────────


func _door_to(world: String, with_destination := true) -> Door:
	var door := Door.new()
	if with_destination:
		var dest := DoorInstance.new()
		dest.world = StringName(world)
		dest.position = Vector3.ZERO
		door.destination_instance = dest
	return door


func test_validate_doors() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var good := _door_to("demo_world")
	good.name = "GoodDoor"
	root.add_child(good)
	var naked := _door_to("", false)
	naked.name = "NakedDoor"
	root.add_child(naked)
	var lost := _door_to("missing_world")
	lost.name = "LostDoor"
	root.add_child(lost)
	var issues: Array = WorldValidator.validate_doors(root, {"demo_world": "res://worlds/demo_world.tscn"})
	assert_eq(issues.size(), 2, "Exactly the two bad doors must flag.")
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("door_without_destination"), "Missing instances must flag.")
	assert_true(kinds.has("door_unknown_world"), "Unknown worlds must flag.")


func test_validate_world_combines_suites() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	root.add_child(mesh)
	var issues: Array = WorldValidator.validate_world(root, {}, _worldspace(), {"max_meshes": 0})
	var kinds := {}
	for issue in issues:
		kinds[str(issue["type"])] = true
	assert_true(kinds.has("over_mesh_budget"), "Budget overruns must flag.")
	assert_eq(WorldValidator.validate_world(root, {}, _worldspace(), {"max_meshes": 10}), [], "Clean worlds must pass.")
