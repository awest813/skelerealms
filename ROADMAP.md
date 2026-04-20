# Roadmap

This roadmap is the high-level view of where Skelerealms is headed.

For the detailed status of specific systems, assumptions, and incomplete areas, see [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md).

## Current state

- **Version target:** `beta 0.8`
- **Development status:** active
- **Stability target:** feature and API stability at `1.0`

The framework has moved beyond the earliest missing-core-systems phase. The current focus is on closing the remaining simulation and authoring gaps that block a polished open-world RPG foundation.

## Recently completed foundation work

These major pieces are already in place:

- Quest system with graph validation and save integration
- Dialogue system with branching choices, conditions, and effects
- Save-system overhaul with named slots, schema versioning, migration hooks, and integrity checks
- Faction disposition thresholds
- AI investigation behavior and expanded crime response
- GOAP planning fixes and objective tracking fixes
- Spawn tracker persistence
- World-loader abort handling
- NPC door interaction across world boundaries
- Generalized vitals and improved perception coverage
- Barter haggling with skill-factor negotiation
- Item worth, ownership, and coven-aware theft detection
- Furniture animation hooks and multi-user sub-point support
- Player damage generalization across all damage types with buff/debuff modifiers
- Network edge cost computation on dissolve, merge, and subdivide
- Granular navigation memory optimization (RefCounted KD-tree nodes)
- Audio emitter refactor to non-physics distance checks
- Debug, audit, and polish pass across Phases 1-6: fixed NPC damage accumulation bug, added barter null safety, cleaned up 20+ raw debug prints, added test suites for coven disposition, network edge costs, and save system internals
- Performance profiling and optimization: GOAP objective/action caching (eliminates per-frame sort and child filter), entity fade-distance caching, NPC perception entity-reference caching, A* binary heap (replaces per-iteration array sort), CrimeMaster empty-queue early exit, NavMaster debug print cleanup
- Audit and polish pass across Phases 0-4: fixed `DefaultDamageModule` direct vitals dict mutations (bypassed `VitalsComponent` clamping and signals) — now uses `change_health/moxie/will()`; fixed `CrimeMaster.bounty_for_coven` dict key crash on unknown severity (`.get()` guard); fixed `BarterSystem.accept_barter` dict key crash when currency not yet initialised (`.get()` guard); removed 4 remaining bare debug `print()` calls (`mod_loader.gd`, `door.gd`, `player_component.gd`) and converted 3 loot-table prints to `push_error/push_warning`; removed two stale `# TODO` markers in `skelesave.gd`; added `test_crime_master.gd` (6 tests) and extended `test_barter.gd` with `accept_barter` null-currency tests
- Audit and polish pass across Phases 5-9: fixed `SaveSystem.save()` and `entity_in_save()` null-safety on `FileAccess.open()` (guarded with warning on failure); removed noisy debug `printe()` calls from `NPCComponent._busy` setter and door-interaction, and `ItemComponent.interact` theft path; replaced bare `print()` in `tools/door_connect.gd` with `push_warning()`; added `push_error` to `PluginMigrationRegistry` when a migration callable is invalid; added `test_spawn_tracker_manager.gd` (8 tests covering save, load, reset, and round-trip)
- **Phase 9 remaining (0.9)**: `_saving` guard + tmp-file + rename for crash-safe `SaveSystem.save()`; initial `@rpc` annotation pass on authority-only and any-peer state-transition methods in `QuestSystem`, `CrimeMaster`, and `DialogueSystem`; `thread_safety.md` and `multiplayer_audit.md` updated to reflect these changes.

## Current priorities

Phase 11 — Combat Subsystem & UI Framework. Both systems are now implemented. The combat layer provides `DamagePacket`, `CombatantComponent`, `CombatAction`, `CombatStateMachine`, hitbox/hurtbox detection, `HitPipeline`, and an AI combat action module. The UI framework provides `SKUIManager` autoload, `SKTheme` resource, HUD/menu shell abstractions, and widget contracts. See `FRAMEWORK_STATUS.md` for the full file listing.

### Phase 11 — Combat Subsystem & UI Framework ✅

1. ✅ **Combat subsystem** — Built-in combat layer in `scripts/combat/` covering:
   - `DamagePacket` extending `DamageInfo` with crit, hit reactions, damage categories, tags
   - `CombatantComponent` unifying poise, resistances, block/parry/i-frames
   - `CombatAction` resource defining attacks/spells with timing, cost, and combos
   - `CombatStateMachine` with Idle/Attack/Cast/Stagger/Knockdown/Death states
   - `SKHitbox`/`SKHurtbox` Area3D wrappers with deduplication and locational damage
   - `HitPipeline` stateless resolver for melee and hitscan hits
   - AI combat action module for NPC action selection
2. ✅ **UI framework** — Framework-owned UI structure in `scripts/ui/` with:
   - `SKUIManager` autoload managing layer stack, menu stack, input mode routing
   - `SKTheme` resource with RPG color palette, font slots, animation timing
   - `SKHUDShell` with widget slots for vitals, compass, crosshair, prompts, status effects
   - `SKMenuShell` with tab/page and popup management
   - Menu contracts: inventory, dialogue, barter, journal, pause, character
   - Widget contracts: list item, stat row, tab panel, tooltip, radial selector, prompt bar

### Phase 12 — Chunk Loading System ✅

Generic, engine-agnostic chunk manager that fills the "No terrain/LOD/chunk pipeline" gap.

1. ✅ **Core types** — `SKChunk` RefCounted data class holding grid coordinates, loaded data, and lifecycle flags (`is_loaded`, `is_loading`, `is_mounted`, `last_touched`, `error`).
2. ✅ **Chunk utilities** — `SKChunkUtils` with static helpers: `to_chunk_key`/`from_chunk_key` (string↔Vector2i), `world_to_chunk_coords` (Vector3→grid using X/Z), `square_coords_around`, and `sort_coords_by_distance` (Manhattan).
3. ✅ **Cancellation token** — `SKCancelToken` lightweight RefCounted flag for cooperative cancellation of in-flight loads.
4. ✅ **Abstract interfaces** — `SKChunkSource` (load/unload data) and `SKChunkAdapter` (mount/unmount visuals) base classes for game-specific implementations.
5. ✅ **Chunk manager** — `SKChunkManager` Node with:
   - Configurable `chunk_size`, `active_radius`, `preload_radius`, `max_cached_chunks`, `load_concurrency`
   - Async loading with worker-pool concurrency limiting
   - Active radius mount/unmount and preload radius pre-fetching
   - LRU cache eviction (oldest-touched, non-active, non-preload chunks evicted first)
   - `chunk_event` signal for full lifecycle observability (created, load-start, loaded, load-error, activated, deactivated, mount-start, mounted, unmount-start, unmounted, unloaded)
   - `dispose()` for clean teardown
