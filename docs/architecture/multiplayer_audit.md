# Multiplayer-Readiness Audit

> Status: initial audit for Phase 9 — Architecture Hardening.
>
> Skelerealms was designed around a single-client, single-session assumption.
> This document catalogues the places that assumption shows up, so projects
> considering a multiplayer fork (authoritative-server co-op, for the most
> part — large-scale shards were never a goal) can see the shape of the work.

This is a survey, not an implementation plan. Nothing here says "Skelerealms
will ship multiplayer"; it says "if you want to, here is where the session
boundaries are currently fused to the process".

---

## Session model

The framework assumes **one active game session per process**. All runtime
state lives behind `Node`-based autoloads that are scoped to the scene tree,
which is itself process-global. There is no `peer_id`/`session_id` concept,
and no abstraction between "the current world" and "a client's view of the
world".

A server-authoritative build needs either:

1. One Godot process per game session, and a thin connector layer on top, or
2. A refactor that lifts the autoload state into one or more `Session`
   instances that the autoloads look up by peer / room ID.

Option 1 is realistic today; option 2 is what Phase 9+ work would enable if it
becomes a goal.

---

## Autoload inventory

| Autoload | Script | Session-scoped state | Risk |
|---|---|---|---|
| `SkeleRealmsGlobal` | `scripts/sk_global.gd` | `world_states`, `status_effects`, `config` | **High** — `world_states` is the GOAP blackboard. Shared across every NPC. |
| `GameInfo` | `scripts/system/game_info.gd` | `world`, `world_time`, `continuity_flags`, `paused`, `world_origin`, `$Timer` | **Critical** — single clock, single "current world", single pause flag. |
| `SaveSystem` | `scripts/system/save_system.gd` | `_migrations`, file I/O under `user://saves/` | **High** — writes to a process-wide save directory. |
| `SKEntityManager` *(scene-scoped, not autoloaded, but exposes `static var instance`)* | `scripts/entities/entity_manager.gd` | `entities`, `disk_assets` | **Critical** — `static var instance` means the last-instantiated manager wins. Multiple simultaneous sessions would stomp each other. |
| `CovenSystem` | `scripts/covens/coven_system.gd` | `covens` dict; mutates `Coven.other_coven_opinions` in place | **High** — opinion deltas are applied to the shared resource. Every client would see the same deltas, or clients would diverge if they apply them locally. |
| `CrimeMaster` | `scripts/crime/crime_master.gd` | `crimes`, `crime_queue` | **Medium** — a crime has a single `perpetrator` ID. In a co-op world, is the crime tracked against the victim's session or the perpetrator's? Not decided. |
| `QuestSystem` / `DialogueSystem` | `scripts/quests/quest_system.gd`, `scripts/dialogue/dialogue_system.gd` | `engine` (runtime quest state + node progress), `active_session` (dialogue) | **High** — quest progress is global. In co-op, per-player progress is almost certainly what you want. |
| `SpawnTrackerManager` | `scripts/system/spawn_tracker_manager.gd` | `spawn_tracker` | Medium — spawner cooldowns/one-shots are global. |
| `ModLoader` | `scripts/mods/mod_loader.gd` | `loaded_mods` | Low — load-once, read-mostly after startup. |
| `DeviceNetwork` | `scripts/misc/device_network.gd` | Signals only | Low. |

### Shared mutable resources

Some resources are loaded once via `ResourceLoader.load()` and then mutated at
runtime. In Godot, those instances are shared across every code path that
loaded them. Two autoloads treating a resource as per-session state would
silently interfere. Notable cases:

- `Coven.other_coven_opinions` — mutated by `CovenSystem.change_opinion()`
  and by `ModLoader` at startup via `CovenOpinionOverride`.
- `QuestDefinition` nodes — the engine does not mutate definitions directly
  (runtime state lives in `QuestRuntimeState`), so these are safe.
- `DialogueDefinition` nodes — same; runtime state is in `DialogueSession`.
- `SKConfig` — loaded into `SkeleRealmsGlobal.config` and reloaded on
  `ProjectSettings.settings_changed`. Content-only, not session state.

---

## Player-identity assumptions

Several systems hardcode the concept of "the" player.

