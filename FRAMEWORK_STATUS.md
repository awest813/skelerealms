# SkeleRealms Framework Status

## Current Version Target

**beta 0.7** (Godot 4 open-world RPG framework plugin)

---

## Autoloads

These singletons are registered by the plugin and are available globally at runtime.

| Singleton Name       | Script Path                                            | Purpose                                               |
|----------------------|--------------------------------------------------------|-------------------------------------------------------|
| `SkeleRealmsGlobal`  | `scripts/sk_global.gd`                                 | Core utilities, entity tree helpers, status-effect registry, SKConfig holder |
| `CovenSystem`        | `scripts/covens/coven_system.gd`                       | Loads and tracks all factions (Covens); manages inter-faction opinions |
| `GameInfo`           | `scripts/system/game_info.gd`                          | World-time clock, current world, continuity flags, pause state |
| `SaveSystem`         | `scripts/system/save_system.gd`                        | Serialize/deserialize game state to `user://saves/`   |
| `CrimeMaster`        | `scripts/crime/crime_master.gd`                        | Tracks crimes committed against Covens; bounty calculation |
| `DeviceNetwork`      | `scripts/misc/device_network.gd`                       | Broadcasts puzzle/device state changes (signals only) |
| `SpawnTrackerManager`| `scripts/system/spawn_tracker_manager.gd`              | Persists spawn point state across save/load cycles    |
| `ModLoader`          | `scripts/mods/mod_loader.gd`                           | Discovers and applies mod manifests at game-start     |

---

## Project Settings

All keys are under the `skelerealms/` namespace. Set automatically when the plugin is enabled.

### Gameplay

| Key                                         | Default   | Description                                                  |
|---------------------------------------------|-----------|--------------------------------------------------------------|
| `skelerealms/actor_fade_distance`           | `100.0`   | Distance (meters) at which entities enter/leave the scene    |
| `skelerealms/entity_cleanup_timer`          | `300.0`   | Seconds before a stale, off-screen entity is freed after a save |
| `skelerealms/granular_navigation_sim_distance` | `1000.0` | Distance at which off-screen NPC simulation stops entirely  |

### World Time

| Key                               | Default | Description                    |
|-----------------------------------|---------|--------------------------------|
| `skelerealms/seconds_per_minute`  | `2.0`   | Real seconds per in-game minute |
| `skelerealms/minutes_per_hour`    | `31.0`  | In-game minutes per hour        |
| `skelerealms/hours_per_day`       | `15.0`  | In-game hours per day           |
| `skelerealms/days_per_week`       | `8`     | Days per week                   |
| `skelerealms/weeks_in_month`      | `4`     | Weeks per month                 |
| `skelerealms/months_in_year`      | `8`     | Months per year                 |

### Paths

| Key                               | Default               | Description                                                 |
|-----------------------------------|-----------------------|-------------------------------------------------------------|
| `skelerealms/worlds_path`         | `res://worlds`        | Directory scanned for world scenes (`.tscn`)                |
| `skelerealms/entities_path`       | `res://entities`      | Directory scanned for entity scenes (`.tscn`)               |
| `skelerealms/covens_path`         | `res://covens`        | Directory scanned for Coven resources (`.tres`/`.res`)      |
| `skelerealms/doors_path`          | `res://doors`         | Directory for door data (referenced in settings; usage TBD) |
| `skelerealms/networks_path`       | `res://networks`      | Directory scanned for granular-navigation Network resources |
| `skelerealms/config_path`         | `res://sk_config.res` | Path to the project's `SKConfig` resource                   |

### Mods

| Key                                | Default       | Description                                                        |
|------------------------------------|---------------|--------------------------------------------------------------------|
| `skelerealms/mods_path`            | `res://mods`  | Directory scanned for `ModManifest` resources (`.tres`/`.res`)     |

### Misc

| Key                                | Default | Description                                                   |
|------------------------------------|---------|---------------------------------------------------------------|
| `skelerealms/savegame_indents`     | `true`  | Whether JSON save files are pretty-printed with indentation   |
| `skelerealms/entity_archetypes`    | (array) | Default NPC and item template scene paths shown in the editor |

---

## Required Folders

These directories must exist in the consuming project. They are read at startup; missing folders cause errors or silent failures.