6. ✅ **Example implementations** — `ExampleChunkSource` (deterministic procedural tiles + entities) and `ExampleChunkAdapter` (log-only mount/unmount) for testing.
7. ✅ **Test suite** — `tests/test_chunk_manager.gd` with GUT tests covering utilities, chunk init, cancel token, manager lifecycle, mount/unmount on move, dispose, event signals, and cache eviction.

| File | Purpose |
|---|---|
| `scripts/chunks/sk_chunk.gd` | Chunk data class |
| `scripts/chunks/sk_chunk_utils.gd` | Coordinate math utilities |
| `scripts/chunks/sk_cancel_token.gd` | Cooperative cancellation token |
| `scripts/chunks/sk_chunk_source.gd` | Abstract chunk data loader |
| `scripts/chunks/sk_chunk_adapter.gd` | Abstract chunk mount/unmount adapter |
| `scripts/chunks/sk_chunk_manager.gd` | Main chunk manager Node |
| `scripts/chunks/example_chunk_source.gd` | Example procedural source |
| `scripts/chunks/example_chunk_adapter.gd` | Example logging adapter |
| `tests/test_chunk_manager.gd` | GUT test suite |

### Phase 9 — Architecture Hardening (0.8 → 0.9 target) ✅

Prepare the framework for long-lived production use and broader adoption.

1. ✅ **Multiplayer-readiness audit** — session-unsafe state, singleton assumptions, and player-identity coupling catalogued in `docs/architecture/multiplayer_audit.md`. No code changes yet; documented as a survey so any future co-op fork has a starting map.
2. ✅ **Thread-safety review** — autoload and shared-state hazards documented in `docs/architecture/thread_safety.md`. Ground rule codified: Skelerealms remains a single-threaded main-thread framework; worker-thread work requires immutable snapshots.
3. ✅ **API stability pass** — Stable / Beta / Internal tiers defined in `docs/architecture/api_stability.md`. Post-1.0 deprecation policy spelled out.
4. ✅ **Plugin packaging** — plugin version bumped to `beta 0.8`. Plugin.cfg metadata retained; AssetLib polish (minimal example project, versioned release artifacts) remains for 0.9.
5. ✅ **Migration tooling** — `PluginMigrationRegistry` (`scripts/system/plugin_migration_registry.gd`) runs one-shot project-level migrations on editor start. Save-file migrations continue to live in `SaveSystem`. Contract documented in `docs/architecture/migration_tooling.md`. Unit tests in `tests/test_plugin_migration_registry.gd`.
6. ✅ **SaveSystem crash safety** — `_saving: bool` guard prevents re-entrant or concurrent calls. Write path converted to tmp-file + rename: data is serialised to `<slot>.tmp` then atomically renamed to `<slot>.dat`, so a crash during the write cannot corrupt an existing save. GUT tests extended to cover the guard.
7. ✅ **`@rpc` annotation pass** — authority-only state transitions (`QuestSystem.activate_quest`, `activate_quest_with_params`, `apply_event`; `CrimeMaster.punish_crimes`) annotated with `@rpc("authority", "reliable")`. Any-peer event reporters (`report_kill`, `report_pickup`, `report_talk`, `report_custom`; `CrimeMaster.add_crime`; `DialogueSystem.end_dialogue`) annotated with `@rpc("any_peer", "call_local", "reliable")`. Annotations do not affect single-player behaviour; `multiplayer_audit.md` updated with the full table.

| File | Purpose |
|---|---|
| `docs/architecture/multiplayer_audit.md` | Survey of session-scoped state, player-singleton assumptions, RPC gaps |
| `docs/architecture/thread_safety.md` | Main-thread rule, per-autoload hazards, safe-to-thread operations |
| `docs/architecture/api_stability.md` | Stable / Beta / Internal tier classification and deprecation policy |
| `docs/architecture/migration_tooling.md` | Save-file vs plugin-level migration split and contract |
| `scripts/system/plugin_migration_registry.gd` | Plugin-version migration runner (project-level state) |
| `tests/test_plugin_migration_registry.gd` | GUT tests for the registry's run loop |
| `scripts/system/save_system.gd` | `_saving` guard + tmp-file + rename write path |
| `tests/test_save_system.gd` | Extended with `_saving` guard tests |
| `scripts/quests/quest_system.gd` | `@rpc` annotations on state-transition methods |
| `scripts/crime/crime_master.gd` | `@rpc` annotations on state-transition methods |
| `scripts/dialogue/dialogue_system.gd` | `@rpc` annotation on `end_dialogue` |

Remaining Phase 9 work (pushed into 0.9):

- AssetLib-ready minimal example project.

## Next phases

### Phase 8 — Runtime Debugging & Diagnostics (0.8 target) ✅

In-game overlays and tools to accelerate iteration and troubleshooting.

