# API Stability

> Status: initial pass for Phase 9 — Architecture Hardening.
>
> This document classifies public Skelerealms surface area into stability
> tiers so consumers can tell at a glance what they can rely on between
> minor releases.

Skelerealms is still pre-1.0. **Anything not explicitly listed as `Stable`
can change in a minor release.** Once the framework ships 1.0 the
`Stable` tier becomes a semver commitment; until then, call this an
intention.

---

## Tiers

| Tier | Meaning | SemVer behaviour once 1.0 ships |
|---|---|---|
| **Stable** | Public API. Method signatures, signal signatures, and resource schemas will not change without a major version bump. | MAJOR bump required for breaking change. |
| **Beta** | Public API but still settling. Breaking changes are allowed in MINOR bumps if called out in the changelog. | MINOR-compatible changes only after deprecation notice. |
| **Internal** | Not intended for consumer code. May change in any release, no notice. | No guarantees, ever. |

If a method or class is not listed below, treat it as **Internal** for now.

---

## Stable

### Autoloads and their core entry points

- `GameInfo`
  - `pause_game(silent: bool = false)`, `unpause_game()`, `toggle_pause()`
  - `start_game()`
  - Signals: `pause`, `unpause`, `game_started`,
    `minute_incremented`, `hour_incremented`, `day_incremented`,
    `week_incremented`, `month_incremented`, `year_incremented`
  - Fields: `world`, `world_time`, `continuity_flags`, `paused`, `is_game_started`

- `SaveSystem`
  - `save(slot_name: String = "")`
  - `load_most_recent()`, `load_game(path: String)`, `load_slot(slot_name: String) -> bool`
  - `list_saves() -> Array[String]`
  - `register_migration(from_version: int, migration: Callable)`
  - Signals: `save_complete`, `load_complete`
  - Constant: `SAVE_SCHEMA_VERSION`

- `CovenSystem`
  - `get_coven(coven: StringName) -> Coven`
  - `add_coven(c: Coven)`, `remove_coven(id: StringName)`
  - `change_opinion(of: StringName, what: StringName, amount: int)`

- `CrimeMaster`
  - `add_crime(crime: Crime, witness: StringName)`
  - `punish_crimes(coven: StringName)`
  - `max_crime_severity(id, coven) -> int`
  - `bounty_for_coven(id, coven) -> int`
  - Signals: `crime_committed`, `crimes_against_covens_updated`

- `QuestSystem`
  - `register_quest(definition: QuestDefinition)`
  - `activate_quest(quest_id: StringName) -> bool`
  - `get_quest_status(quest_id) -> String`
  - `apply_event(event: QuestEvent)`
  - `report_kill`, `report_pickup`, `report_talk`, `report_custom`
  - `validate_quest(quest_id) -> QuestGraphEngine.QuestValidationReport`
  - Signals: `quest_activated`, `quest_completed`, `quest_updated`

- `DialogueSystem`
  - `register_dialogue(definition: DialogueDefinition)`
  - `start_dialogue(dialogue_id, context = null) -> DialogueNodeView`
  - `choose(choice_id) -> DialogueAdvanceResult`
  - `end_dialogue()`, `is_in_dialogue() -> bool`, `has_dialogue(id) -> bool`
  - Signals: `dialogue_started`, `dialogue_ended`, `choice_made`

- `SKEntityManager` (via `SKEntityManager.instance`)
  - `get_entity(id: StringName) -> SKEntity`
  - `add_entity(scene: PackedScene) -> SKEntity`
  - `remove_entity(rid: StringName)`

### Core classes

- `SKEntity` — `get_component`, `has_component`, `add_component`,
  `save`, `load_data`, `reset_data`, `broadcast_message`, `printe`
- `SKEntityComponent` — `dirty`, `save()`, `load_data()`, `reset_data()`,
  `_entity_ready()`, `on_generate()`, `gather_debug_info()`
- `Coven` resource schema — `coven_id`, `coven_name`, `member_opinions`,
  `other_coven_opinions`, `track_crime`, disposition thresholds
  (`hostile_below`, `friendly_at`, `allied_at`)

### Save schema

- Top-level keys: `schema_version`, `game_info`, `entity_data`,
  `other_data`, `checksum`
- Per-entity format: `{ "entity_data": {...}, "components": {...} }`
- `SAVE_SCHEMA_VERSION` and the migration callback contract

### Project-setting keys

All keys under `skelerealms/*` listed in `ROADMAP.md` are Stable.
Renaming or removing one requires a migration (see
`docs/architecture/migration_tooling.md`).

### Group names

- `savegame_entity`, `savegame_gameinfo`, `savegame_other` — all
  stable; the save system iterates these and is unlikely to change them.
- `audio_listener` — stable; consumed by `AudioEmitter`.

---

## Beta

APIs that work but may still change before 1.0. Use them, but pin the
plugin version you developed against.

- `ModManifest` / `ModLoader`
  - `ModLoader.load_mod(manifest)`
  - `ModManifest` fields (`covens`, `quests`, `dialogues`,
    `coven_opinion_overrides`)
- `NPCComponent` public surface (`kill()`, `is_dead`,
  `crime_confrontation`, `door_interacted`, `investigate_started`,
  `investigate_ended`)
- Barter system (`BarterSystem`, haggle API, signals)
- Granular navigation: `NavMaster`, `NavWorld`, `NavNode` — core
  behaviour is stable but the `RefCounted` refactor may still shift.
- Runtime debug overlays (`AIStateOverlay`, `NavDebugDraw`,
  `PerceptionDebugDraw`, `QuestStateInspector`) — input keys and
  exported flags may still change.

---

## Internal

Treat everything below as implementation detail. Don't call it, don't
subclass it, don't rely on its signal signatures.

- `scripts/fsm/*`
- `scripts/ai/Modules/default_*` — the default AI modules are intentionally
  replaceable; use them as reference but fork before shipping.
- `scripts/network/*` — granular navigation authoring layer
- `QuestGraphEngine._node_maps`, `_successor_maps`, and any other
  underscore-prefixed field
- `SaveSystem._serialize` / `_deserialize` / `_compute_checksum` /
  `_apply_migrations` / `_get_most_recent_savegame` — override point for
  custom formats exists, but the exact shape of the internal pipeline may
  change.
- `DialogueEngine.DialogueSessionSnapshot.serialize/deserialize` — kept
  internal until the dialogue schema settles.
- All `@tool` editor helpers under `tools/`

---

## Deprecation policy (post-1.0 plan)

After 1.0 lands:

1. A breaking change on a **Stable** surface requires a major bump and
   a migration note in `docs/user guide/migrating.md`.
2. A breaking change on a **Beta** surface requires a minor bump, a
   `@deprecated` annotation one minor ahead, and a migration note.
3. **Internal** surfaces may change in any release; do not file bugs
   about them breaking.

This policy starts at 1.0. Pre-1.0 releases can break anything.
