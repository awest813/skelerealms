## Tests for the loot table system: SKLTItemChance, SKLTWeightedPool, and SKLTWeightedItem.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## SKLootTable, SKLootTableItem, SKLTWeightedPool, and SKLTWeightedItem are pure Node/RefCounted
## classes with no scene-tree dependencies beyond parenting, so they run headless.
extends GutTest


# ── Helpers ───────────────────────────────────────────────────────────────────


## Build a minimal PackedScene so SKLTWeightedItem.resolve() returns a non-empty result.
func _make_packed_scene() -> PackedScene:
	var root := Node.new()
	root.name = "Item"
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _make_weighted_item(weight: float, scene: PackedScene = null) -> SKLTWeightedItem:
	var wi: SKLTWeightedItem = preload("res://scripts/loottable/items/lt_weighted_item.gd").new()
	wi.weight = weight
	wi.data = scene if scene != null else _make_packed_scene()
	return wi


func _make_weighted_pool(picks: int = 1, allow_duplicates: bool = false) -> SKLTWeightedPool:
	var pool: SKLTWeightedPool = preload("res://scripts/loottable/items/lt_weighted_pool.gd").new()
	pool.picks = picks
	pool.allow_duplicates = allow_duplicates
	return pool


# ── SKLTItemChance ────────────────────────────────────────────────────────────


func test_itemchance_always_drops_at_chance_one() -> void:
	var node: SKLTItemChance = preload("res://scripts/loottable/items/lt_itemchance.gd").new()
	node.item = _make_packed_scene()
	node.chance = 1.0
	add_child(node)
	for _i in 20:
		var result := node.resolve()
		assert_eq(result.items.size(), 1,
			"chance=1.0 should always produce an item.")
	node.queue_free()


func test_itemchance_never_drops_at_chance_zero() -> void:
	var node: SKLTItemChance = preload("res://scripts/loottable/items/lt_itemchance.gd").new()
	node.item = _make_packed_scene()
	node.chance = 0.0
	add_child(node)
	for _i in 20:
		var result := node.resolve()
		assert_eq(result.items.size(), 0,
			"chance=0.0 should never produce an item.")
	node.queue_free()


# ── SKLTWeightedItem ──────────────────────────────────────────────────────────


func test_weighted_item_resolves_its_scene() -> void:
	var ps := _make_packed_scene()
	var wi := _make_weighted_item(1.0, ps)
	add_child(wi)
	var result := wi.resolve()
	assert_eq(result.items.size(), 1, "SKLTWeightedItem should resolve to its scene.")
	assert_eq(result.items[0], ps)
	wi.queue_free()


func test_weighted_item_with_null_data_resolves_empty() -> void:
	var wi: SKLTWeightedItem = preload("res://scripts/loottable/items/lt_weighted_item.gd").new()
	wi.weight = 1.0
	wi.data = null
	add_child(wi)
	var result := wi.resolve()
	assert_eq(result.items.size(), 0, "Null data should produce an empty result.")
	wi.queue_free()


# ── SKLTWeightedPool ──────────────────────────────────────────────────────────


func test_weighted_pool_empty_returns_empty() -> void:
	var pool := _make_weighted_pool()
	add_child(pool)
	var result := pool.resolve()
	assert_eq(result.items.size(), 0, "Empty pool should return empty result.")
	pool.queue_free()


func test_weighted_pool_single_pick_returns_one_item() -> void:
	var pool := _make_weighted_pool(1)
	add_child(pool)
	var wi1 := _make_weighted_item(1.0)
	var wi2 := _make_weighted_item(1.0)
	pool.add_child(wi1)
	pool.add_child(wi2)
	var result := pool.resolve()
	assert_eq(result.items.size(), 1, "picks=1 should return exactly one item.")
	pool.queue_free()


func test_weighted_pool_picks_all_without_duplicates() -> void:
	var pool := _make_weighted_pool(3, false)
	add_child(pool)
	var wi1 := _make_weighted_item(1.0, _make_packed_scene())
	var wi2 := _make_weighted_item(1.0, _make_packed_scene())
	var wi3 := _make_weighted_item(1.0, _make_packed_scene())
	pool.add_child(wi1)
	pool.add_child(wi2)
	pool.add_child(wi3)
	var result := pool.resolve()
	assert_eq(result.items.size(), 3,
		"picks=3 with 3 unique items and no duplicates should yield all 3.")
	pool.queue_free()


func test_weighted_pool_no_duplicates_clamps_to_pool_size() -> void:
	var pool := _make_weighted_pool(10, false)
	add_child(pool)
	pool.add_child(_make_weighted_item(1.0))
	pool.add_child(_make_weighted_item(1.0))
	var result := pool.resolve()
	assert_eq(result.items.size(), 2,
		"picks > pool size with allow_duplicates=false should be clamped to pool size.")
	pool.queue_free()


func test_weighted_pool_allows_duplicates() -> void:
	var pool := _make_weighted_pool(5, true)
	add_child(pool)
	pool.add_child(_make_weighted_item(1.0))
	var result := pool.resolve()
	assert_eq(result.items.size(), 5,
		"allow_duplicates=true should allow picking the same item multiple times.")
	pool.queue_free()


func test_weighted_pool_zero_weight_items_excluded() -> void:
	var pool := _make_weighted_pool(1)
	add_child(pool)
	var wi_zero := _make_weighted_item(0.0)
	var wi_valid := _make_weighted_item(1.0)
	pool.add_child(wi_zero)
	pool.add_child(wi_valid)
	for _i in 20:
		var result := pool.resolve()
		assert_eq(result.items[0], wi_valid.data,
			"Items with weight 0 must never be selected.")
	pool.queue_free()


func test_weighted_pool_high_weight_selected_more_often() -> void:
	## Statistical test: a 10:1 weight ratio should heavily favour the heavier item.
	var pool := _make_weighted_pool(1)
	add_child(pool)
	var heavy_scene := _make_packed_scene()
	var light_scene := _make_packed_scene()
	var heavy := _make_weighted_item(10.0, heavy_scene)
	var light := _make_weighted_item(1.0, light_scene)
	pool.add_child(heavy)
	pool.add_child(light)

	var heavy_count: int = 0
	var trials: int = 200
	for _i in trials:
		var result := pool.resolve()
		if result.items.size() > 0 and result.items[0] == heavy_scene:
			heavy_count += 1

	# With a 10:1 ratio over 200 trials the heavy item should win > 70% of the time.
	assert_true(heavy_count > 140,
		"High-weight item should dominate selection (got %d/%d)." % [heavy_count, trials])
	pool.queue_free()


# ── LootTableResult.size() ────────────────────────────────────────────────────


func test_loot_table_result_size_counts_items_and_entities() -> void:
	var r := SKLootTable.LootTableResult.new(
		[_make_packed_scene(), _make_packed_scene()],
		{},
		[&"npc_1"]
	)
	assert_eq(r.size(), 3, "size() should count items + entities.")


func test_loot_table_result_size_empty_is_zero() -> void:
	var r := SKLootTable.LootTableResult.new()
	assert_eq(r.size(), 0, "Empty result should have size 0.")