| Path                | When Read              | Notes                                                  |
|---------------------|------------------------|--------------------------------------------------------|
| `res://worlds`      | `WorldLoader._ready`   | Must contain at least one `.tscn` world scene          |
| `res://entities`    | `SKEntityManager._ready` | All entity `.tscn` files discovered recursively      |
| `res://covens`      | `CovenSystem` on game-start | Coven `.tres`/`.res` resources                    |
| `res://networks`    | `NavMaster.load_all_networks` on game-start | Granular-navigation Network `.tres` resources |
| `res://doors`       | Referenced in settings | Scanning not yet implemented in code (see TODOs)       |
| `user://saves/`     | `SaveSystem` on first save | Created automatically by `DirAccess.make_dir_recursive_absolute` |

---

## Hard-coded Assumptions

Values baked into the source that a consumer cannot override via settings or `SKConfig` without editing the addon.

| Location | Assumption | Impact |
|---|---|---|
| `scripts/constants.gd` | Default currency key is `&"snails"` (`SKConstants.DE_FACTO_CURRENCY`) | Any code that reads this const uses the literal string `snails` |
| `scripts/crime/crime_master.gd` | Bounty amounts: `{0:0, 1:500, 2:10000, 5:100000}` | Crime severity → gold mapping is fixed |
| `scripts/components/vitals_component.gd` | ~~`DISHONORED_MODE = false` — gates whether will recharges instantly after casting~~ Now configurable via `is_player` and `dishonored_mode` exports ✅ | Configure via inspector exports |
| `scripts/system/game_info.gd` | World-time timer fires every real second (`$Timer.start(1)`) | Timer granularity is 1 s regardless of `seconds_per_minute` |
| `scripts/system/game_info.gd` | `Input.MOUSE_MODE_CAPTURED` on `_ready` | Overrides mouse mode unconditionally at startup |
| `scripts/entities/entity.gd` | Component lookup uses child node name == class name string (e.g., `get_node_or_null("NPCComponent")`) | Entity component naming is a strict contract |
| `scripts/components/player_component.gd` | Hardcoded sibling paths `$"../TeleportComponent"` and `$"../DamageableComponent"` | Player entity must include both components as siblings |
| `scripts/components/player_component.gd` | ~~Damage handler reads only `damage_effects[&"blunt"]`~~ Now iterates all damage types with configurable `damage_modifiers` dictionary export ✅ | Configure per-type resistances via inspector |
| `scripts/components/npc_component.gd` | Off-screen walk speed `_walk_speed = 1` (m/s) | All NPCs move at the same speed when not in scene |
| `scripts/components/npc_component.gd` | Path follow end distance `_path_follow_end_distance = 1` (m) | Snap-to-point threshold is fixed |
| `scripts/components/npc_component.gd` | `visibility_threshold = 0.3` | NPC ignores targets below this light/visibility level |
| `scripts/ai/perception_eyes.gd` | Perception tick interval `perception_interval = 0.25` s | Fixed perception rate for all NPC eyes |
| `scripts/skelerealms.gd` | Editor ray length `RAY_LENGTH = 500`, snap distance `SNAP_DISTANCE = 0.1` | Editor network-point placement constants |
| `scripts/system/save_system.gd` | ~~Save path always `user://saves/<datetime>.dat`~~ | Named save slots now supported via `save(slot_name)` and `load_slot(slot_name)` |
| `scripts/entities/entity_manager.gd` | Entity ref-ID == scene filename (without extension) | File naming is a strict contract for entity identity |

---

## Known Broken Systems

These features have been explicitly flagged as broken, or contain code that provably cannot function correctly.

### ~~1. Barter — `shop_will_accept_item`~~ ✅ FIXED
- **File:** `scripts/barter/barter.gd:108`
- **Fix:** Fixed type hint to `ShopComponent`, replaced incorrect `ic.data.tags` reference with proper `ItemDataComponent` children lookup via `get_type()`, added null safety checks for entity and component access.

### ~~2. GOAP — Objective assignment after planning~~ ✅ FIXED
- **File:** `scripts/components/goap_component.gd:49`
- **Fix:** Moved `_current_objective = o` assignment to before `_pop_action()` so the planner correctly tracks which objective is active from the moment the plan starts executing. This prevents the one-frame re-planning window.

### 3. ~~GOAP — Graph search algorithm is depth-first, not breadth-first~~ ✅ FIXED
- **File:** `scripts/components/goap_component.gd`
- **Fix:** Rewrote `_build_graph` to use BFS (iterative queue) so action plans are cost-optimal. (Camelot integration)

