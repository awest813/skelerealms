extends GutTest
## Regression coverage for the baseline needed by the flight game.

class _ManagerFixture extends SKEntityManager:
	func _ready() -> void:
		pass

class _EntityFixture extends SKEntity:
	func _process(_delta: float) -> void:
		pass
	func get_component(type: String) -> SKEntityComponent:
		return get_node_or_null(type) as SKEntityComponent

var _manager: SKEntityManager
var _loader: WorldLoader

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameInfo.is_loading = false
	GameInfo.unpause_game()
	_manager = _ManagerFixture.new()
	add_child_autofree(_manager)

func after_each() -> void:
	GameInfo.is_loading = false
	GameInfo.unpause_game()
	SaveSystem._snapshot = {}

func _make_loader() -> WorldLoader:
	var loader := WorldLoader.new()
	var old := Node3D.new()
	old.name = "old_world"
	loader.add_child(old)
	add_child_autofree(loader)
	for id in ["a", "b"]:
		var root := Node3D.new()
		root.name = id
		var scene := PackedScene.new()
		scene.pack(root)
		root.free()
		var path := "user://baseline_world_%s.tscn" % id
		ResourceSaver.save(scene, path)
		loader.world_paths[id] = path
	return loader

func _wait_for_loader(loader: WorldLoader) -> void:
	for i in 200:
		await get_tree().process_frame
		if not loader._request_active:
			return
	fail_test("World load timed out.")

func test_repeated_jumps_free_old_worlds_and_reject_overlap() -> void:
	var loader := _make_loader()
	for i in 8:
		var old: WeakRef = weakref(loader.get_child(0))
		var destination := "a" if i % 2 == 0 else "b"
		assert_true(loader.load_world(destination))
		assert_false(loader.load_world(destination), "Only one transition can be active.")
		await _wait_for_loader(loader)
		await get_tree().process_frame
		assert_eq(loader.get_child_count(), 1)
		assert_null(old.get_ref(), "Replaced scene must be freed, not orphaned.")
		assert_eq(str(GameInfo.world), destination)
		assert_false(get_tree().paused)

func test_invalid_destination_preserves_world() -> void:
	var loader := _make_loader()
	var old := loader.get_child(0)
	assert_false(loader.load_world("missing"))
	assert_same(loader.get_child(0), old)
	assert_false(GameInfo.is_loading)

func test_failed_preparation_keeps_original_without_duplicate() -> void:
	var loader := _make_loader()
	var old := loader.get_child(0)
	# Exercise the rollback point before a scene commit deterministically.
	loader._previous_world_id = "old_world"
	loader._request_active = true
	loader._was_paused = false
	GameInfo.is_loading = true
	GameInfo.pause_game(true)
	loader._abort("Injected preparation failure")
	assert_same(loader.get_child(0), old)
	assert_eq(loader.get_child_count(), 1)
	assert_false(GameInfo.is_loading)
	assert_false(get_tree().paused)

func test_transition_preserves_existing_pause() -> void:
	var loader := _make_loader()
	GameInfo.pause_game(true)
	assert_true(loader.load_world("a"))
	await _wait_for_loader(loader)
	assert_true(get_tree().paused)

func _target() -> SKHurtbox:
	var entity := _EntityFixture.new()
	entity.name = "target"
	_manager._add_entity_raw(entity)
	var damage := DamageableComponent.new()
	entity.add_child(damage)
	watch_signals(damage)
	var area := SKHurtbox.new()
	area.owner_entity_ref = &"target"
	area.position = Vector3(0, 0, -5)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	add_child_autofree(area)
	return area

