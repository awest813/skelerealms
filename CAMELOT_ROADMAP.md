# Camelot Integration Roadmap

Ideas and implementations ported from [Camelot](https://github.com/awest813/Camelot) into SkeleRealms.

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

### 3C  Mod-Friendly Data Architecture
**Source:** `src/framework/mods/content-merge.ts`

Design coven resources, quest definitions, and entity templates with a
manifest-driven override system for mod support.

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
