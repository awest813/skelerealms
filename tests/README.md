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
| `test_quest_aliases.gd` | Alias fill selection (coven/form/exclude/nearest/chains), optional vs required misses, match-time `{Alias}` resolution, param precedence, save/restore of fills, alias validation, authored `.tres` demo quest end-to-end, QuestSystem finder wiring. |
| `test_quest_stages.gd` | Stage activation logging, node-triggered advancement, explicit `set_stage` outcomes, quest completion/failure via stages, alias-resolved journal text, journal/objective shapes with done-flags, stage validation, save/restore of stages, staged demo quest flow, QuestSystem stage signals. |
| `test_radiant_manager.gd` | Trigger matching/target filtering, cooldown gating, active caps, instance numbering, template validation, engine snapshot round-trips, quest unregistration, end-to-end issuance with signals, loading guards, save/load cycles with numbering continuity, removed-mod skips. |
| `test_dialogue_scenes.gd` | Persuasion success/failure branches (seed-calibrated), fizzle holds, choice-view attempt tags, success/fail effect routing, persuasion validation gaps, scene cast/blocking/advance/end, required-participant gating, greet ranges, scene save/restore, system hosting with speaker override, system greet/save/load. |
| `test_dialogue_barks.gd` | Shared condition semantics after extraction, voice passthrough to views, priority/speaker/condition/chance picking, cooldown gating without recording misses, bark validation, system payload emission. |
| `test_companions.gd` | Companion data save/load, carry capacity, recruit/dismiss/home/teleport flows, party caps, follow/wait orders, affinity bands/milestones/clamps, fracture walk-aways, follow steering (approach/hold/yield/catch-up/cross-world/anchorless/inert), dialogue recruit/dismiss effects and companion conditions. |
| `test_ai_packages.gd` | Package evaluation (time windows incl. overnight wrap, need gates with/without trackers, priority vs urgency, target resolvability), change-only signals, minute-tick re-evaluation, validation, save/load, movement steering, nearby-only furniture seating, package-switch release, busy/companion yields, idle cases. |
| `test_progression.gd` | Skill/character XP leveling with carryover and multi-level awards, unknown-skill/negative/config-less guards, perk requirements matrix, grant spend/effects/flags, XP-rate shaping, perk validation, level-funded points, origin application/rejection, component save/load. |
| `test_creatures.gd` | Profile validation, ground body configuration (capsule/speed/senses), one-shot sense scaling, nav-independent target store, flyer steering/climbing/turning/arrival, shared steering math. |
| `test_world_streaming.gd` | Cell/worldspace validation, chunk-source mapping (cells, wilderness, interiors, bad paths, cancel), adapter mount-at-center/unmount/empty/rootless cases, 3×3 streamer mount/evict, fade policy apply/restore with cache invalidation, door/budget/world validation. |
| `test_dialogue_engine.gd` | Dialogue session creation, choice evaluation, condition blocking, effect application, terminal nodes. |
| `test_barter.gd` | `BarterSystem` sell/buy toggling, haggle discount accumulation, `accept_barter` modifier application. |
| `test_coven_disposition.gd` | Coven disposition thresholds (`get_disposition`), boundary values, custom thresholds, disposition names, coven opinions. |
| `test_network_edge_costs.gd` | Network graph edge cost computation: dissolve (cost summing), subdivide (cost halving), merge (distance-based). |
| `test_save_system.gd` | Save system internals: checksum computation, serialization round-trip, migration pipeline, v1→v2 migration specifics. |
| `test_perf_optimizations.gd` | Phase 7 performance optimizations: binary heap ordering, GOAP objectives dirty-flag tracking, action cache rebuild, entity fade-distance caching. |
| `test_plugin_migration_registry.gd` | Phase 9 migration tooling: fresh-install stamping, no-op when up to date, single-step and chained multi-version upgrades, skipping pre-cursor migrations. |
| `test_loot_table.gd` | `SKLTItemChance` probability fix, `SKLTWeightedItem` scene resolution, `SKLTWeightedPool` selection logic (single pick, no-duplicate clamping, duplicates, zero-weight exclusion, statistical weight bias), and `LootTableResult.size()`. |
| `test_editor_tools.gd` | Editor tools: `Span` overlap math, `DialogueEngine.validate_definition` issue kinds, quest/dialogue graph-editor node/link/delete/port logic with layout persistence and validate dialogs, save-inspector checksum verification under both indent settings plus latest-save search, `door_connect` subdirectory search, schedule-editor box tracking/time math/dynamic track growth, quest trigger types from the resource hint, coven-matrix id sorting, template scene-text generation. |

## Notes

- Audit validation on 2026-10-08: 448 framework tests passed (1,356 assertions), 355 flight checks passed, and the example travel/save/reload smoke test reported zero failures. Both projects imported without script parse or compile errors. The framework test process still reports resource leaks and crashes during shutdown; passing assertions do not establish a clean shutdown (see the baseline repairs document).
- `QuestGraphEngine` and `DialogueEngine` are pure `RefCounted` classes with no scene-tree dependencies, so their tests run in headless mode without additional setup.
- `BarterSystem` tests use lightweight stub objects for `InventoryComponent` and `ShopComponent`.
- `Coven` and `Network` / `NetworkEdge` / `NetworkPoint` are pure `Resource` classes, so their tests also run headless.
- `SaveSystem` tests exercise private helper methods (`_compute_checksum`, `_serialize`, `_deserialize`, `_apply_migrations`) directly.