func test_hitscan_reaches_hurtbox_once_and_respects_obstacles() -> void:
	var target := _target()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var action := CombatAction.new()
	action.base_damage = {&"laser": 10.0}
	action.crit_chance = 0.0
	var space := target.get_world_3d().direct_space_state
	assert_eq(HitPipeline.resolve_hitscan(space, Vector3.ZERO, Vector3.FORWARD, action, "shooter"), HitPipeline.HitResult.LANDED)
	var damage := _manager.entities[&"target"].get_component("DamageableComponent")
	assert_signal_emit_count(damage, "damaged", 1)
	var obstacle := StaticBody3D.new()
	obstacle.position = Vector3(0, 0, -2)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	obstacle.add_child(shape)
	add_child_autofree(obstacle)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(HitPipeline.resolve_hitscan(space, Vector3.ZERO, Vector3.FORWARD, action, "shooter"), HitPipeline.HitResult.MISSED)
	assert_signal_emit_count(damage, "damaged", 1)
	var excluded: Array[RID] = [target.get_rid(), obstacle.get_rid()]
	assert_eq(HitPipeline.resolve_hitscan(space, Vector3.ZERO, Vector3.FORWARD, action, "shooter", &"", excluded), HitPipeline.HitResult.MISSED)

func test_save_repeated_slots_preserves_clean_components_and_orientation() -> void:
	var entity := _EntityFixture.new()
	entity.name = "saved_ship"
	entity.world = "a"
	entity.rotation = Quaternion(Vector3.UP, 0.7)
	_manager._add_entity_raw(entity)
	var inventory := InventoryComponent.new()
	entity.add_child(inventory)
	inventory.add_money(125, &"credits")
	SaveSystem.save("baseline_a")
	SaveSystem.save("baseline_b")
	var stored := SaveSystem._deserialize(FileAccess.get_file_as_string("user://saves/baseline_b.dat"))
	var checksum: String = stored["checksum"]
	stored.erase("checksum")
	assert_eq(SaveSystem._compute_checksum(SaveSystem._serialize(stored)), checksum, "A freshly written save must validate after JSON conversion.")
	inventory.remove_money(100, &"credits")
	entity.rotation = Quaternion.IDENTITY
	assert_true(SaveSystem.load_slot("baseline_b"))
	assert_eq(inventory.currencies[&"credits"], 125)
	assert_true(entity.rotation.is_equal_approx(Quaternion(Vector3.UP, 0.7)))
	for slot in ["baseline_a", "baseline_b"]:
		DirAccess.remove_absolute("user://saves/%s.dat" % slot)

func test_save_parser_rejects_non_object_json() -> void:
	assert_eq(SaveSystem._deserialize("[]"), {})
	assert_eq(SaveSystem._deserialize("broken"), {})

func test_save_validation_rejects_nested_corruption_and_future_schema() -> void:
	var valid := {"schema_version": 2, "entity_data": {}, "game_info": {}, "other_data": {}}
	assert_true(SaveSystem._valid_snapshot(valid))
	for patch in [
		{"entity_data": {"ship": []}},
		{"entity_data": {"ship": {"components": {"InventoryComponent": 42}}}},
		{"game_info": {"GameInfo": "invalid"}},
		{"schema_version": 999},
		{"schema_version": "two"},
		{"checksum": 123},
	]:
		var invalid := valid.duplicate(true)
		invalid.merge(patch, true)
		assert_false(SaveSystem._valid_snapshot(invalid))
	assert_false(SaveSystem._valid_snapshot({"unrelated": "json"}))

func test_loader_tracks_the_attached_world_independently_of_restored_metadata() -> void:
	var loader := _make_loader()
	GameInfo.world = &"a" # A save may restore metadata before loading its scene.
	assert_true(loader.load_world("b"))
	assert_eq(loader._previous_world_id, "old_world")
	await _wait_for_loader(loader)
	assert_eq(loader.active_world_id, "b")

func test_puppet_spawn_restores_orientation() -> void:
	var entity := _EntityFixture.new()
	entity.name = "rotated_ship"
	entity.rotation = Quaternion(Vector3.UP, 1.0)
	entity.position = Vector3(3, 2, 1)
	_manager._add_entity_raw(entity)
	var spawner := PuppetSpawnerComponent.new()
	spawner.add_child(Node3D.new())
	entity.add_child(spawner)
	spawner.spawn()
	assert_true((spawner.puppet as Node3D).quaternion.is_equal_approx(entity.rotation))
	assert_eq((spawner.puppet as Node3D).position, entity.position)

func test_manager_deletion_clears_only_its_own_global_reference() -> void:
	var first := _ManagerFixture.new()
	var second := _ManagerFixture.new()
	first.free()
	assert_same(SKEntityManager.instance, second)
	second.free()
	assert_null(SKEntityManager.instance)