1. ✅ **AI state overlay** — `AIStateOverlay` CanvasLayer (`scripts/system/ai_state_overlay.gd`). Displays each active NPC's GOAP debug info (current objective, active action, action queue via `gather_debug_info()`) and perception-memory visibility per tracked entity. Toggle with F10.
2. ✅ **Navigation debug draw** — `NavDebugDraw` Node3D (`scripts/system/nav_debug_draw.gd`). Renders all NavNode edges for loaded worlds using `ImmediateMesh`. Same-world edges in green; cross-world portal edges in orange. Toggle with F11, configurable `rebuild_interval`.
3. ✅ **Perception debug draw** — `PerceptionDebugDraw` Node3D (`scripts/system/perception_debug_draw.gd`). Draws horizontal FOV arcs and boundary rays for every NPC with an `EyesPerception` node, plus cross markers at last-known entity positions colour-coded by visibility. Toggle with F12.
4. ✅ **Quest state inspector** — `QuestStateInspector` CanvasLayer (`scripts/system/quest_state_inspector.gd`). Runtime scrollable panel listing all registered quests with status and per-node progress. Active-only filter toggle. Toggle with F9.
5. ✅ **Save file inspector** — `SaveInspector` editor tool (`tools/save_inspector.gd`). Bottom panel in the Godot editor. Opens any `.dat` save file via browse dialog or typed path, displays the full JSON as a collapsible `Tree`, reports schema version, entity count, checksum validity.

| File | Purpose |
|---|---|
| `scripts/system/ai_state_overlay.gd` | Runtime CanvasLayer — GOAP state and perception overlay |
| `scripts/system/nav_debug_draw.gd` | Runtime Node3D — ImmediateMesh nav-graph visualizer |
| `scripts/system/perception_debug_draw.gd` | Runtime Node3D — FOV cone and detection-marker visualizer |
| `scripts/system/quest_state_inspector.gd` | Runtime CanvasLayer — quest state panel |
| `tools/save_inspector.gd` | `@tool` editor bottom panel — save file browser and validator |

## Recently completed work

These pieces landed in the latest milestone:

- **Phase 12 — Chunk Loading System**: Generic, engine-agnostic chunk manager in `scripts/chunks/` with async loading, active/preload radii, mount/unmount lifecycle, LRU cache eviction, concurrency limits, and cancellation token support. Includes abstract `SKChunkSource`/`SKChunkAdapter` interfaces and example implementations. GUT test suite in `tests/test_chunk_manager.gd`.
- **Phase 9 — Architecture Hardening (initial pass)**: four architecture docs (`multiplayer_audit.md`, `thread_safety.md`, `api_stability.md`, `migration_tooling.md`), plus the `PluginMigrationRegistry` class and tests for it. Plugin version bumped to `beta 0.8`.
- **Phase 10 — External Inspiration Integration**: Ported behaviour tree system from BehaviourToolkit (MIT); added `SKBlackboard` shared AI state store; added quest template variables with `{placeholder}` substitution; added `ANY` join mode for quest node prerequisites.
- **Phase 8 — Runtime Debugging & Diagnostics**: AI state overlay, navigation debug draw, perception debug draw, quest state inspector, and save file inspector all implemented. Runtime nodes add no overhead when hidden. Editor save inspector wired as a bottom panel in the plugin.
- **Phase 7 — Editor Tooling**: Visual quest graph editor, dialogue tree editor, and coven relationship matrix all landed as `@tool` editor plugins. Each opens a dedicated popup window from the Godot inspector. The schedule editor (shipped in beta 0.6) completes the set of four authoring tools.
- Mod-friendly data architecture: `ModManifest` resource and `ModLoader` autoload with manifest-driven override support for covens, quests, and dialogues.
- Crime — non-player tracking completeness: assault and murder crimes are now broadcast by `DefaultDamageModule`; fixed `crime_committed` signal type and null safety in `CrimeMaster`.
- **Documentation**: Added user-guide pages for the Quest system, Dialogue system, Save system, and Mods system. Updated the documentation table of contents in `docs/intro.md`.
- **Integration tests**: Added GUT-compatible test suites for `QuestGraphEngine` (`tests/test_quest_graph_engine.gd`), `DialogueEngine` (`tests/test_dialogue_engine.gd`), and `BarterSystem` (`tests/test_barter.gd`).
- **Performance**: `QuestGraphEngine` now builds precomputed node-lookup and successor-edge maps at registration time, eliminating O(n) list scans during `apply_event` and graph traversal.

## Path to 1.0

Skelerealms should reach 1.0 only after:

- The major incomplete systems are finished
- Core authoring workflows are reliable
- Key framework APIs settle down
- The addon is comfortable to integrate into a long-running production project

Until then, expect iteration and breaking changes where the framework still needs structural improvement.

---

## Camelot Integration History

