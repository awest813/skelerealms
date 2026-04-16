# Camelot Integration Roadmap

Ideas and implementations ported from [Camelot](https://github.com/awest813/Camelot) into SkeleRealms.

Camelot is a TypeScript/Babylon.js browser RPG framework. Its headless framework layer
(`src/framework/`) contains engine-agnostic systems for quests, dialogue, factions,
saves, and mods — all well-tested. The algorithms and architectural patterns translate
directly to GDScript even though the runtime is different.

---

## Phase 1 — New Systems (HIGH value, fills the biggest stated gaps)

### 1A  Quest System
**Source:** `src/framework/quests/quest-graph-engine.ts`

SkeleRealms explicitly lists "Quests" as missing in its README. Camelot's
`QuestGraphEngine` provides:

- Directed-acyclic-graph quest structure with prerequisites and `next_node_ids`.
- `activate_quest` / `apply_event` / `get_snapshot` / `restore_snapshot` API.
- Built-in `validate_graph()` — BFS reachability, dead-end detection, cycle detection.
- Kill / Fetch / Talk / Custom trigger types with progress counters and XP rewards.

**Files created:**
| File | Purpose |
|---|---|
| `scripts/quests/quest_types.gd` | Resource classes: `QuestNodeDefinition`, `QuestDefinition`, `QuestEvent`, etc. |
| `scripts/quests/quest_graph_engine.gd` | Core engine — `register_quest`, `activate_quest`, `apply_event`, `validate_graph`, snapshot/restore |
| `scripts/quests/quest_system.gd` | Autoload singleton — loads quest definitions, wires save integration |

### 1B  Dialogue System
**Source:** `src/framework/dialogue/dialogue-engine.ts`

Also explicitly missing from SkeleRealms. Camelot's `DialogueEngine` provides:

- Branching dialogue trees with typed conditions (reputation, flags, items, skills)
  and effects (set flag, adjust reputation, give/consume items, activate quest).
- Session-based API so dialogue data stays decoupled from runtime state.
- Snapshot/restore for save integration.

**Files created:**
| File | Purpose |
|---|---|
| `scripts/dialogue/dialogue_types.gd` | Resource classes: `DialogueNode`, `DialogueChoice`, `DialogueDefinition`, etc. |
| `scripts/dialogue/dialogue_engine.gd` | Core engine — `register_dialogue`, `create_session`, session `choose()` / snapshot |
| `scripts/dialogue/dialogue_system.gd` | Autoload singleton — loads definitions, coordinates with other systems |

---

## Phase 2 — Bug Fixes & Enhancements (MEDIUM-HIGH value)

### 2A  GOAP BFS Fix
**Source:** Camelot's `validateGraph()` BFS pattern

SkeleRealms' `_build_graph` in `goap_component.gd` is documented as broken
depth-first (FRAMEWORK_STATUS Phase 1 #2). Rewrite to BFS (explicit queue,
visited set) so action plans are cost-optimal.

### 2B  Save System Enhancements
**Source:** `src/framework/save/save-engine.ts`, `save-migration-registry.ts`

- **Named save slots** — accept an optional `slot_name` parameter; file becomes
  `user://saves/<slot_name>.dat` (falls back to datetime).
- **Schema versioning** — embed `schema_version` in every save; run registered
  migrations in order on load.
- **FNV-1a checksum** — detect corruption before attempting to parse.

### 2C  Faction Disposition Thresholds
**Source:** `src/framework/factions/faction-engine.ts`

Add per-coven configurable `hostile_below`, `friendly_at`, `allied_at` thresholds
and a `get_disposition()` helper returning `hostile / neutral / friendly / allied`.
This also fixes FRAMEWORK_STATUS Phase 1 #5 (coven NPC-opinion lookup).

---

## Phase 3 — Feature Ideas (MEDIUM value, future work)

### 3A  AI Investigate State
**Source:** Camelot AI description

Complete the investigate stub in `default_threat_response.gd`:
on losing sight → record `last_known_position` → navigate there → if nothing
found, return to patrol.

### 3B  Guard Challenge / Crime Response
**Source:** Camelot's Guard Challenge Modal

Complete `default_crime_report.gd` with four response branches:
pay fine, serve jail time, resist arrest, attempt persuasion.

### 3C  Mod-Friendly Data Architecture
**Source:** `src/framework/mods/content-merge.ts`

Design coven resources, quest definitions, and entity templates with a
manifest-driven override system for mod support.
