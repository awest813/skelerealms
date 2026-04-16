# SkeleRealms Framework Status

## Current Version Target

**beta 0.6** (Godot 4 open-world RPG framework plugin)

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
| `scripts/components/player_component.gd` | Damage handler reads only `damage_effects[&"blunt"]` | Only blunt damage affects player health |
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
| **Player damage handling** | `scripts/components/player_component.gd:19` | Only `&"blunt"` damage type is wired; buff/debuff pipeline is not implemented |
| **Crime — reporting & response** | `scripts/crime/crime_master.gd:42`, `scripts/ai/Modules/default_crime_report.gd` | ~~Crimes against non-player entities are not tracked; the crime-reporter AI module does not attempt to aggress the perpetrator after reporting~~ Crime report module now evaluates coven membership, supports configurable other-coven reporting, and provides four confrontation resolution branches (pay fine, serve time, resist arrest, persuasion). Crimes against non-player entities are tracked. (Camelot integration) |
| **~~Threat response — investigate & friendly fire~~** ✅ | `scripts/ai/Modules/default_threat_response.gd` | Investigate-after-losing-sight state implemented with `_begin_investigate` / `_end_investigate` / `_cancel_investigate` flow. Friendly-fire response implemented based on `friendly_fire_behavior` export (Neutral/Friend/Ally). (Camelot integration) |
| **Furniture — animation & multi-use** | `scripts/points/furniture.gd:11–12` | NPC sitting/using animations are not triggered; only one NPC can use a furniture point at a time (sub-points not implemented) |
| **Save system — ~~custom filenames / save slots~~** ✅ | `scripts/system/save_system.gd` | Named save slots, schema versioning (v2) with migration registry, FNV-1a checksum validation, and `load_complete` signal are now implemented (Camelot integration) |
| **~~Entity serialization~~** ✅ | `scripts/entities/entity.gd` | Position serialized as `[x,y,z]` array, rotation as `[x,y,z,w]`, form_id persisted, safe dictionary access throughout (Camelot integration) |
| **~~Inventory/Equipment persistence~~** ✅ | `scripts/components/inventory_component.gd`, `scripts/components/equipment_component.gd` | Both components now implement `save()`/`load_data()` with dirty flag tracking (Camelot integration) |
| **~~Covens persistence~~** ✅ | `scripts/components/covens_component.gd` | Coven membership now persists across save/load with group re-sync (Camelot integration) |
| **~~Spawn tracker — persistence~~** ✅ | `scripts/points/spawn_point.gd`, `scripts/system/spawn_tracker_manager.gd` | `SpawnTrackerManager` autoload persists `spawn_tracker` via `savegame_other` group; one-shot spawner state survives restarts |
| **Barter — ~~filtering~~ & haggling** | `scripts/barter/barter.gd:21–22` | ~~Per-vendor item whitelists/blacklists are not enforced~~ `shop_will_accept_item` now correctly checks item data component types against shop whitelist/blacklist ✅; haggling (price negotiation) is not implemented |
| **Item — worth & ownership** | `scripts/components/item_component.gd:36,76,148` | Theft determination based on item worth and owner relationships is stubbed; item size is not compensated for during drop placement |
| **Network edge costs** | `scripts/network/Scripts/network.gd:55` | Edge cost assignment in the editor is not wired up |
| **~~World loader — abort handling~~** ✅ | `scripts/system/world_loader.gd` | On failure, attempts to recover previous world; pauses game as fallback; `world_loading_failed` signal emitted for UI integration |
| **Granular navigation — memory efficiency** | `scripts/granular_navigation/navigation_master.gd:246` | KD-tree uses object references; converting to packed arrays/indices is a noted optimization |
| **Audio emitter** | `scripts/misc/audio_emitter.gd:12` | Audio event propagation is physics-based; a non-physics alternative is desired |
| **~~NPC path — door interaction~~** ✅ | `scripts/components/npc_component.gd` | NPCs find nearest `Door` node and call `interact()` to teleport when path crosses a world boundary; `door_interacted` signal emitted for animation/sound hooks |

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
8. **~~Complete Crime system~~** ✅ — crime report module now evaluates coven membership, supports configurable other-coven reporting, and provides four confrontation resolution branches. Crimes against non-player entities are tracked. (Camelot integration)
9. **~~Complete Threat response~~** ✅ — investigate state, watch-state visibility check, and friendly-fire response all implemented. (Camelot integration)
10. **~~Fix Item drop direction~~** ✅ — replaced incorrect `get_euler().normalized()` with proper `-Basis(quaternion).z` forward vector.
11. **~~Fix `shop_will_accept_item`~~** ✅ — fixed type hint to `ShopComponent`, replaced `ic.data.tags` with proper `ItemDataComponent` children lookup, added null safety.

### Phase 3 — World & Persistence (needed for a complete game loop)

12. **~~Save system — custom filenames / save slots~~** ✅ — named save slots, schema versioning (v2), migration hooks, FNV-1a checksum, safe deserialization, and `load_complete` signal are now implemented.
13. **~~Spawn tracker persistence~~** ✅ — `SpawnTrackerManager` autoload serializes `NPCSpawnPoint.spawn_tracker` via the `savegame_other` group so one-shot spawner state survives game restarts.
14. **~~World loader abort handling~~** ✅ — on load failure, attempts to recover the previous world; pauses game as fallback. Added `world_loading_failed` signal for UI integration.
15. **~~NPC door interaction~~** ✅ — NPCs find the nearest `Door` node and call `interact()` to teleport when their path crosses a world boundary. Added `door_interacted` signal.

### Phase 4 — Polish & Depth (enriches the simulation)

16. **Barter — haggling** — add a haggling negotiation round. (Filtering is now implemented via `shop_will_accept_item`.)
17. **Item worth & ownership** — implement the theft-detection and item-drop-size-compensation stubs.
18. **Furniture animation & multi-use** — trigger NPC use animations; support sub-points for multiple simultaneous users.
19. **Player damage generalization** — extend the damage pipeline to all damage types and buff/debuff modifiers.
20. **Network edge costs in editor** — wire up cost assignment in the network editor toolbar.
21. **Granular navigation memory optimization** — convert the KD-tree from object references to packed arrays.
22. **Audio emitter refactor** — replace the physics-based sound propagation with a non-physics alternative.
