## Unit tests for Network graph edge cost computation.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Network, NetworkPoint, and NetworkEdge are pure Resource classes with no
## scene-tree dependencies, so all tests run headless.
extends GutTest


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_network() -> Network:
	return Network.new()


## Build a simple triangle network: A—B—C—A with given costs.
func _make_triangle(cost_ab: float = 1.0, cost_bc: float = 1.0, cost_ca: float = 1.0) -> Dictionary:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	var c := net.add_point(Vector3(5, 0, 8))
	net.add_edge(a, b, cost_ab)
	net.add_edge(b, c, cost_bc)
	net.add_edge(c, a, cost_ca)
	return {"net": net, "a": a, "b": b, "c": c}


## Build a simple linear network: A—B—C with given costs.
func _make_linear(cost_ab: float = 2.0, cost_bc: float = 3.0) -> Dictionary:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(5, 0, 0))
	var c := net.add_point(Vector3(10, 0, 0))
	net.add_edge(a, b, cost_ab)
	net.add_edge(b, c, cost_bc)
	return {"net": net, "a": a, "b": b, "c": c}


# ── Basic graph operations ──────────────────────────────────────────────────


func test_add_point_creates_point() -> void:
	var net := _make_network()
	var pt := net.add_point(Vector3(1, 2, 3))
	assert_not_null(pt)
	assert_eq(net.points.size(), 1)


func test_add_edge_creates_edge() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(5, 0, 0))
	var edge := net.add_edge(a, b, 3.0)
	assert_not_null(edge)
	assert_eq(edge.cost, 3.0)
	assert_eq(net.edges.size(), 1)


func test_add_duplicate_bidirectional_edge_returns_null() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(5, 0, 0))
	net.add_edge(a, b, 1.0)
	var dup := net.add_edge(a, b, 2.0)
	assert_null(dup, "Duplicate bidirectional edge should return null.")
	assert_eq(net.edges.size(), 1)


func test_find_edge_returns_existing_edge() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(5, 0, 0))
	net.add_edge(a, b, 4.0)
	var found := net.find_edge(a, b)
	assert_not_null(found)
	assert_eq(found.cost, 4.0)


func test_find_edge_returns_null_for_missing() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(5, 0, 0))
	assert_null(net.find_edge(a, b))


func test_remove_point_removes_associated_edges() -> void:
	var data := _make_triangle()
	var net: Network = data["net"]
	assert_eq(net.points.size(), 3)
	assert_eq(net.edges.size(), 3)
	net.remove_point(data["b"])
	assert_eq(net.points.size(), 2)
	# Removing B should remove edges A-B and B-C, leaving only C-A
	assert_eq(net.edges.size(), 1)


# ── Dissolve point — cost summing ───────────────────────────────────────────


func test_dissolve_point_sums_edge_costs() -> void:
	var data := _make_linear(2.0, 3.0)
	var net: Network = data["net"]
	# Dissolving B from A—B(2)—C(3) should create A—C with cost 2+3 = 5
	net.dissolve_point(data["b"])
	assert_eq(net.points.size(), 2, "After dissolving B, 2 points should remain.")
	assert_eq(net.edges.size(), 1, "After dissolving B, 1 edge should remain.")
	var edge := net.find_edge(data["a"], data["c"])
	assert_not_null(edge, "Edge A-C should exist after dissolving B.")
	assert_almost_eq(edge.cost, 5.0, 0.001,
		"Dissolved edge cost should be sum of removed edges (2 + 3 = 5).")


func test_dissolve_point_with_single_connection_just_removes() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(5, 0, 0))
	net.add_edge(a, b, 10.0)
	# Dissolving a point with only one connection should just remove it
	net.dissolve_point(b)
	assert_eq(net.points.size(), 1)
	assert_eq(net.edges.size(), 0)