### 4. ~~Coven NPC-opinion lookup~~ ✅ FIXED
- **File:** `scripts/components/npc_component.gd`
- **Fix:** Replaced the nonexistent `get_covennpc_opinions()` call with the correct `get_coven_opinions()`, which returns this coven's opinion of the other entity's covens. (Camelot integration)

### ~~5. Granular Navigation — connections never loaded~~ ✅ FIXED
- **Files:** `scripts/granular_navigation/navigation_master.gd`, `scripts/granular_navigation/navigation_node.gd`
- **Fix:** Implemented `_load()` for deferred portal connections, added `save()`/`load_data()`/`reset_data()` methods for connection persistence via the save system, fixed portal_edges append bug, and added a node lookup table. NavMaster now registers with the `savegame_other` group so connections survive across sessions.

### 6. ~~Skelesave — `deserialize` always returns empty dictionary~~ ✅ FIXED
- **File:** `scripts/misc/skelesave.gd:82–100`
- **Fix:** The `while` loop now correctly writes `current_key` → `_decode_value(current_phrase)` into `output` on each `VALUE_DELIM` token. The `_decode_value` array path was also completed. (Critical bug fix)

### ~~7. Item drop — direction calculation~~ ✅ FIXED
- **File:** `scripts/components/item_component.gd:136`
- **Fix:** Replaced incorrect `drop_dir.get_euler().normalized()` with proper `-Basis(quaternion).z` forward vector. Items now drop in front of the entity correctly.

---

## Known Incomplete Systems

These systems exist and partially work, but have documented gaps.

