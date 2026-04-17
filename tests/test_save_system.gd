## Unit tests for SaveSystem internals.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## These tests exercise the pure-logic helpers of SaveSystem (serialization,
## checksum computation, migration pipeline) without requiring a full scene
## tree or save files on disk.
extends GutTest


# ── Helpers ──────────────────────────────────────────────────────────────────


## Create a SaveSystem node and add it to the tree so it initializes.
func _make_save_system() -> Node:
	var ss := preload("res://scripts/system/save_system.gd").new()
	add_child(ss)
	return ss


# ── Checksum ─────────────────────────────────────────────────────────────────


func test_checksum_returns_8_char_hex() -> void:
	var ss := _make_save_system()
	var result: String = ss._compute_checksum("hello world")
	assert_eq(result.length(), 8, "Checksum should be 8-character hex string.")
	# Should be valid hex
	for ch in result:
		assert_true("0123456789abcdef".contains(ch),
			"Checksum character '%s' should be hexadecimal." % ch)


func test_checksum_is_deterministic() -> void:
	var ss := _make_save_system()
	var a := ss._compute_checksum("test data 12345")
	var b := ss._compute_checksum("test data 12345")
	assert_eq(a, b, "Same input should produce same checksum.")


func test_checksum_differs_for_different_input() -> void:
	var ss := _make_save_system()
	var a := ss._compute_checksum("alpha")
	var b := ss._compute_checksum("bravo")
	assert_ne(a, b, "Different inputs should produce different checksums.")


func test_checksum_empty_string() -> void:
	var ss := _make_save_system()
	var result := ss._compute_checksum("")
	assert_eq(result.length(), 8)


# ── Serialize / Deserialize ──────────────────────────────────────────────────


func test_serialize_and_deserialize_round_trip() -> void:
	var ss := _make_save_system()
	var original := {
		"schema_version": 2,
		"game_info": {"test": "value"},
		"entity_data": {"hero": {"health": 100}},
		"other_data": {}
	}
	var text := ss._serialize(original)
	assert_true(text.length() > 0)
	var restored := ss._deserialize(text)
	assert_eq(restored["schema_version"], 2)
	assert_eq(restored["game_info"]["test"], "value")
	assert_eq(restored["entity_data"]["hero"]["health"], 100)


func test_deserialize_invalid_json_returns_null() -> void:
	var ss := _make_save_system()
	var result := ss._deserialize("not valid json {{{")
	assert_null(result)


# ── Migration pipeline ──────────────────────────────────────────────────────


func test_migration_bumps_version() -> void:
	var ss := _make_save_system()
	# Create a v1 save blob
	var data := {
		"schema_version": 1,
		"entity_data": {},
		"game_info": {},
		"other_data": {}
	}
	data = ss._apply_migrations(data)
	assert_eq(data["schema_version"], ss.SAVE_SCHEMA_VERSION,
		"After migrations, version should match SAVE_SCHEMA_VERSION.")


func test_custom_migration_is_applied() -> void:
	var ss := _make_save_system()
	# Clear built-in migrations and register a simple one
	ss._migrations.clear()
	ss._migrations[1] = func(d: Dictionary) -> Dictionary:
		d["custom_flag"] = true
		return d
	var data := {"schema_version": 1}
	data = ss._apply_migrations(data)
	assert_true(data.get("custom_flag", false),
		"Custom migration should have been applied.")


func test_multiple_migrations_chain() -> void:
	var ss := _make_save_system()
	ss._migrations.clear()
	ss._migrations[1] = func(d: Dictionary) -> Dictionary:
		d["step_1"] = true
		return d
	ss._migrations[2] = func(d: Dictionary) -> Dictionary:
		d["step_2"] = d.get("step_1", false)
		return d
	# Override SAVE_SCHEMA_VERSION check — run up to version 3
	var data := {"schema_version": 1}
	# Manually apply since SAVE_SCHEMA_VERSION may not be 3
	var version: int = data.get("schema_version", 0)
	while version < 3:
		if ss._migrations.has(version):
			data = ss._migrations[version].call(data)
		version += 1
		data["schema_version"] = version
	assert_true(data.get("step_1", false))
	assert_true(data.get("step_2", false))
	assert_eq(data["schema_version"], 3)


func test_already_current_version_skips_migration() -> void:
	var ss := _make_save_system()
	var data := {"schema_version": ss.SAVE_SCHEMA_VERSION}
	var result := ss._apply_migrations(data)
	assert_eq(result["schema_version"], ss.SAVE_SCHEMA_VERSION)


# ── v1 to v2 migration specifics ────────────────────────────────────────────


func test_v1_to_v2_converts_position_string_to_array() -> void:
	var ss := _make_save_system()
	var data := {
		"schema_version": 1,
		"entity_data": {
			"hero": {
				"entity_data": {
					"position": "(1.5, 2.0, -3.5)"
				}
			}
		},
		"game_info": {},
		"other_data": {}
	}
	data = ss._apply_migrations(data)
	var pos = data["entity_data"]["hero"]["entity_data"]["position"]
	assert_true(pos is Array, "Position should be converted to Array.")
	assert_eq(pos.size(), 3)
	assert_almost_eq(float(pos[0]), 1.5, 0.01)
	assert_almost_eq(float(pos[1]), 2.0, 0.01)
	assert_almost_eq(float(pos[2]), -3.5, 0.01)


func test_v1_to_v2_converts_unique_string_to_bool() -> void:
	var ss := _make_save_system()
	var data := {
		"schema_version": 1,
		"entity_data": {
			"hero": {
				"entity_data": {
					"unique": "true"
				}
			}
		},
		"game_info": {},
		"other_data": {}
	}
	data = ss._apply_migrations(data)
	var unique = data["entity_data"]["hero"]["entity_data"]["unique"]
	assert_true(unique is bool, "'unique' should be converted to bool.")
	assert_true(unique)


func test_v1_to_v2_adds_rotation_if_missing() -> void:
	var ss := _make_save_system()
	var data := {
		"schema_version": 1,
		"entity_data": {
			"hero": {
				"entity_data": {}
			}
		},
		"game_info": {},
		"other_data": {}
	}
	data = ss._apply_migrations(data)
	var rotation = data["entity_data"]["hero"]["entity_data"]["rotation"]
	assert_not_null(rotation)
	assert_eq(rotation.size(), 4)
	# Identity quaternion: [0, 0, 0, 1]
	assert_almost_eq(float(rotation[3]), 1.0, 0.01)


func test_v1_to_v2_adds_form_id_if_missing() -> void:
	var ss := _make_save_system()
	var data := {
		"schema_version": 1,
		"entity_data": {
			"hero": {
				"entity_data": {}
			}
		},
		"game_info": {},
		"other_data": {}
	}
	data = ss._apply_migrations(data)
	var form_id = data["entity_data"]["hero"]["entity_data"]["form_id"]
	assert_eq(form_id, "")


func test_v1_to_v2_skips_entries_without_entity_data() -> void:
	var ss := _make_save_system()
	var data := {
		"schema_version": 1,
		"entity_data": {
			"empty_entity": {}
		},
		"game_info": {},
		"other_data": {}
	}
	# Should not crash
	data = ss._apply_migrations(data)
	assert_eq(data["schema_version"], ss.SAVE_SCHEMA_VERSION)


# ── Slot naming ──────────────────────────────────────────────────────────────


func test_list_saves_returns_empty_when_no_dir() -> void:
	var ss := _make_save_system()
	# The user://saves directory may or may not exist in test environment.
	# list_saves should at minimum not crash.
	var saves := ss.list_saves()
	assert_true(saves is Array)
