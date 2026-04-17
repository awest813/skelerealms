## Unit tests for Coven disposition thresholds.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Coven is a pure Resource with no scene-tree dependencies, so all tests run
## headless.
extends GutTest


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_coven(hostile: int = -25, friendly: int = 25, allied: int = 60) -> Coven:
	var c := Coven.new()
	c.coven_id = &"test_coven"
	c.hostile_below = hostile
	c.friendly_at = friendly
	c.allied_at = allied
	return c


# ── Default thresholds ──────────────────────────────────────────────────────


func test_hostile_below_default_threshold() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(-30), Coven.Disposition.HOSTILE)


func test_neutral_at_negative_above_hostile() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(-20), Coven.Disposition.NEUTRAL)


func test_neutral_at_zero() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(0), Coven.Disposition.NEUTRAL)


func test_neutral_just_below_friendly() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(24), Coven.Disposition.NEUTRAL)


func test_friendly_at_threshold() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(25), Coven.Disposition.FRIENDLY)


func test_friendly_between_thresholds() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(50), Coven.Disposition.FRIENDLY)


func test_allied_at_threshold() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(60), Coven.Disposition.ALLIED)


func test_allied_above_threshold() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(100), Coven.Disposition.ALLIED)


# ── Boundary values ─────────────────────────────────────────────────────────


func test_exactly_at_hostile_boundary_is_neutral() -> void:
	var c := _make_coven()
	# hostile_below is -25 → opinion == -25 is NOT hostile (it must be < -25)
	assert_eq(c.get_disposition(-25), Coven.Disposition.NEUTRAL)


func test_one_below_hostile_boundary_is_hostile() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(-26), Coven.Disposition.HOSTILE)


func test_one_below_friendly_is_neutral() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(24), Coven.Disposition.NEUTRAL)


func test_one_below_allied_is_friendly() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition(59), Coven.Disposition.FRIENDLY)


# ── Custom thresholds ───────────────────────────────────────────────────────


func test_custom_hostile_threshold() -> void:
	var c := _make_coven(-50, 25, 60)
	assert_eq(c.get_disposition(-30), Coven.Disposition.NEUTRAL,
		"With hostile_below=-50, opinion -30 should be neutral.")
	assert_eq(c.get_disposition(-51), Coven.Disposition.HOSTILE)


func test_custom_friendly_threshold() -> void:
	var c := _make_coven(-25, 10, 60)
	assert_eq(c.get_disposition(10), Coven.Disposition.FRIENDLY,
		"With friendly_at=10, opinion 10 should be friendly.")
	assert_eq(c.get_disposition(9), Coven.Disposition.NEUTRAL)


func test_custom_allied_threshold() -> void:
	var c := _make_coven(-25, 25, 80)
	assert_eq(c.get_disposition(79), Coven.Disposition.FRIENDLY,
		"With allied_at=80, opinion 79 should be friendly.")
	assert_eq(c.get_disposition(80), Coven.Disposition.ALLIED)


func test_very_strict_thresholds() -> void:
	# hostile_below = 0 means any negative is hostile
	# friendly_at = 50, allied_at = 90
	var c := _make_coven(0, 50, 90)
	assert_eq(c.get_disposition(-1), Coven.Disposition.HOSTILE)
	assert_eq(c.get_disposition(0), Coven.Disposition.NEUTRAL)
	assert_eq(c.get_disposition(49), Coven.Disposition.NEUTRAL)
	assert_eq(c.get_disposition(50), Coven.Disposition.FRIENDLY)
	assert_eq(c.get_disposition(89), Coven.Disposition.FRIENDLY)
	assert_eq(c.get_disposition(90), Coven.Disposition.ALLIED)


# ── Disposition name ─────────────────────────────────────────────────────────


func test_disposition_name_hostile() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition_name(-30), "hostile")


func test_disposition_name_neutral() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition_name(0), "neutral")


func test_disposition_name_friendly() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition_name(30), "friendly")


func test_disposition_name_allied() -> void:
	var c := _make_coven()
	assert_eq(c.get_disposition_name(70), "allied")


# ── Coven opinions ───────────────────────────────────────────────────────────


func test_get_coven_opinions_returns_defaults_for_unknown() -> void:
	var c := _make_coven()
	c.other_coven_opinions = {}
	var opinions := c.get_coven_opinions([&"unknown_coven"])
	assert_eq(opinions.size(), 1)
	assert_eq(opinions[0], 0)


func test_get_coven_opinions_returns_known_values() -> void:
	var c := _make_coven()
	c.other_coven_opinions = {&"ally_coven": 50, &"enemy_coven": -40}
	var opinions := c.get_coven_opinions([&"ally_coven", &"enemy_coven", &"neutral_coven"])
	assert_eq(opinions.size(), 3)
	assert_eq(opinions[0], 50)
	assert_eq(opinions[1], -40)
	assert_eq(opinions[2], 0)