func test_dissolve_point_in_triangle_creates_correct_costs() -> void:
	var data := _make_triangle(2.0, 4.0, 6.0)
	var net: Network = data["net"]
	# Dissolving B from triangle A—B(2)—C(4), A—C(6)
	# B has edges to A (cost 2) and C (cost 4)
	# Dissolving B should reconnect A-C with cost 2+4=6
	# But A-C already exists (cost 6), so the new edge may be skipped due to bidirectional check
	net.dissolve_point(data["b"])
	assert_eq(net.points.size(), 2)
	# The existing A-C edge should remain (add_edge returns null for duplicates)
	var edge := net.find_edge(data["a"], data["c"])
	assert_not_null(edge)


# ── Subdivide edge — cost halving ───────────────────────────────────────────


func test_subdivide_edge_halves_cost() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	var edge := net.add_edge(a, b, 8.0)
	var mid := net.subdivide_edge(edge)
	assert_not_null(mid, "Subdivide should return the new midpoint.")
	assert_eq(net.points.size(), 3, "After subdivide, 3 points should exist.")
	assert_eq(net.edges.size(), 2, "After subdivide, 2 edges should exist.")
	# Each new edge should have half the cost
	var edge_a_mid := net.find_edge(a, mid)
	var edge_mid_b := net.find_edge(mid, b)
	assert_not_null(edge_a_mid)
	assert_not_null(edge_mid_b)
	assert_almost_eq(edge_a_mid.cost, 4.0, 0.001, "Edge A-mid should have half cost.")
	assert_almost_eq(edge_mid_b.cost, 4.0, 0.001, "Edge mid-B should have half cost.")


func test_subdivide_preserves_position_midpoint() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	var edge := net.add_edge(a, b, 4.0)
	var mid := net.subdivide_edge(edge)
	assert_almost_eq(mid.position.x, 5.0, 0.001)
	assert_almost_eq(mid.position.y, 0.0, 0.001)
	assert_almost_eq(mid.position.z, 0.0, 0.001)


func test_subdivide_odd_cost_splits_evenly() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3.ZERO)
	var b := net.add_point(Vector3(7, 0, 0))
	var edge := net.add_edge(a, b, 7.0)
	var mid := net.subdivide_edge(edge)
	var e1 := net.find_edge(a, mid)
	var e2 := net.find_edge(mid, b)
	assert_almost_eq(e1.cost, 3.5, 0.001)
	assert_almost_eq(e2.cost, 3.5, 0.001)


# ── Merge points — distance-based cost ──────────────────────────────────────


func test_merge_points_creates_midpoint() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	net.add_edge(a, b, 5.0)
	var merged := net.merge_points(a, b)
	assert_not_null(merged)
	assert_almost_eq(merged.position.x, 5.0, 0.001,
		"Merged point should be at midpoint of A and B.")


func test_merge_points_reconnects_with_distance_cost() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	var c := net.add_point(Vector3(0, 10, 0))
	net.add_edge(a, b, 5.0)
	net.add_edge(a, c, 5.0)
	# Merging A and B: new point at (5, 0, 0)
	# C is at (0, 10, 0), so distance from (5,0,0) to (0,10,0) = sqrt(125) ≈ 11.18
	var merged := net.merge_points(a, b)
	assert_eq(net.points.size(), 2, "After merge: merged point and C.")
	assert_eq(net.edges.size(), 1, "After merge: one edge from merged to C.")
	var edge := net.find_edge(merged, c)
	assert_not_null(edge)
	var expected_dist := merged.position.distance_to(c.position)
	assert_almost_eq(edge.cost, expected_dist, 0.01,
		"Reconnected edge should use distance-based cost.")


func test_merge_removes_old_points() -> void:
	var net := _make_network()
	var a := net.add_point(Vector3(0, 0, 0))
	var b := net.add_point(Vector3(10, 0, 0))
	net.add_edge(a, b, 5.0)
	var merged := net.merge_points(a, b)
	assert_false(net.points.has(a), "Original point A should be removed.")
	assert_false(net.points.has(b), "Original point B should be removed.")
	assert_true(net.points.has(merged), "Merged point should be in the network.")