| Location | Assumption |
|---|---|
| `scripts/components/player_component.gd` | Hardcoded sibling paths (`$"../TeleportComponent"`, `$"../DamageableComponent"`) and a single player entity. |
| `scripts/components/vitals_component.gd` | `is_player` export gates player-only mechanics; there is no notion of which player. |
| `scripts/system/game_info.gd:world_origin` | Falls back to `get_viewport().get_camera_3d()` — one camera, one origin. |
| `SKEntity._should_be_in_scene()` | Compares position against a single `GameInfo.world_origin`. Entities would need per-client visibility for split-world co-op. |
| `scripts/ai/...` (perception, threat, crime) | The "player" is often the implicit target resolved via `PlayerComponent`. |

For a co-op game with a small number of players, the cheapest path is to keep
`world_origin` a single tracked node and just duplicate the actor-fade check
per player. That would push "player" into a list, not a singleton.

---

## Save system — single-writer assumption

`SaveSystem.save()` writes to `user://saves/<slot>.dat`. It is not guarded
against concurrent calls — two threads or two sessions calling `save()` at
once would race on `FileAccess.open(..., WRITE)`. Named slots help if the
conflicting sessions use different slot names, but nothing enforces that.

For multiplayer, saves should be server-authoritative. The client shouldn't
be running `save()` at all; the server should. See also
`docs/architecture/thread_safety.md` for the concurrent-write discussion.

---

## Networking primitives — initial `@rpc` pass ✅ (partial)

An initial `@rpc` annotation pass landed as part of Phase 9 remaining work.

**Authority-only state transitions** (server drives these; clients must not call
them without going through the authority):

| Method | Annotation | Rationale |
|---|---|---|
| `QuestSystem.activate_quest` | `@rpc("authority", "reliable")` | Server activates quests for all players |
| `QuestSystem.activate_quest_with_params` | `@rpc("authority", "reliable")` | Same |
| `QuestSystem.apply_event` | `@rpc("authority", "reliable")` | Server drives quest progress |
| `CrimeMaster.punish_crimes` | `@rpc("authority", "reliable")` | Server settles crime state |

**Any-peer event reporting** (clients report what happened; server processes it):

| Method | Annotation | Rationale |
|---|---|---|
| `QuestSystem.report_kill` | `@rpc("any_peer", "call_local", "reliable")` | Client reports a kill event |
| `QuestSystem.report_pickup` | `@rpc("any_peer", "call_local", "reliable")` | Client reports picking up an item |
| `QuestSystem.report_talk` | `@rpc("any_peer", "call_local", "reliable")` | Client reports a talk interaction |
| `QuestSystem.report_custom` | `@rpc("any_peer", "call_local", "reliable")` | Client reports a custom event |
| `CrimeMaster.add_crime` | `@rpc("any_peer", "call_local", "reliable")` | Witness reports a crime |
| `DialogueSystem.end_dialogue` | `@rpc("any_peer", "call_local", "reliable")` | Either side can end a dialogue |

**Not annotated** — methods with non-trivial return values that callers depend on
(e.g., `DialogueSystem.start_dialogue`, `DialogueSystem.choose`) are omitted
because RPC return values are not forwarded to the caller. A server-authoritative
dialogue flow would need a separate signal-based or callback contract.

`@rpc` annotations do not affect single-player behaviour. The annotations mark
intent; actual RPC wiring requires a multiplayer peer to be configured.

**Remaining:**

3. Decide whether AI simulation is server-only or client-predicted. GOAP is
   expensive enough that server-only is the sensible default, but perception
   ticks at 0.25 s per NPC so bandwidth is not free.

The framework is **not** RPC-ready end-to-end. These annotations are the
first step; full multiplayer support requires the session-refactor and
`@rpc` wiring described in the Recommendations section below.

---

## Recommendations

For a project that needs a single-player experience with maybe a 2–4 player
co-op stretch goal, the recommended path is:

1. Keep Skelerealms single-client for now.
2. Wrap the whole framework behind a server process. Each connected client
   sends inputs; the server runs the simulation and ships `@rpc` state deltas
   back.
3. Contain the blast radius of the player-singleton assumption by introducing
   a `players: Array[SKEntity]` on `GameInfo` and deprecating `world_origin`
   in favour of a `get_origin_for(peer_id)` style accessor.

A full peer-to-peer, shared-world experience is out of scope for 1.0.
