extends Node
## End-to-end baseline check using the actual example scene and save coordinator.
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle(loader: WorldLoader) -> void:
	for i in 300:
		await get_tree().process_frame
		if not loader._request_active:
			for frame in 3:
				await get_tree().physics_frame
				await get_tree().process_frame
			return
	check(false, "World transition timed out.")

func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	var loader := game.get_node("WorldLoader") as WorldLoader
	await settle(loader)
	check(loader.get_child_count() == 1, "Initial world should be attached.")
	var player := SKEntityManager.instance.get_entity(&"player")
	var teleport := player.get_component("TeleportComponent") as TeleportComponent
	teleport.teleport("demo_world_b", Vector3(2, 1.2, -4))
	await settle(loader)
	check(str(loader.get_child(0).name) == "demo_world_b", "Door travel must commit destination B.")
	check(player.position.x == 2, "Arrival position must be applied after loading.")
	var inventory := player.get_component("InventoryComponent") as InventoryComponent
	inventory.add_money(321, &"test_credits")
	SaveSystem.save("baseline_smoke")
	teleport.teleport("demo_world", Vector3.ZERO)
	await settle(loader)
	inventory.remove_money(300, &"test_credits")
	check(game.request_load_slot("baseline_smoke"), "Valid save must begin loading.")
	await settle(loader)
	check(str(loader.get_child(0).name) == "demo_world_b", "Quick-load must replace the visible world.")
	check(str(GameInfo.world) == "demo_world_b", "World metadata must match the loaded scene.")
	check(inventory.currencies.get(&"test_credits") == 321, "Wallet must survive a disk round trip.")
	check(not get_tree().paused, "Travel must restore input/physics.")
	var invalid := SaveSystem._deserialize(FileAccess.get_file_as_string("user://saves/baseline_smoke.dat"))
	invalid["game_info"]["GameInfo"]["world"] = "nonexistent_world"
	invalid.erase("checksum")
	var bad_file := FileAccess.open("user://saves/baseline_invalid_world.dat", FileAccess.WRITE)
	bad_file.store_string(SaveSystem._serialize(invalid))
	bad_file.close()
	inventory.remove_money(100, &"test_credits")
	check(not game.request_load_slot("baseline_invalid_world"), "Invalid saved destination must be rejected.")
	check(inventory.currencies.get(&"test_credits") == 221, "Rejected load must not mutate the wallet.")
	check(str(loader.get_child(0).name) == "demo_world_b", "Rejected load must keep the active scene.")
	# A known destination can also fail during preparation. Use a valid Resource
	# of the wrong type so the threaded loader reaches its failure path.
	ResourceSaver.save(Resource.new(), "user://baseline_not_scene.tres")
	loader.world_paths["broken_world"] = "user://baseline_not_scene.tres"
	invalid["game_info"]["GameInfo"]["world"] = "broken_world"
	bad_file = FileAccess.open("user://saves/baseline_invalid_world.dat", FileAccess.WRITE)
	bad_file.store_string(SaveSystem._serialize(invalid))
	bad_file.close()
	check(game.request_load_slot("baseline_invalid_world"), "Known destination should begin preparation.")
	await settle(loader)
	check(inventory.currencies.get(&"test_credits") == 221, "Failed preparation must leave live state unchanged.")
	check(str(loader.get_child(0).name) == "demo_world_b", "Failed preparation must retain the old scene.")
	check(game._pending_save.is_empty(), "Failed preparation must release the pending snapshot.")
	DirAccess.remove_absolute("user://baseline_not_scene.tres")
	DirAccess.remove_absolute("user://saves/baseline_invalid_world.dat")
	DirAccess.remove_absolute("user://saves/baseline_smoke.dat")
	print("EXAMPLE SMOKE: %d failures" % failures)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)
