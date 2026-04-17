# Integration Tests

This directory contains integration test scripts for Skelerealms' critical systems. The tests are written to be compatible with [GUT (Godot Unit Test)](https://github.com/bitwes/Gut).

## Running the Tests

1. Install the GUT plugin into your project (`addons/gut`).
2. Add a GUT node to a test scene (or use the GUT panel in the Godot editor).
3. Set the test directory to `res://tests/` (or the path where you've placed these scripts).
4. Run from the editor or from the command line:

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

## Test Files

| File | What it tests |
|---|---|
| `test_quest_graph_engine.gd` | Quest activation, event advancement, graph completion, save/restore snapshots, validation. |
| `test_dialogue_engine.gd` | Dialogue session creation, choice evaluation, condition blocking, effect application, terminal nodes. |
| `test_barter.gd` | `BarterSystem` sell/buy toggling, haggle discount accumulation, `accept_barter` modifier application. |
| `test_coven_disposition.gd` | Coven disposition thresholds (`get_disposition`), boundary values, custom thresholds, disposition names, coven opinions. |
| `test_network_edge_costs.gd` | Network graph edge cost computation: dissolve (cost summing), subdivide (cost halving), merge (distance-based). |
| `test_save_system.gd` | Save system internals: checksum computation, serialization round-trip, migration pipeline, v1→v2 migration specifics. |
| `test_perf_optimizations.gd` | Phase 7 performance optimizations: binary heap ordering, GOAP objectives dirty-flag tracking, action cache rebuild, entity fade-distance caching. |
| `test_plugin_migration_registry.gd` | Phase 9 migration tooling: fresh-install stamping, no-op when up to date, single-step and chained multi-version upgrades, skipping pre-cursor migrations. |

## Notes

- `QuestGraphEngine` and `DialogueEngine` are pure `RefCounted` classes with no scene-tree dependencies, so their tests run in headless mode without additional setup.
- `BarterSystem` tests use lightweight stub objects for `InventoryComponent` and `ShopComponent`.
- `Coven` and `Network` / `NetworkEdge` / `NetworkPoint` are pure `Resource` classes, so their tests also run headless.
- `SaveSystem` tests exercise private helper methods (`_compute_checksum`, `_serialize`, `_deserialize`, `_apply_migrations`) directly.
