## Unit tests for the Phase 7 performance optimizations.
## Validates that caching, binary heap, and early-exit behaviors are correct.
## Run with the GUT framework (https://github.com/bitwes/Gut).
extends GutTest


# ── Binary Heap Tests ────────────────────────────────────────────────────────


func test_heap_push_pop_ordering():
	# Verify elements are popped in ascending order (min-heap property).
	var heap: Array = []
	NavMaster._heap_push(heap, 5.0, _make_stub_node("E"))
	NavMaster._heap_push(heap, 1.0, _make_stub_node("A"))
	NavMaster._heap_push(heap, 3.0, _make_stub_node("C"))
	NavMaster._heap_push(heap, 2.0, _make_stub_node("B"))
	NavMaster._heap_push(heap, 4.0, _make_stub_node("D"))

	var result: Array[String] = []
	while not heap.is_empty():
		var entry = NavMaster._heap_pop(heap)
		result.append(entry[1].node_name)

	assert_eq(result, ["A", "B", "C", "D", "E"], "Heap should pop in ascending f-score order")


func test_heap_single_element():
	var heap: Array = []
	NavMaster._heap_push(heap, 42.0, _make_stub_node("only"))
	var entry = NavMaster._heap_pop(heap)
	assert_eq(entry[0], 42.0)
	assert_eq(entry[1].node_name, "only")
	assert_true(heap.is_empty(), "Heap should be empty after popping single element")


func test_heap_duplicate_scores():
	# All elements have the same f-score; all should still be retrievable.
	var heap: Array = []
	for i in range(5):
		NavMaster._heap_push(heap, 1.0, _make_stub_node("n%d" % i))
	var count := 0
	while not heap.is_empty():
		NavMaster._heap_pop(heap)
		count += 1
	assert_eq(count, 5, "All elements with equal scores should be popped")


func test_heap_large_input():
	# Push many elements in reverse order and verify they come out sorted.
	var heap: Array = []
	var n := 100
	for i in range(n, 0, -1):
		NavMaster._heap_push(heap, float(i), _make_stub_node("n%d" % i))
	var prev_f := -1.0
	while not heap.is_empty():
		var entry = NavMaster._heap_pop(heap)
		assert_true(entry[0] >= prev_f, "f-score should be non-decreasing")
		prev_f = entry[0]


# ── GOAP Objectives Dirty Flag Tests ────────────────────────────────────────


func test_goap_objectives_dirty_on_add():
	var goap := GOAPComponent.new()
	goap._objectives_dirty = false
	goap.add_objective({"test": true}, true, 1.0)
	assert_true(goap._objectives_dirty, "Adding objective should mark dirty")
	assert_true(goap._rebuild_plan, "Adding objective should trigger plan rebuild")
	goap.free()


func test_goap_objectives_dirty_on_remove():
	var goap := GOAPComponent.new()
	goap.add_objective({"test": true}, true, 1.0)
	goap._objectives_dirty = false
	goap.remove_objective_by_goals({"test": true})
	assert_true(goap._objectives_dirty, "Removing objective should mark dirty")
	goap.free()


func test_goap_objectives_not_dirty_on_empty_remove():
	var goap := GOAPComponent.new()
	goap._objectives_dirty = false
	goap.remove_objective_by_goals({"nonexistent": true})
	assert_false(goap._objectives_dirty, "Removing non-existent objective should not mark dirty")
	goap.free()


func test_goap_action_cache_rebuild():
	var goap := GOAPComponent.new()
	# After init, cache should be built
	goap._rebuild_action_cache()
	# With no GOAPAction children, cache should be empty
	assert_eq(goap._cached_actions.size(), 0, "Cache should be empty with no action children")
	assert_false(goap._actions_dirty, "Actions dirty flag should be cleared after rebuild")
	goap.free()


# ── Entity Fade Distance Cache Tests ────────────────────────────────────────


func test_entity_fade_distance_cached():
	# Verify that _actor_fade_dist_sq starts at -1 (uncached)
	var entity := SKEntity.new()
	assert_eq(entity._actor_fade_dist_sq, -1.0, "Fade distance should start uncached")
	entity.free()


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_stub_node(n: String) -> NavNode:
	var node := NavNode.new()
	node.node_name = n
	node.position = Vector3.ZERO
	return node
