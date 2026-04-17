## Unit tests for PluginMigrationRegistry.
## Run with the GUT framework (https://github.com/bitwes/Gut).
##
## Verifies that plugin-version migrations run in order, mark progress via
## ProjectSettings, and are skipped when the installed version already matches
## the target.
extends GutTest


const REGISTRY := preload("res://scripts/system/plugin_migration_registry.gd")
const VERSION_KEY := "skelerealms/__installed_version"


func before_each() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "")


func after_each() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "")


# ── Fresh install path ───────────────────────────────────────────────────────


func test_first_install_stamps_current_version_and_runs_nothing() -> void:
	var ran := [false]
	var registry := REGISTRY.new("beta 0.8")
	registry.register("beta 0.6", func(): ran[0] = true)

	var result: bool = registry.run()

	assert_false(result, "Fresh install should not run any migrations.")
	assert_false(ran[0], "Fresh install should not invoke registered migrations.")
	assert_eq(
		ProjectSettings.get_setting(VERSION_KEY),
		"beta 0.8",
		"Fresh install should stamp the current version."
	)


# ── Already-up-to-date path ──────────────────────────────────────────────────


func test_matching_installed_version_is_a_noop() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "beta 0.8")
	var ran := [false]
	var registry := REGISTRY.new("beta 0.8")
	registry.register("beta 0.7", func(): ran[0] = true)

	var result: bool = registry.run()

	assert_false(result, "No-op when installed version == current version.")
	assert_false(ran[0], "Registered migration should not run.")


# ── Single-step upgrade ──────────────────────────────────────────────────────


func test_single_migration_runs_when_version_matches() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "beta 0.7")
	var side_effects := []
	var registry := REGISTRY.new("beta 0.8")
	registry.register("beta 0.7", func(): side_effects.append("0.7->0.8"))

	var result: bool = registry.run()

	assert_true(result, "Run should report at least one migration ran.")
	assert_eq(side_effects, ["0.7->0.8"],
		"The registered migration for 0.7 must execute.")
	assert_eq(
		ProjectSettings.get_setting(VERSION_KEY),
		"beta 0.8",
		"Installed version should advance to the target."
	)


# ── Multi-step upgrade ───────────────────────────────────────────────────────


func test_chain_of_migrations_runs_in_order() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "beta 0.6")
	var order := []
	var registry := REGISTRY.new("beta 0.9")
	registry.register("beta 0.6", func(): order.append("a"))
	registry.register("beta 0.7", func(): order.append("b"))
	registry.register("beta 0.8", func(): order.append("c"))

	var result: bool = registry.run()

	assert_true(result)
	assert_eq(order, ["a", "b", "c"], "Migrations must execute in chain order.")
	assert_eq(
		ProjectSettings.get_setting(VERSION_KEY),
		"beta 0.9",
		"Final version stamp must match the target."
	)


# ── Skipping irrelevant migrations ───────────────────────────────────────────


func test_migrations_before_installed_version_are_skipped() -> void:
	ProjectSettings.set_setting(VERSION_KEY, "beta 0.7")
	var order := []
	var registry := REGISTRY.new("beta 0.8")
	registry.register("beta 0.5", func(): order.append("too old"))
	registry.register("beta 0.6", func(): order.append("also too old"))
	registry.register("beta 0.7", func(): order.append("relevant"))

	registry.run()

	assert_eq(order, ["relevant"],
		"Only migrations whose from-version matches the install cursor should run.")
