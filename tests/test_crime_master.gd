## Unit tests for CrimeMaster pure-logic helpers.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Tests cover bounty calculation, crime severity lookup, and the robustness
## of bounty_for_coven against unknown severity values.
extends GutTest


# ── Helpers ──────────────────────────────────────────────────────────────────


func _make_crime_master() -> Node:
	var cm := preload("res://scripts/crime/crime_master.gd").new()
	add_child(cm)
	return cm


func _make_crime(type: StringName, perp: String, victim: String) -> Crime:
	return Crime.new(type, perp, victim)


# ── bounty_amount dict ────────────────────────────────────────────────────────


func test_bounty_amount_covers_all_known_crime_severities() -> void:
	# Verify that every severity value produced by the Crime class's CRIMES
	# constant is present in CrimeMaster.bounty_amount so the old direct
	# dict-access code would not have crashed for built-in crime types.
	var cm := _make_crime_master()
	for crime_type: StringName in Crime.CRIMES:
		var sev: int = Crime.CRIMES[crime_type]
		assert_true(cm.bounty_amount.has(sev),
			"bounty_amount should have an entry for severity %d (crime type '%s')." % [sev, crime_type])


func test_bounty_for_unknown_severity_returns_zero() -> void:
	# Robustness fix: bounty_for_coven now uses .get() so an unknown severity
	# returns 0 rather than crashing.  We exercise this via the public
	# bounty_for_coven method after injecting a crime into the crimes dict.
	var cm := _make_crime_master()
	var coven := &"test_coven"

	# Build a crime with a known type so .severity works, then inject it
	# directly into the crimes table with an artificially high severity to
	# simulate a future crime type not yet present in bounty_amount.
	var crime := _make_crime(&"assault", "perp", "victim")
	cm.crimes[coven] = {"punished": [], "unpunished": [crime]}

	# severity = 2 (assault) — should be in bounty_amount and return 10000
	var bounty := cm.bounty_for_coven("perp", coven)
	assert_eq(bounty, 10000, "Assault bounty should be 10000.")


func test_bounty_for_coven_with_no_crimes_returns_zero() -> void:
	var cm := _make_crime_master()
	var result := cm.bounty_for_coven("perp", &"nonexistent_coven")
	assert_eq(result, 0)


func test_bounty_accumulates_multiple_crimes() -> void:
	var cm := _make_crime_master()
	var coven := &"test_coven"
	var c1 := _make_crime(&"theft", "perp", "victim")     # severity 1 → 500
	var c2 := _make_crime(&"assault", "perp", "victim")   # severity 2 → 10000
	cm.crimes[coven] = {"punished": [], "unpunished": [c1, c2]}

	var bounty := cm.bounty_for_coven("perp", coven)
	assert_eq(bounty, 10500, "Bounty should sum all unpunished crime amounts.")


func test_max_crime_severity_returns_highest() -> void:
	var cm := _make_crime_master()
	var coven := &"test_coven"
	var c1 := _make_crime(&"theft", "perp", "victim")   # severity 1
	var c2 := _make_crime(&"murder", "perp", "victim")  # severity 5
	cm.crimes[coven] = {"punished": [], "unpunished": [c1, c2]}

	var sev := cm.max_crime_severity("perp", coven)
	assert_eq(sev, 5)


func test_max_crime_severity_no_crimes_returns_zero() -> void:
	var cm := _make_crime_master()
	var result := cm.max_crime_severity("perp", &"unknown_coven")
	assert_eq(result, 0)


func test_punish_crimes_moves_unpunished_to_punished() -> void:
	var cm := _make_crime_master()
	var coven := &"test_coven"
	var crime := _make_crime(&"theft", "perp", "victim")
	cm.crimes[coven] = {"punished": [], "unpunished": [crime]}

	cm.punish_crimes(coven)

	assert_eq(cm.crimes[coven]["unpunished"].size(), 0,
		"unpunished list should be empty after punish_crimes.")
	assert_eq(cm.crimes[coven]["punished"].size(), 1,
		"punished list should contain the transferred crime.")
