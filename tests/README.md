# Integration Tests

This directory contains integration test scripts for Skelerealms' critical systems. The tests are written to be compatible with [GUT (Godot Unit Test)](https://github.com/bitwes/Gut).

## Running the Tests

Use Godot 4.4.1 and GUT 9.4.0. From the repository root:

```powershell
./tools/prepare_example.ps1 -GutPath '<GUT checkout>/addons/gut'
godot --headless --path .local/example --editor --import
godot --headless --path .local/example -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --headless --path .local/example res://smoke_test.tscn
godot --headless --path flight_sandbox -s res://test_flight.gd
```

The generated host resolves plugin paths, test preload paths, and a GUT CLI name collision without modifying the installed dependency. Re-run preparation after source changes. See [baseline repairs](../docs/architecture/baseline_repairs.md) for setup details and validation limitations.

## Test Files

| File | What it tests |
|---|---|
| `test_space_baseline.gd` | World ownership/rollback, hitscan filtering, save round trips and checksums, puppet orientation. |
| `test_quest_graph_engine.gd` | Quest activation, event advancement, graph completion, save/restore snapshots, validation. |
| `test_dialogue_engine.gd` | Dialogue session creation, choice evaluation, condition blocking, effect application, terminal nodes. |
| `test_barter.gd` | `BarterSystem` sell/buy toggling, haggle discount accumulation, `accept_barter` modifier application. |
| `test_coven_disposition.gd` | Coven disposition thresholds (`get_disposition`), boundary values, custom thresholds, disposition names, coven opinions. |
| `test_network_edge_costs.gd` | Network graph edge cost computation: dissolve (cost summing), subdivide (cost halving), merge (distance-based). |
| `test_save_system.gd` | Save system internals: checksum computation, serialization round-trip, migration pipeline, v1→v2 migration specifics. |
| `test_perf_optimizations.gd` | Phase 7 performance optimizations: binary heap ordering, GOAP objectives dirty-flag tracking, action cache rebuild, entity fade-distance caching. |
| `test_plugin_migration_registry.gd` | Phase 9 migration tooling: fresh-install stamping, no-op when up to date, single-step and chained multi-version upgrades, skipping pre-cursor migrations. |
| `test_loot_table.gd` | `SKLTItemChance` probability fix, `SKLTWeightedItem` scene resolution, `SKLTWeightedPool` selection logic (single pick, no-duplicate clamping, duplicates, zero-weight exclusion, statistical weight bias), and `LootTableResult.size()`. |

## Notes

- `QuestGraphEngine` and `DialogueEngine` are pure `RefCounted` classes with no scene-tree dependencies, so their tests run in headless mode without additional setup.
- `BarterSystem` tests use lightweight stub objects for `InventoryComponent` and `ShopComponent`.
- `Coven` and `Network` / `NetworkEdge` / `NetworkPoint` are pure `Resource` classes, so their tests also run headless.
- `SaveSystem` tests exercise private helper methods (`_compute_checksum`, `_serialize`, `_deserialize`, `_apply_migrations`) directly.
