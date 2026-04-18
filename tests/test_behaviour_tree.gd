## Unit tests for the Skelerealms Behaviour Tree system.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## The BT classes extend Node and require a scene tree, so these tests use
## add_child/remove_child to wire up the tree manually in each test.
extends GutTest


# ── Helpers ────────────────────────────────────────────────────────────────


## A configurable leaf used by tests.  Returns a caller-supplied status.
class _TestLeaf extends SKBTLeaf:
	var return_status: SKBTNode.Status = SKBTNode.Status.SUCCESS
	var tick_count: int = 0

	func tick(_delta: float, _actor: Node, _blackboard: SKBlackboard) -> Status:
		tick_count += 1
		return return_status


## Build a test blackboard.
func _bb() -> SKBlackboard:
	return SKBlackboard.new()


# ── SKBlackboard ──────────────────────────────────────────────────────────


func test_blackboard_set_and_get() -> void:
	var bb := _bb()
	bb.set_value(&"health", 100)
	assert_eq(bb.get_value(&"health"), 100)


func test_blackboard_get_missing_key_returns_default() -> void:
	var bb := _bb()
	assert_eq(bb.get_value(&"missing", 42), 42)


func test_blackboard_has_value() -> void:
	var bb := _bb()
	assert_false(bb.has_value(&"x"))
	bb.set_value(&"x", "hello")
	assert_true(bb.has_value(&"x"))


func test_blackboard_erase_value() -> void:
	var bb := _bb()
	bb.set_value(&"k", 1)
	var erased := bb.erase_value(&"k")
	assert_true(erased)
	assert_false(bb.has_value(&"k"))
	assert_false(bb.erase_value(&"k"))


func test_blackboard_clear() -> void:
	var bb := _bb()
	bb.set_value(&"a", 1)
	bb.set_value(&"b", 2)
	bb.clear()
	assert_false(bb.has_value(&"a"))
	assert_false(bb.has_value(&"b"))


func test_blackboard_serialize_roundtrip() -> void:
	var bb := _bb()
	bb.set_value(&"score", 99)
	var data := bb.serialize()
	var bb2 := _bb()
	bb2.deserialize(data)
	assert_eq(bb2.get_value(&"score"), 99)


# ── SKBTLeaf ──────────────────────────────────────────────────────────────


func test_leaf_returns_success_by_default() -> void:
	var leaf := SKBTLeaf.new()
	add_child_autofree(leaf)
	assert_eq(leaf.tick(0.016, self, _bb()), SKBTNode.Status.SUCCESS)


# ── SKBTSequence ──────────────────────────────────────────────────────────


func test_sequence_succeeds_when_all_succeed() -> void:
	var seq := SKBTSequence.new()
	var a := _TestLeaf.new()
	var b := _TestLeaf.new()
	seq.add_child(a)
	seq.add_child(b)
	add_child_autofree(seq)
	# Need to rebuild leaves after tree is ready
	seq._rebuild_leaves()

	var bb := _bb()
	# First tick runs a (SUCCESS), advances to b — returns RUNNING
	var status := seq.tick(0.016, self, bb)
	assert_eq(status, SKBTNode.Status.RUNNING)
	# Second tick runs b (SUCCESS) — sequence complete
	status = seq.tick(0.016, self, bb)
	assert_eq(status, SKBTNode.Status.SUCCESS)


func test_sequence_fails_on_first_failure() -> void:
	var seq := SKBTSequence.new()
	var a := _TestLeaf.new()
	a.return_status = SKBTNode.Status.FAILURE
	var b := _TestLeaf.new()
	seq.add_child(a)
	seq.add_child(b)
	add_child_autofree(seq)
	seq._rebuild_leaves()

	assert_eq(seq.tick(0.016, self, _bb()), SKBTNode.Status.FAILURE)
	assert_eq(b.tick_count, 0, "Second leaf should not have been ticked.")


# ── SKBTSelector ──────────────────────────────────────────────────────────


func test_selector_succeeds_on_first_success() -> void:
	var sel := SKBTSelector.new()
	var a := _TestLeaf.new()
	a.return_status = SKBTNode.Status.FAILURE
	var b := _TestLeaf.new()
	b.return_status = SKBTNode.Status.SUCCESS
	sel.add_child(a)
	sel.add_child(b)
	add_child_autofree(sel)
	sel._rebuild_leaves()

	var bb := _bb()
	# First tick: a fails, advance — RUNNING
	var status := sel.tick(0.016, self, bb)
	assert_eq(status, SKBTNode.Status.RUNNING)
	# Second tick: b succeeds
	status = sel.tick(0.016, self, bb)
	assert_eq(status, SKBTNode.Status.SUCCESS)


func test_selector_fails_when_all_fail() -> void:
	var sel := SKBTSelector.new()
	var a := _TestLeaf.new()
	a.return_status = SKBTNode.Status.FAILURE
	var b := _TestLeaf.new()
	b.return_status = SKBTNode.Status.FAILURE
	sel.add_child(a)
	sel.add_child(b)
	add_child_autofree(sel)
	sel._rebuild_leaves()

	var bb := _bb()
	sel.tick(0.016, self, bb) # a fails, advance
	var status := sel.tick(0.016, self, bb) # b fails
	assert_eq(status, SKBTNode.Status.FAILURE)


# ── SKBTParallel ──────────────────────────────────────────────────────────


func test_parallel_success_on_all() -> void:
	var par := SKBTParallel.new()
	par.policy = SKBTParallel.ParallelPolicy.SUCCESS_ON_ALL
	var a := _TestLeaf.new()
	var b := _TestLeaf.new()
	par.add_child(a)
	par.add_child(b)
	add_child_autofree(par)
	par._rebuild_leaves()

	assert_eq(par.tick(0.016, self, _bb()), SKBTNode.Status.SUCCESS)