| System | File(s) | Missing Pieces |
|---|---|---|
| **~~Perception (FOV)~~** ✅ | `scripts/ai/perception_eyes.gd` | Vertical FOV check now uses pitch angle comparison; AABB-based occlusion coverage percentage calculated via multi-point raycast sampling; horizontal check uses proper `cos(deg_to_rad())` threshold |
| **~~Vitals (generalized)~~** ✅ | `scripts/components/vitals_component.gd` | Now works for both player and NPC entities; `is_player` and `dishonored_mode` exports gate player-specific mechanics; recharge rates are configurable via `@export` |
| **~~Player damage handling~~** ✅ | `scripts/components/player_component.gd` | `on_damage()` now iterates all damage types with configurable `damage_modifiers` dictionary export; handles moxie/will attribute damage separately; applies spell effects via `SpellTargetComponent` |
| **~~Crime — reporting & response~~** ✅ | `scripts/crime/crime_master.gd`, `scripts/ai/Modules/default_crime_report.gd`, `scripts/ai/Modules/default_damage_module.gd` | Crime report module evaluates coven membership, supports configurable other-coven reporting, and provides four confrontation resolution branches. Fixed `crime_committed` signal type (`NavPoint` → `Vector3`). Added null safety for missing victim entities. Assault and murder crimes are now broadcast from `DefaultDamageModule` when health damage is dealt by another entity, completing non-player crime tracking. |
| **~~Threat response — investigate & friendly fire~~** ✅ | `scripts/ai/Modules/default_threat_response.gd` | Investigate-after-losing-sight state implemented with `_begin_investigate` / `_end_investigate` / `_cancel_investigate` flow. Friendly-fire response implemented based on `friendly_fire_behavior` export (Neutral/Friend/Ally). (Camelot integration) |
| **~~Furniture — animation & multi-use~~** ✅ | `scripts/points/furniture.gd` | `max_users` export with sub-point support via child `IdlePoint` nodes; `play_animation`/`stop_animation` signals emitted on occupy/unoccupy for animation hooks; `occupy()`/`unoccupy_entity()`/`has_room()` API |
| **Save system — ~~custom filenames / save slots~~** ✅ | `scripts/system/save_system.gd` | Named save slots, schema versioning (v2) with migration registry, FNV-1a checksum validation, and `load_complete` signal are now implemented (Camelot integration) |
| **~~Entity serialization~~** ✅ | `scripts/entities/entity.gd` | Position serialized as `[x,y,z]` array, rotation as `[x,y,z,w]`, form_id persisted, safe dictionary access throughout (Camelot integration) |
| **~~Inventory/Equipment persistence~~** ✅ | `scripts/components/inventory_component.gd`, `scripts/components/equipment_component.gd` | Both components now implement `save()`/`load_data()` with dirty flag tracking (Camelot integration) |
| **~~Covens persistence~~** ✅ | `scripts/components/covens_component.gd` | Coven membership now persists across save/load with group re-sync (Camelot integration) |
| **~~Spawn tracker — persistence~~** ✅ | `scripts/points/spawn_point.gd`, `scripts/system/spawn_tracker_manager.gd` | `SpawnTrackerManager` autoload persists `spawn_tracker` via `savegame_other` group; one-shot spawner state survives restarts |
| **~~Barter — filtering & haggling~~** ✅ | `scripts/barter/barter.gd` | `shop_will_accept_item` correctly checks item data component types against shop whitelist/blacklist; `haggle()` method with skill-factor-based negotiation using `ShopComponent.haggle_tolerance`, configurable `max_haggle_attempts`, `haggle_succeeded`/`haggle_failed` signals; haggle modifier auto-applied on `accept_barter` |
| **~~Item — worth & ownership~~** ✅ | `scripts/components/item_component.gd` | `worth` export for monetary value; `item_radius` export for drop-position wall offset; `_is_theft_for()` checks coven disposition — items owned by entities sharing friendly/allied covens are not theft; `stolen` and `worth` persisted in save data |
| **~~Network edge costs~~** ✅ | `scripts/network/Scripts/network.gd` | `dissolve_point()` sums costs from dissolved edges; `merge_points()` uses distance-based costs; `subdivide_edge()` splits cost in half; editor cost popup wired to `find_edge().cost` |
| **~~World loader — abort handling~~** ✅ | `scripts/system/world_loader.gd` | On failure, attempts to recover previous world; pauses game as fallback; `world_loading_failed` signal emitted for UI integration |
| **~~Granular navigation — memory efficiency~~** ✅ | `scripts/granular_navigation/navigation_master.gd`, `navigation_node.gd`, `navigation_world.gd` | `NavNode` converted from `Node3D` to `RefCounted`; `NavWorld` converted from `Node` to `RefCounted`; eliminates scene tree overhead per navigation point; explicit `parent_node`/`position`/`node_name` fields replace inherited Node properties |
| **~~Audio emitter~~** ✅ | `scripts/misc/audio_emitter.gd` | Replaced physics-based `PhysicsShapeQueryParameters3D` sphere query with direct distance checks against `audio_listener` group members using `global_position`; no physics bodies required |
| **~~NPC path — door interaction~~** ✅ | `scripts/components/npc_component.gd` | NPCs find nearest `Door` node and call `interact()` to teleport when path crosses a world boundary; `door_interacted` signal emitted for animation/sound hooks |
| **~~Mod-friendly data architecture~~** ✅ | `scripts/mods/mod_manifest.gd`, `scripts/mods/mod_loader.gd`, `scripts/mods/coven_opinion_override.gd` | `ModManifest` resource declares covens, quests, dialogues, and coven opinion overrides. `ModLoader` autoload scans `skelerealms/mods_path` (default `res://mods`) at game-start and registers all declared content; `load_mod()` is also callable programmatically. |

---

## Roadmap Order

Ordered by dependency depth and severity. Fix broken systems before building on top of them.

### Phase 1 — Critical Fixes (nothing downstream works correctly without these)

1. **~~Fix `Skelesave.deserialize`~~** ✅ — the deserialization loop now correctly populates the output dictionary; array decoding also completed.
2. **~~Fix GOAP breadth-first search~~** ✅ — `_build_graph` rewritten to BFS so action plans are reliably cost-optimal. (Camelot integration)
3. **~~Fix GOAP objective assignment~~** ✅ — moved `_current_objective` assignment before `_pop_action()` so the planner correctly tracks which objective is active.
4. **~~Fix Granular Navigation connections~~** ✅ — implemented `_load()` for deferred portal connections, added save/load persistence via `savegame_other` group, fixed portal_edges append bug.
5. **~~Fix Coven NPC-opinion lookup~~** ✅ — corrected to use `get_coven_opinions()`; NPC hostility calculations now work correctly for coven-aligned characters. (Camelot integration)

### Phase 2 — Core Gameplay Gaps (needed for a playable loop)