The phases below document the work ported from [Camelot](https://github.com/awest813/Camelot) into SkeleRealms.

Camelot is a TypeScript/Babylon.js browser RPG framework. Its headless framework layer
(`src/framework/`) contains engine-agnostic systems for quests, dialogue, factions,
saves, and mods — all well-tested. The algorithms and architectural patterns translate
directly to GDScript even though the runtime is different.
---

## Phase 1 — New Systems (HIGH value, fills the biggest stated gaps) ✅

### ~~1A  Quest System~~ ✅
**Source:** `src/framework/quests/quest-graph-engine.ts`

~~SkeleRealms explicitly lists "Quests" as missing in its README.~~ Camelot's
`QuestGraphEngine` provides:

- Directed-acyclic-graph quest structure with prerequisites and `next_node_ids`.
- `activate_quest` / `apply_event` / `get_snapshot` / `restore_snapshot` API.
- Built-in `validate_graph()` — BFS reachability, dead-end detection, cycle detection.
- Kill / Fetch / Talk / Custom trigger types with progress counters and XP rewards.

**Implementation:**
- `QuestNodeDefinition`, `QuestDefinition`, `QuestEvent` resource classes created.
- `QuestGraphEngine` — core engine with `register_quest`, `activate_quest`, `apply_event`, `validate_graph`, snapshot/restore.
- `QuestSystem` — autoload singleton that loads quest definitions and wires save integration.

| File | Purpose |
|---|---|
| `scripts/quests/quest_node_definition.gd` | Resource class for quest node definitions |
| `scripts/quests/quest_definition.gd` | Resource class for quest definitions |
| `scripts/quests/quest_event.gd` | Resource class for quest events |
| `scripts/quests/quest_graph_engine.gd` | Core engine — `register_quest`, `activate_quest`, `apply_event`, `validate_graph`, snapshot/restore |
| `scripts/quests/quest_system.gd` | Autoload singleton — loads quest definitions, wires save integration |

### ~~1B  Dialogue System~~ ✅
**Source:** `src/framework/dialogue/dialogue-engine.ts`

~~Also explicitly missing from SkeleRealms.~~ Camelot's `DialogueEngine` provides:

- Branching dialogue trees with typed conditions (reputation, flags, items, skills)
  and effects (set flag, adjust reputation, give/consume items, activate quest).
- Session-based API so dialogue data stays decoupled from runtime state.
- Snapshot/restore for save integration.

**Implementation:**
- `DialogueNode`, `DialogueChoice`, `DialogueDefinition`, `DialogueChoiceCondition`,
  `DialogueChoiceEffect`, `DialogueContext`, `DialogueSession` resource/utility classes created.
- `DialogueEngine` — core engine with `register_dialogue`, `create_session`, session `choose()` / snapshot.
- `DialogueSystem` — autoload singleton that loads definitions and coordinates with other systems.

| File | Purpose |
|---|---|
| `scripts/dialogue/dialogue_node.gd` | Resource class for dialogue nodes |
| `scripts/dialogue/dialogue_choice.gd` | Resource class for dialogue choices |
| `scripts/dialogue/dialogue_choice_condition.gd` | Typed conditions for dialogue choices |
| `scripts/dialogue/dialogue_choice_effect.gd` | Effects triggered by dialogue choices |
| `scripts/dialogue/dialogue_context.gd` | Context data for dialogue evaluation |
| `scripts/dialogue/dialogue_definition.gd` | Resource class for full dialogue trees |
| `scripts/dialogue/dialogue_session.gd` | Runtime session for active dialogue |
| `scripts/dialogue/dialogue_engine.gd` | Core engine — `register_dialogue`, `create_session`, session `choose()` / snapshot |
| `scripts/dialogue/dialogue_system.gd` | Autoload singleton — loads definitions, coordinates with other systems |

---

## Phase 2 — Bug Fixes & Enhancements (MEDIUM-HIGH value) ✅

### ~~2A  GOAP BFS Fix~~ ✅
**Source:** Camelot's `validateGraph()` BFS pattern

~~SkeleRealms' `_build_graph` in `goap_component.gd` is documented as broken
depth-first (FRAMEWORK_STATUS Phase 1 #2).~~ Rewritten to BFS (explicit queue,
visited set) so action plans are cost-optimal.

### ~~2B  Save System Enhancements~~ ✅
**Source:** `src/framework/save/save-engine.ts`, `save-migration-registry.ts`

All three enhancements implemented:
- **Named save slots** — `save(slot_name)` and `load_slot(slot_name)` API; file
  becomes `user://saves/<slot_name>.dat` (falls back to datetime).
- **Schema versioning** — `SAVE_SCHEMA_VERSION = 2` embedded in every save;
  registered migrations run in order on load via `register_migration()`.
- **FNV-1a checksum** — detects corruption before attempting to parse.

Also added: `load_complete` signal, safe dictionary access throughout
deserialization, inventory/equipment/covens persistence.

### ~~2C  Faction Disposition Thresholds~~ ✅
**Source:** `src/framework/factions/faction-engine.ts`

Added per-coven configurable `hostile_below`, `friendly_at`, `allied_at` threshold
exports and a `get_disposition()` helper returning `HOSTILE / NEUTRAL / FRIENDLY / ALLIED`
(via `Coven.Disposition` enum). Also fixed the coven NPC-opinion lookup
(FRAMEWORK_STATUS Phase 1 #5).

---

## Phase 3 — Feature Ideas (MEDIUM value, future work)

### 3A  AI Investigate State
**Source:** Camelot AI description

~~Complete the investigate stub in `default_threat_response.gd`:
on losing sight → record `last_known_position` → navigate there → if nothing
found, return to patrol.~~ ✅

**Implementation:**
- When `UNAWARE` state fires and target is below attack threshold, NPC records last
  known position in GOAP memory and adds `{"area_investigated": true}` objective.
- When `AWARE_VISIBLE` fires during investigation, the investigation is cancelled
  (target found).
- When `WARY` fires (awareness fully decayed), the investigation ends and NPC
  returns to patrol.
- Added `investigate_started` and `investigate_ended` signals to `NPCComponent`.
- Also implemented friendly-fire response based on `friendly_fire_behavior` export.

### 3B  Guard Challenge / Crime Response
**Source:** Camelot's Guard Challenge Modal

~~Complete `default_crime_report.gd` with four response branches:
pay fine, serve jail time, resist arrest, attempt persuasion.~~ ✅

**Implementation:**
- `DefaultCrimeReportModule` now checks coven membership to determine whether to
  report crimes (own covens vs. other covens via `report_crimes_against_other_covens`).
- On witnessing a crime above `confront_severity_threshold`, the NPC stores
  confrontation data in GOAP memory and adds `{"crime_confronted": true}` objective.
- Four resolution methods: `resolve_pay_fine()`, `resolve_serve_time()`,
  `resolve_resist_arrest()`, `resolve_persuasion()`.
- `crime_confrontation` signal added to `NPCComponent` for UI/dialogue integration.
- Added `can_see_entity()` helper to `NPCComponent`.

### ~~3C  Mod-Friendly Data Architecture~~ ✅
**Source:** `src/framework/mods/content-merge.ts`

~~Design coven resources, quest definitions, and entity templates with a
manifest-driven override system for mod support.~~ ✅

**Implementation:**
- `ModManifest` resource — declares covens, quests, dialogues, and
  `CovenOpinionOverride` entries a mod contributes.
- `CovenOpinionOverride` resource — declares an opinion delta from one coven
  toward another, applied via `CovenSystem.change_opinion()`.
- `ModLoader` autoload — scans `skelerealms/mods_path` (default `res://mods`)
  at game-start, loads every `.tres`/`.res` that is a `ModManifest`, and
  registers all declared content. Also exposes `load_mod(manifest)` for
  programmatic loading.
- `skelerealms/mods_path` project setting added to control the scan directory.

| File | Purpose |
|---|---|
| `scripts/mods/mod_manifest.gd` | Resource class — declares mod content |
| `scripts/mods/coven_opinion_override.gd` | Resource class — opinion delta entry |
| `scripts/mods/mod_loader.gd` | Autoload singleton — discovers and applies manifests |

---

## Phase 5 — World & Persistence (0.8 roadmap items) ✅

### ~~5A  Spawn Tracker Persistence~~ ✅
Serialized `NPCSpawnPoint.spawn_tracker` into the save file via a new
`SpawnTrackerManager` autoload that registers with the `savegame_other`
group. One-shot spawner state now survives game restarts.

**Implementation:**
- Created `SpawnTrackerManager` (`scripts/system/spawn_tracker_manager.gd`) —
  singleton that implements `save()`, `load_data()`, `reset_data()`.
- Integer dictionary keys are converted to strings for JSON compatibility.
- Registered as autoload in the plugin (`skelerealms.gd`).
- Removed the `# TODO: Save this` comment from `spawn_point.gd`.

| File | Purpose |
|---|---|
| `scripts/system/spawn_tracker_manager.gd` | Autoload singleton — persists `NPCSpawnPoint.spawn_tracker` via `savegame_other` group |

### ~~5B  World Loader Abort Handling~~ ✅
Replaced the silent `_abort()` stub with proper error handling.

**Implementation:**
- Added `world_loading_failed(error_message)` signal for UI integration.
- On failure, attempts to reload the previous world (`_previous_world_id`)
  using a synchronous `ResourceLoader.load()` fallback.
- If recovery also fails, pauses the game via `GameInfo.pause_game(true)` to
  prevent undefined state.
- Descriptive error messages propagated through `push_error()` and the signal.

### ~~5C  NPC Door Interaction~~ ✅
NPCs now interact with doors when their path crosses a world boundary.

**Implementation:**
- Added `_interact_with_nearest_door(near_position)` to `NPCComponent` —
  searches for the nearest `Door` node in the scene (via `doors` group or
  recursive tree walk) and calls `door.interact(entity_name)`.
- The `Door.on_interact` handler uses the entity's `TeleportComponent` to
  teleport the NPC to the destination world and position.
- Added `door_interacted(door)` signal to `NPCComponent` for animation/sound
  hooks.
- Removed the `# TODO: Interact with door?` comment.

---

## Phase 4 — Framework Fixes & Generalization (0.7 roadmap items) ✅

### ~~4A  GOAP Objective Assignment Fix~~ ✅
Moved `_current_objective` assignment before `_pop_action()` so the planner
correctly tracks which objective is active from the moment the plan starts.

### ~~4B  Granular Navigation Connection Persistence~~ ✅
Implemented `_load()` for deferred portal connections, added `save()`/`load_data()`
for connection persistence via the `savegame_other` group, fixed `portal_edges`
append bug, and added a node lookup table.

### ~~4C  Generalized VitalsComponent~~ ✅
Decoupled from player-only use. Added `is_player` and `dishonored_mode` exports
to gate player-specific mechanics. Recharge rates (`moxie_recharge_rate`,
`will_recharge_rate`) are now configurable via `@export`.

### ~~4D  Complete Perception FOV~~ ✅
Added vertical FOV check using pitch angle comparison against `fov_v` export.
Implemented AABB coverage percentage via 7-point raycast sampling (center + 6 face
centers). Horizontal check now uses proper `cos(deg_to_rad())` threshold.
Visibility = `light_level × coverage`.

### ~~4E  Fix Item Drop Direction~~ ✅
Replaced incorrect `get_euler().normalized()` with proper `-Basis(quaternion).z`
forward vector. Removed stale debug prints.

### ~~4F  Fix Barter `shop_will_accept_item`~~ ✅
Fixed type hint from `Resource` to `ShopComponent`. Replaced non-existent
`ic.data.tags` with `ItemDataComponent` children lookup via `get_type()`. Added
null safety for entity and component access.

---

## Phase 6 — Polish & Depth (0.6 roadmap items) ✅

### ~~6A  Barter Haggling~~ ✅
Added negotiation mechanics to the barter system.

**Implementation:**
- `haggle(skill_factor)` method with skill-factor-based success calculation using
  `ShopComponent.haggle_tolerance` (vendor willingness to negotiate).
- Configurable `max_haggle_attempts` export (default 3 rounds per session).
- Discount accumulates per successful haggle, capped at `1.0 - tolerance`.
- `haggle_succeeded(new_modifier)` and `haggle_failed` signals for UI integration.
- Haggle modifier automatically applied to buying prices in `accept_barter()`.

### ~~6B  Item Worth & Ownership~~ ✅
Completed theft logic, ownership checks, and item-drop-size compensation.

**Implementation:**
- Added `worth: int` export for monetary value (used by barter and theft severity).
- Added `item_radius: float` export for drop-position wall offset.
- `_is_theft_for(entity_ref)` checks coven disposition — items owned by entities
  sharing friendly/allied covens with the taker are not considered theft.
- Drop position now offsets by `item_radius` along hit normal when near walls.
- `stolen` and `worth` persisted across save/load.
- Fixed `transaction.gd` to use `ItemComponent.worth` directly (removed broken `.data.worth`).

### ~~6C  Furniture Animation & Multi-Use~~ ✅
Support richer NPC use points and multiple simultaneous users.

**Implementation:**
- `max_users: int` export (default 1) for concurrent occupancy.
- Child `IdlePoint` nodes act as sub-points for additional occupants.
- `play_animation(entity_name, anim)` signal emitted on occupy for animation hooks.
- `stop_animation(entity_name)` signal emitted on unoccupy.
- `occupy(who) -> bool` returns false when full; `unoccupy_entity(who)` frees a
  specific slot; `has_room() -> bool` checks availability.

### ~~6D  Player Damage Generalization~~ ✅
Extended the player damage pipeline beyond blunt-only handling.

**Implementation:**
- `on_damage()` now iterates all entries in `DamageInfo.damage_effects`.
- Per-type `damage_modifiers: Dictionary` export (StringName → float multiplier).
- Attribute damage types (`&"moxie"`, `&"will"`) handled separately via
  `change_moxie()`/`change_will()`.
- Spell effects applied via `SpellTargetComponent.add_effect()`.

### ~~6E  Network Edge Costs~~ ✅
Wired up cost computation in network graph operations.

**Implementation:**
- `dissolve_point()` sums costs from the two dissolved edges when reconnecting.
- `merge_points()` computes distance-based costs from the new merged node.
- `subdivide_edge()` splits the original edge cost in half for each new edge.

### ~~6F  Granular Navigation Memory Optimization~~ ✅
Reduced memory overhead in the navigation runtime.

**Implementation:**
- Converted `NavNode` from `Node3D` to `RefCounted` — eliminates Godot scene tree
  overhead (transforms, signals, groups, visibility) per navigation point.
- Converted `NavWorld` from `Node` to `RefCounted` — no longer part of scene tree.
- Added explicit `parent_node`, `position`, and `node_name` fields to `NavNode`
  (replacing inherited Node3D properties).
- `NavMaster` now manages worlds via Dictionary instead of child nodes.

### ~~6G  Audio Emitter Refactor~~ ✅
Replaced physics-based sound propagation with a direct approach.

**Implementation:**
- Removed `PhysicsShapeQueryParameters3D` / `SphereShape3D` sphere query.
- Iterates `audio_listener` group members directly via `get_tree().get_nodes_in_group()`.
- Distance check uses `global_position.distance_squared_to()` against range².
- No physics bodies required for audio event detection.

---

## Phase 7 — Quality, Audit & Performance ✅

### ~~7A  User-Guide Documentation~~ ✅
Added user-guide markdown files for every new Camelot-ported system.

**Implementation:**
- `docs/user guide/quests.md` — QuestGraphEngine setup, registration, events, save integration.
- `docs/user guide/dialogue.md` — DialogueEngine setup, conditions, effects, session lifecycle.
- `docs/user guide/save_system.md` — named slots, schema versioning, migrations, checksum.
- `docs/user guide/mods.md` — ModManifest format, coven-opinion overrides, programmatic loading.
- Updated `docs/intro.md` table of contents with links to all guide pages.

### ~~7B  Integration Test Coverage~~ ✅
GUT-compatible test suites added for every new Camelot system.

| File | Coverage |
|---|---|
| `tests/test_quest_graph_engine.gd` | Registration, activation, event advancement, partial progress, parallel nodes, snapshot/restore, graph validation |
| `tests/test_dialogue_engine.gd` | Session creation, choice conditions, effects, terminal nodes, snapshot/restore |
| `tests/test_barter.gd` | Haggle arithmetic, sell/buy toggling, cancel signals |
| `tests/test_coven_disposition.gd` | Disposition thresholds — HOSTILE / NEUTRAL / FRIENDLY / ALLIED boundaries |
| `tests/test_network_edge_costs.gd` | `dissolve_point()` cost sum, `merge_points()` distance cost, `subdivide_edge()` half-cost |
| `tests/test_save_system.gd` | Checksum computation, serialization round-trip, migration pipeline, v1→v2 migration |
| `tests/test_perf_optimizations.gd` | Binary heap ordering, GOAP dirty-flag tracking, action cache rebuild, entity fade-distance cache |

### ~~7C  QuestGraphEngine Performance~~ ✅
Eliminated repeated linear scans in hot paths.

**Implementation:**
- Added `_node_maps` dictionary (quest_id → node_id → `QuestNodeDefinition`) built at `register_quest` time.
- Added `_successor_maps` dictionary (quest_id → node_id → `Array[StringName]`) precomputed at registration.
- `_get_immediate_next_node_ids`, `_are_prerequisites_completed`, `_activate_implicit_nodes`, and
  `_get_all_successors` all reduced from O(n) per call to O(1) via cached dictionaries.

### ~~7D  NPC Damage Accumulation Bug~~ ✅
`DefaultDamageModule.process_damage()` used `=` (assignment) instead of `+=` for `accumulated_damage`,
meaning only the last damage type in a multi-type `DamageInfo` was applied.  Fixed to `+=`.

### ~~7E  Barter Null Safety~~ ✅
Added null checks on `vendor.parent_entity` in `start_barter()` and safe entity/component lookups
in `accept_barter()` item-move loops to prevent null reference errors.

### ~~7F  Debug Print Cleanup~~ ✅
Replaced bare `print()` calls throughout with entity-tagged `printe()` logging or `push_warning()`.

- `default_threat_response.gd` — 15+ bare `print()` → `_npc.printe()`.
- `world_loader.gd` — 7 debug `print()` removed; directory-error print → `push_warning()`.
- `coven_system.gd` — stray `print()` → `push_warning()`.
- `machine_perception.gd` — debug `print()` removed.
- `navigation_master.gd` — 6 remaining bare `print()` removed; deferred-connection message → `push_warning()`.

### ~~7G  GOAP Per-Frame Overhead~~ ✅
`GOAPComponent._process()` previously sorted objectives and rebuilt child action lists every frame.

**Implementation:**
- Objectives sorted only when `_objectives_dirty` flag is set (on add/remove).
- Child `GOAPAction` nodes cached in `_cached_actions`; rebuilt only when `_actions_dirty` is set.

### ~~7H  Entity Fade-Distance Caching~~ ✅
`SKEntity._should_be_in_scene()` called `ProjectSettings.get_setting()` every frame for every entity.
Now caches `actor_fade_distance²` in `_actor_fade_dist_sq` on first access.

### ~~7I  NPC Perception Entity-Reference Caching~~ ✅
`NPCComponent._process()` perception loop previously walked the scene tree via
`SkeleRealmsGlobal.get_entity_in_tree()` every frame per visible object.  Added
`_entity_ref_cache` dictionary mapping perceived `Object` → `SKEntity`; stale entries are
evicted when `is_instance_valid()` fails.

### ~~7J  A-Star Binary Heap~~ ✅
`NavMaster.calculate_path()` replaced per-iteration `Array.sort_custom()` (O(n log n) per step)
with a binary min-heap using `_heap_push()` / `_heap_pop()` static helpers (O(log n) per
insertion/extraction).  Closed-list membership check changed from `Array.has()` (O(n)) to
`Dictionary.has()` (O(1)).

### ~~7K  CrimeMaster Empty-Queue Early Exit~~ ✅
`CrimeMaster._process()` now returns immediately when `crime_queue` is empty, avoiding
function-call and loop-setup overhead every frame while the queue is idle.

### ~~7L  Audit Polish — `_determine_threat` Null Safety~~ ✅
`DefaultThreatResponseModule._determine_threat()` called `.some()` on `get_component()` return
values, which are `SKEntityComponent | null` (not `Option` objects).

**Implementation:**
- `e.get_component("PlayerComponent").some()` → `e.has_component("PlayerComponent")`.
- `e_sc = e.get_component("SkillsComponent")` guard → `if not e_sc:`.
- Added null guard for `_npc.parent_entity.get_component("SkillsComponent")` to prevent crash when
  the NPC itself has no `SkillsComponent`.

---

## Phase 0-4 Audit — Debug, Polish & Test Coverage ✅

A targeted audit pass over every system introduced in Phases 1–4 (Critical Fixes, Core Gameplay
Gaps, World & Persistence, Polish & Depth).

### ~~A  DefaultDamageModule vitals bypass~~ ✅
Direct dictionary mutations in `process_damage()` silently bypassed `VitalsComponent` clamping,
dirty-flag tracking, and all vital-change signals (`dies`, `exhausted`, `drained`, `vitals_updated`).

**Fix:**
- `vitals_component.vitals["moxie"] -= ...` → `vitals_component.change_moxie(-...)`
- `vitals_component.vitals["will"] -= ...` → `vitals_component.change_will(-...)`
- `vitals_component.vitals["health"] -= ...` → `vitals_component.change_health(-...)`
- Added `float` type annotation to the local `accumulated_damage` variable.

### ~~B  CrimeMaster bounty dict key crash~~ ✅
`bounty_for_coven()` used `bounty_amount[x.severity]` which would throw an unhandled key error
for any crime with a severity not present in the `bounty_amount` constant (e.g., if a new crime
type with severity 3 or 4 is added).

**Fix:** `bounty_amount[x.severity]` → `bounty_amount.get(x.severity, 0)`.

### ~~C  BarterSystem accept_barter currency key crash~~ ✅
`accept_barter()` used `vendor.currencies[currency]` and `customer.currencies[currency]` which
throw key errors when the currency has never been initialised for a participant.

**Fix:** Both direct accesses replaced with `.get(currency, 0)`.

### ~~D  Remaining bare print() cleanup~~ ✅
Four bare `print()` calls not covered by the Phase 7F pass:

- `scripts/mods/mod_loader.gd` — informational mod-load message removed (the `mod_loaded` signal already carries this information).
- `scripts/world_objects/door.gd` — debug teleport trace removed.
- `scripts/components/player_component.gd` — debug teleport trace removed.
- `scripts/loottable/items/lt_on_condition.gd` — three `print()` calls converted: parse error and execution failure → `push_error()`; non-boolean return type → `push_warning()`.

### ~~E  Skelesave stale TODO comments~~ ✅
Removed two `# TODO` markers from `scripts/misc/skelesave.gd` — both marked sections were already
fully implemented (array branch of `_decode_value`).

### ~~F  Test coverage~~ ✅
New and extended test suites covering the bugs fixed above.

| File | New coverage |
|---|---|
| `tests/test_crime_master.gd` | `bounty_for_coven` accumulation, `max_crime_severity`, `punish_crimes` |
| `tests/test_barter.gd` | `accept_barter` with uninitialised currency key |

---

## Phase 9 — Architecture Hardening (initial pass, 0.8 target) ✅

This phase inherits Camelot's framework-layer maturity (tests, docs, validators) and applies it to architectural concerns: who can touch what, when, from which thread, in which session. The first pass is documentation-led so the remaining 0.9 work has a clear map.

### ~~9A  Multiplayer-Readiness Audit~~ ✅
**Source:** Camelot's session-scoped framework design (every framework engine in Camelot accepts a session context)

**Implementation:**
- `docs/architecture/multiplayer_audit.md` catalogues every autoload, shared mutable resource, and player-singleton assumption.
- Risk column maps each autoload to **Critical / High / Medium / Low** so consumers planning a co-op fork can prioritise.
- Notes on `Coven.other_coven_opinions` being a shared mutable resource, `SKEntityManager.instance` static singleton blast radius, and absent `@rpc` annotations throughout.

### ~~9B  Thread-Safety Review~~ ✅
**Source:** Pure-function boundaries from Camelot's headless framework layer

**Implementation:**
- `docs/architecture/thread_safety.md` codifies the main-thread rule.
- Concrete hazards listed with file paths: `SaveSystem.save()` file-write race, `SKEntityManager` dictionary writes, `CrimeMaster.crime_queue` producer/consumer, `NavMaster` graph mutations under path queries, `ResourceLoader` shared-instance cache.
- Safe-to-thread operations enumerated (`QuestGraphEngine.validate_graph`, `NavMaster._heap_push/pop`, `SaveSystem._compute_checksum` on captured strings).

### ~~9C  API Stability Tiers~~ ✅
**Source:** Camelot's exported/internal module split

**Implementation:**
- `docs/architecture/api_stability.md` classifies every autoload entry point, core class, save-schema key, project-setting, and group name into **Stable / Beta / Internal**.
- Stable tier gets MAJOR-bump protection; Beta tier gets MINOR-bump notice; Internal has no guarantees.
- Post-1.0 deprecation policy spelled out.

### ~~9D  Plugin Packaging~~ ✅ (partial)
**Source:** Camelot's versioned release artifacts

**Implementation:**
- `plugin.cfg` version bumped to `beta 0.8`.
- `PLUGIN_VERSION` constant in `skelerealms.gd` so the migration registry and future tooling have a single source of truth.
- AssetLib-ready minimal example project deferred to 0.9.

### ~~9E  Plugin Migration Registry~~ ✅
**Source:** `src/framework/save/save-migration-registry.ts` generalised beyond save files

**Implementation:**
- `PluginMigrationRegistry` (`scripts/system/plugin_migration_registry.gd`) — `RefCounted` helper that runs one-shot project-level migrations keyed by FROM-version.
- Installed version tracked under `skelerealms/__installed_version` and persisted via `ProjectSettings.save()`.
- Invoked from `skelerealms.gd:_enter_tree()` before any other plugin setup.
- Contract, examples, and fresh-install-vs-upgrade behaviour documented in `docs/architecture/migration_tooling.md`.
- GUT tests in `tests/test_plugin_migration_registry.gd` cover: fresh install stamping, no-op when up to date, single-step upgrade, chained multi-version upgrade, skipping migrations before the installed cursor.

| File | Purpose |
|---|---|
| `docs/architecture/multiplayer_audit.md` | Session-scoped state, player-singleton assumptions, RPC gaps |
| `docs/architecture/thread_safety.md` | Main-thread rule, per-autoload hazards, safe-to-thread operations |
| `docs/architecture/api_stability.md` | Stable / Beta / Internal tier classification and deprecation policy |
| `docs/architecture/migration_tooling.md` | Save-file vs plugin-level migration split and contract |
| `scripts/system/plugin_migration_registry.gd` | Plugin-version migration runner (project-level state) |
| `tests/test_plugin_migration_registry.gd` | GUT tests for the registry's run loop |

## Phase 10 — External Inspiration Integration ✅

This phase borrows ideas from three open-source Godot 4 addons, porting the most valuable patterns into Skelerealms' own codebase without introducing external dependencies.

### ~~10A  Behaviour Tree System~~ ✅
**Inspiration:** [BehaviourToolkit](https://github.com/ThePat02/BehaviourToolkit) (MIT) by ThePat02

Ported a self-contained behaviour tree framework designed to complement the existing GOAP system. GOAP selects *what* to do (high-level goals); behaviour trees handle *how* to do it (fine-grained action execution).

**Classes added:**

| File | Purpose |
|---|---|
| `scripts/ai/behaviour_tree/sk_bt_node.gd` | `SKBTNode` — base class with `Status` enum (`SUCCESS`, `FAILURE`, `RUNNING`) and `tick()` method |
| `scripts/ai/behaviour_tree/sk_bt_leaf.gd` | `SKBTLeaf` — leaf node for custom action/condition logic |
| `scripts/ai/behaviour_tree/sk_bt_composite.gd` | `SKBTComposite` — base for composite nodes with cached child list |
| `scripts/ai/behaviour_tree/sk_bt_decorator.gd` | `SKBTDecorator` — base for single-child wrapper nodes |
| `scripts/ai/behaviour_tree/sk_bt_root.gd` | `SKBTRoot` — tree root with idle/physics process, autostart, actor, and blackboard |
| `scripts/ai/behaviour_tree/composites/sk_bt_sequence.gd` | `SKBTSequence` — succeeds when all children succeed |
| `scripts/ai/behaviour_tree/composites/sk_bt_selector.gd` | `SKBTSelector` — succeeds when any child succeeds |
| `scripts/ai/behaviour_tree/composites/sk_bt_parallel.gd` | `SKBTParallel` — ticks all children; SUCCESS_ON_ALL or SUCCESS_ON_ONE policy |
| `scripts/ai/behaviour_tree/composites/sk_bt_random.gd` | `SKBTRandom` — randomly selects one child to execute |
| `scripts/ai/behaviour_tree/decorators/sk_bt_inverter.gd` | `SKBTInverter` — flips SUCCESS ↔ FAILURE |
| `scripts/ai/behaviour_tree/decorators/sk_bt_always_succeed.gd` | `SKBTAlwaysSucceed` — forces SUCCESS |
| `scripts/ai/behaviour_tree/decorators/sk_bt_always_fail.gd` | `SKBTAlwaysFail` — forces FAILURE |
| `scripts/ai/behaviour_tree/decorators/sk_bt_repeat.gd` | `SKBTRepeat` — repeats child N times |
| `scripts/ai/behaviour_tree/decorators/sk_bt_limiter.gd` | `SKBTLimiter` — limits child to N completions |

### ~~10B  SKBlackboard~~ ✅
**Inspiration:** BehaviourToolkit's `Blackboard` resource

| File | Purpose |
|---|---|
| `scripts/ai/sk_blackboard.gd` | `SKBlackboard` — shared key-value `Resource` with `set_value`, `get_value`, `has_value`, `erase_value`, `clear`, `serialize`/`deserialize`, and `changed` signal |

### ~~10C  Quest Template Variables~~ ✅
**Inspiration:** [Quest Weaver](https://github.com/undomick/godot_nexus_quest_weaver)'s `{target}`, `{amount}` placeholder system

- `QuestDefinition.parameters: Dictionary` — default placeholder values.
- `QuestGraphEngine.activate_quest_with_params(quest_id, params)` — merges overrides with defaults and resolves `{key}` in `quest_name`, `description`, and each node's `description` and `target_id`.
- `QuestSystem.activate_quest_with_params()` — wrapper for the autoload.
- Existing `activate_quest()` calls pass-through with empty params (fully backward-compatible).

### ~~10D  Quest "Any" Join Mode~~ ✅
**Inspiration:** Quest Weaver's parallel/synchronize flow nodes

- `QuestNodeDefinition.join_mode` enum (`ALL`, `ANY`).
- Default `ALL` preserves existing AND-join semantics (every prerequisite must be completed).
- `ANY` enables OR-join: the node activates as soon as any single prerequisite completes.
- `_are_prerequisites_completed()` updated to respect `join_mode`.

### ~~10E  Tests~~ ✅
| File | Purpose |
|---|---|
| `tests/test_behaviour_tree.gd` | GUT tests for SKBlackboard, all BT composites, and all BT decorators |
| `tests/test_quest_graph_engine.gd` | Extended with template variable and ANY/ALL join mode tests |

### GLoot — Reference Notes (no integration)
**Source:** [GLoot](https://github.com/peter-kish/gloot) by peter-kish

GLoot's inventory model (item stacking, weight/grid constraints, prototype inheritance) is architecturally incompatible with Skelerealms' entity-based item system. However, it serves as an excellent reference for future enhancements:

- **Item stacking** — `stack_size`/`max_stack_size` pattern could be adapted into `ItemComponent`.
- **Weight/capacity constraints** — could be added as optional exports on `InventoryComponent`.
- **Grid inventory** — Diablo/Resident Evil style 2D layout, useful reference if ever needed.
- **Prototype inheritance** — JSON prototree model is elegant for data-driven item definitions.