func test_parallel_fails_if_any_child_fails() -> void:
	var par := SKBTParallel.new()
	par.policy = SKBTParallel.ParallelPolicy.SUCCESS_ON_ALL
	var a := _TestLeaf.new()
	a.return_status = SKBTNode.Status.FAILURE
	var b := _TestLeaf.new()
	par.add_child(a)
	par.add_child(b)
	add_child_autofree(par)
	par._rebuild_leaves()

	assert_eq(par.tick(0.016, self, _bb()), SKBTNode.Status.FAILURE)


func test_parallel_success_on_one() -> void:
	var par := SKBTParallel.new()
	par.policy = SKBTParallel.ParallelPolicy.SUCCESS_ON_ONE
	var a := _TestLeaf.new()
	a.return_status = SKBTNode.Status.RUNNING
	var b := _TestLeaf.new()
	b.return_status = SKBTNode.Status.SUCCESS
	par.add_child(a)
	par.add_child(b)
	add_child_autofree(par)
	par._rebuild_leaves()

	assert_eq(par.tick(0.016, self, _bb()), SKBTNode.Status.SUCCESS)


# ── SKBTRandom ────────────────────────────────────────────────────────────


func test_random_picks_one_child() -> void:
	var rnd := SKBTRandom.new()
	var a := _TestLeaf.new()
	var b := _TestLeaf.new()
	rnd.add_child(a)
	rnd.add_child(b)
	add_child_autofree(rnd)
	rnd._rebuild_leaves()

	rnd.tick(0.016, self, _bb())
	assert_eq(a.tick_count + b.tick_count, 1, "Exactly one child should have been ticked.")


# ── SKBTInverter ──────────────────────────────────────────────────────────


func test_inverter_flips_success() -> void:
	var inv := SKBTInverter.new()
	var child := _TestLeaf.new()
	child.return_status = SKBTNode.Status.SUCCESS
	inv.add_child(child)
	add_child_autofree(inv)
	inv.leaf = child

	assert_eq(inv.tick(0.016, self, _bb()), SKBTNode.Status.FAILURE)


func test_inverter_flips_failure() -> void:
	var inv := SKBTInverter.new()
	var child := _TestLeaf.new()
	child.return_status = SKBTNode.Status.FAILURE
	inv.add_child(child)
	add_child_autofree(inv)
	inv.leaf = child

	assert_eq(inv.tick(0.016, self, _bb()), SKBTNode.Status.SUCCESS)


func test_inverter_passes_running() -> void:
	var inv := SKBTInverter.new()
	var child := _TestLeaf.new()
	child.return_status = SKBTNode.Status.RUNNING
	inv.add_child(child)
	add_child_autofree(inv)
	inv.leaf = child

	assert_eq(inv.tick(0.016, self, _bb()), SKBTNode.Status.RUNNING)


# ── SKBTAlwaysSucceed ─────────────────────────────────────────────────────


func test_always_succeed_forces_success() -> void:
	var dec := SKBTAlwaysSucceed.new()
	var child := _TestLeaf.new()
	child.return_status = SKBTNode.Status.FAILURE
	dec.add_child(child)
	add_child_autofree(dec)
	dec.leaf = child

	assert_eq(dec.tick(0.016, self, _bb()), SKBTNode.Status.SUCCESS)


# ── SKBTAlwaysFail ────────────────────────────────────────────────────────


func test_always_fail_forces_failure() -> void:
	var dec := SKBTAlwaysFail.new()
	var child := _TestLeaf.new()
	child.return_status = SKBTNode.Status.SUCCESS
	dec.add_child(child)
	add_child_autofree(dec)
	dec.leaf = child

	assert_eq(dec.tick(0.016, self, _bb()), SKBTNode.Status.FAILURE)


# ── SKBTRepeat ────────────────────────────────────────────────────────────


func test_repeat_runs_child_n_times() -> void:
	var rep := SKBTRepeat.new()
	rep.repetitions = 3
	rep.on_limit = SKBTNode.Status.SUCCESS
	var child := _TestLeaf.new()
	rep.add_child(child)
	add_child_autofree(rep)
	rep.leaf = child

	var bb := _bb()
	# Should return RUNNING for first 2 successful ticks
	assert_eq(rep.tick(0.016, self, bb), SKBTNode.Status.RUNNING)
	assert_eq(rep.tick(0.016, self, bb), SKBTNode.Status.RUNNING)
	# Third tick should return on_limit (SUCCESS)
	assert_eq(rep.tick(0.016, self, bb), SKBTNode.Status.SUCCESS)
	assert_eq(child.tick_count, 3)


# ── SKBTLimiter ───────────────────────────────────────────────────────────


func test_limiter_blocks_after_limit() -> void:
	var lim := SKBTLimiter.new()
	lim.limit = 2
	lim.on_limit = SKBTNode.Status.FAILURE
	var child := _TestLeaf.new()
	lim.add_child(child)
	add_child_autofree(lim)
	lim.leaf = child

	var bb := _bb()
	assert_eq(lim.tick(0.016, self, bb), SKBTNode.Status.SUCCESS) # run 1
	assert_eq(lim.tick(0.016, self, bb), SKBTNode.Status.SUCCESS) # run 2
	assert_eq(lim.tick(0.016, self, bb), SKBTNode.Status.FAILURE) # blocked
	assert_eq(child.tick_count, 2, "Child should have ticked exactly twice.")

	lim.reset()
	assert_eq(lim.tick(0.016, self, bb), SKBTNode.Status.SUCCESS) # allowed again