6. **~~Generalize `VitalsComponent`~~** ✅ — decoupled from player-only use; `is_player` and `dishonored_mode` exports gate player-specific mechanics; recharge rates are configurable via `@export`.
7. **~~Complete Perception FOV~~** ✅ — vertical FOV check using pitch angle, AABB coverage percentage via multi-point raycast sampling, horizontal check uses proper `cos(deg_to_rad())` threshold.
8. **~~Complete Crime system~~** ✅ — crime report module now evaluates coven membership, supports configurable other-coven reporting, and provides four confrontation resolution branches. Crimes against non-player entities are tracked. `DefaultDamageModule` now broadcasts assault and murder crimes. Fixed `crime_committed` signal type and null safety in `_process_crime_queue`. (Camelot integration)
9. **~~Complete Threat response~~** ✅ — investigate state, watch-state visibility check, and friendly-fire response all implemented. (Camelot integration)
10. **~~Fix Item drop direction~~** ✅ — replaced incorrect `get_euler().normalized()` with proper `-Basis(quaternion).z` forward vector.
11. **~~Fix `shop_will_accept_item`~~** ✅ — fixed type hint to `ShopComponent`, replaced `ic.data.tags` with proper `ItemDataComponent` children lookup, added null safety.

### Phase 3 — World & Persistence (needed for a complete game loop)

12. **~~Save system — custom filenames / save slots~~** ✅ — named save slots, schema versioning (v2), migration hooks, FNV-1a checksum, safe deserialization, and `load_complete` signal are now implemented.
13. **~~Spawn tracker persistence~~** ✅ — `SpawnTrackerManager` autoload serializes `NPCSpawnPoint.spawn_tracker` via the `savegame_other` group so one-shot spawner state survives game restarts.
14. **~~World loader abort handling~~** ✅ — on load failure, attempts to recover the previous world; pauses game as fallback. Added `world_loading_failed` signal for UI integration.
15. **~~NPC door interaction~~** ✅ — NPCs find the nearest `Door` node and call `interact()` to teleport when their path crosses a world boundary. Added `door_interacted` signal.

### Phase 4 — Polish & Depth (enriches the simulation) ✅

16. **~~Barter — haggling~~** ✅ — `haggle()` method with skill-factor-based negotiation using `ShopComponent.haggle_tolerance`; configurable max attempts; `haggle_succeeded`/`haggle_failed` signals; haggle modifier auto-applied on `accept_barter`.
17. **~~Item worth & ownership~~** ✅ — `worth` and `item_radius` exports; coven-disposition-based theft detection via `_is_theft_for()`; item radius wall offset on drop; `stolen` and `worth` persisted.
18. **~~Furniture animation & multi-use~~** ✅ — `max_users` export with child `IdlePoint` sub-points; `play_animation`/`stop_animation` signals; `occupy()`/`unoccupy_entity()`/`has_room()` API.
19. **~~Player damage generalization~~** ✅ — iterates all damage types with configurable `damage_modifiers` dictionary; handles moxie/will attribute damage; applies spell effects via `SpellTargetComponent`.
20. **~~Network edge costs in editor~~** ✅ — `dissolve_point()` sums costs; `merge_points()` uses distance-based costs; `subdivide_edge()` splits cost in half.
21. **~~Granular navigation memory optimization~~** ✅ — `NavNode` converted from `Node3D` to `RefCounted`; `NavWorld` from `Node` to `RefCounted`; eliminates scene tree overhead per navigation point.
22. **~~Audio emitter refactor~~** ✅ — replaced physics-based sphere query with direct distance checks against `audio_listener` group members.
23. **~~Crime — non-player tracking completeness~~** ✅ — `DefaultDamageModule` broadcasts `assault` and `murder` crimes via `CrimeMaster.crime_committed` when health damage is dealt by another entity. Fixed `crime_committed` signal type (`NavPoint` → `Vector3`) and added null safety in `_process_crime_queue`.
24. **~~Mod-friendly data architecture~~** ✅ — `ModManifest` resource (covens, quests, dialogues, coven opinion overrides); `ModLoader` autoload scans `res://mods` at game-start and registers all declared content. `skelerealms/mods_path` project setting controls the scan directory.

### Phase 5 — Quality & Documentation ✅

25. **~~User-guide documentation for new systems~~** ✅ — Added `docs/user guide/quests.md`, `docs/user guide/dialogue.md`, `docs/user guide/save_system.md`, and `docs/user guide/mods.md`. Updated `docs/intro.md` table of contents with all guide pages.
26. **~~Integration test coverage~~** ✅ — GUT-compatible test suites added: `tests/test_quest_graph_engine.gd` (registration, activation, event advancement, partial progress, parallel nodes, snapshot/restore, graph validation), `tests/test_dialogue_engine.gd` (session creation, choice conditions, effects, terminal nodes, snapshot/restore), `tests/test_barter.gd` (haggle arithmetic, sell/buy toggling, cancel signals). See `tests/README.md` for how to run.
27. **~~QuestGraphEngine performance~~** ✅ — Added `_node_maps` and `_successor_maps` dictionaries built at `register_quest` time, eliminating repeated O(n) linear scans in `_get_immediate_next_node_ids`, `_are_prerequisites_completed`, `_activate_implicit_nodes`, and `_get_all_successors` during `apply_event` and `validate_graph`.

### Phase 6 — Debug, Audit & Polish

28. **~~NPC damage accumulation bug~~** ✅ — `DefaultDamageModule.process_damage()` used `=` (assignment) instead of `+=` for `accumulated_damage`, meaning only the last damage type in a multi-type `DamageInfo` was applied. Fixed to `+=` so all damage types stack correctly.
29. **~~Barter null safety~~** ✅ — Added null checks on `vendor.parent_entity` in `start_barter()` and safe entity/component lookups in `accept_barter()` item-move loops to prevent null reference errors.
30. **~~Debug print cleanup~~** ✅ — Replaced 15+ bare `print()` calls in `default_threat_response.gd` with entity-tagged `_npc.printe()` logging. Removed 7 debug `print()` calls from `world_loader.gd` and converted the directory-error print to `push_warning()`. Fixed stray `print()` calls in `coven_system.gd` (→ `push_warning()`) and `machine_perception.gd` (removed).
31. **~~Additional test suites~~** ✅ — Added GUT test suites for: coven disposition thresholds (`tests/test_coven_disposition.gd`), network edge cost computation (`tests/test_network_edge_costs.gd`), and save system internals (`tests/test_save_system.gd`) covering checksum computation, serialization round-trip, migration pipeline, and v1→v2 migration specifics.

### Phase 7 — Performance Profiling & Optimization ✅

32. **~~GOAP per-frame sorting and action filtering~~** ✅ — `GOAPComponent._process()` no longer sorts objectives or filters/maps child nodes every frame. Objectives are sorted only when the `_objectives_dirty` flag is set (on add/remove). Child `GOAPAction` nodes are cached in `_cached_actions` and rebuilt only when `_actions_dirty` is set.
33. **~~Entity fade-distance caching~~** ✅ — `SKEntity._should_be_in_scene()` now caches `actor_fade_distance²` on first access instead of calling `ProjectSettings.get_setting()` every frame for every entity.
34. **~~NPC perception entity-reference caching~~** ✅ — `NPCComponent._process()` perception loop now maintains an `_entity_ref_cache` dictionary mapping perceived `Object` → `SKEntity`, avoiding repeated `SkeleRealmsGlobal.get_entity_in_tree()` tree walks every frame per visible object.
35. **~~A* binary heap~~** ✅ — `NavMaster.calculate_path()` replaced per-iteration `Array.sort_custom()` (O(n log n) per step) with a binary min-heap using `_heap_push()`/`_heap_pop()` static helpers (O(log n) per insertion/extraction). Closed-list membership check also changed from `Array.has()` (O(n)) to `Dictionary.has()` (O(1)).
36. **~~CrimeMaster empty-queue early exit~~** ✅ — `CrimeMaster._process()` now returns immediately when `crime_queue` is empty, avoiding the function call and loop setup overhead on every frame.
37. **~~NavMaster debug print cleanup~~** ✅ — Removed 6 remaining bare `print()` calls from `navigation_master.gd` (`add_point`, `_load_from_networks`, `_load_from_disk`, `load_all_networks`). One deferred-connection message converted to `push_warning()`.
38. **~~Performance test suite~~** ✅ — Added `tests/test_perf_optimizations.gd` with GUT tests covering: binary heap ordering (ascending, single-element, duplicate scores, large input), GOAP dirty-flag tracking (add/remove/empty-remove), action cache rebuild, and entity fade-distance cache initialization.
