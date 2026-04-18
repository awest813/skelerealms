# Thread-Safety Review

> Status: initial audit for Phase 9 — Architecture Hardening.
>
> Skelerealms is a **single-threaded framework**. All autoloads, components,
> and systems run on Godot's main thread and rely on that for ordering
> guarantees. This document lists the places that assumption is baked in,
> and the concrete hazards a consumer would hit if they reached for Godot's
> threading APIs without restraint.

---

## The ground rule

> If you touch Skelerealms state from anywhere other than the main thread,
> you are on your own. No autoload in this framework is thread-safe.

The engine itself offers `Thread`, `WorkerThreadPool`, and `Mutex` for the
cases where you genuinely need parallelism (asset loading, background
pathfinding). Nothing in Skelerealms uses them, and nothing in Skelerealms
guards against other code using them.

---

## Known sharp edges

### ~~`SaveSystem.save()` — file I/O is not serialised~~ ✅ Fixed

`scripts/system/save_system.gd`

`save()` reads the most recent savegame, merges it, and writes a new file.
A re-entrant or concurrent call (e.g., two `call_deferred` chains racing a user
click) would race on the merge step and on the output file.

**Fix (Phase 9 remaining):**
- Added `_saving: bool` guard — a second call to `save()` while one is already in
  progress pushes a warning and returns immediately, preventing the merge race.
- Converted the write path to a **tmp-file + rename** pattern: the serialised data
  is first written to `<slot>.tmp`, then renamed to `<slot>.dat`. On any
  POSIX-like filesystem the rename is atomic, so a crash or error during writing
  cannot produce a partial `.dat` file. On Windows the rename replaces any
  existing file atomically as long as both files are on the same volume.

**Remaining limitation:** the guard is a reentrancy fence, not a mutex. Calling
`save()` from a worker thread while the main thread is also inside `save()` is
still a race — the flag itself is not read/written atomically outside the main
thread. The main-thread-only rule from the ground rule above still applies.

### `SKEntityManager` — static singleton, no locking

`scripts/entities/entity_manager.gd`

```
static var instance: SKEntityManager
```

`get_entity`, `add_entity`, `remove_entity`, and `_cleanup_stale_entities`
all mutate the `entities` dictionary without synchronisation. `get_entity`
also has a side effect: it rehydrates entities from the save file via
`SaveSystem.entity_in_save`, which opens a file. Calling `get_entity` from
a worker thread would both race the dictionary and race the save-file
lock.

### `CrimeMaster.crime_queue` — producer/consumer on the main thread

`scripts/crime/crime_master.gd`

`add_crime` writes into `crime_queue`; `_process` drains it on the same
frame boundary. This is fine for single-thread, but if any AI module is
ever moved off the main thread (GOAP pathfinding is a tempting candidate),
the producer side is a race.

### `SkeleRealmsGlobal.world_states` — global GOAP blackboard

`scripts/sk_global.gd`

A single `Dictionary` accessed by every `GOAPComponent._process()` tick.
Fast and fine as long as all of them run on the main thread. Any move of
GOAP planning to a worker thread would need to snapshot this dictionary
before handing it off, or accept stale reads.

### `QuestGraphEngine` — cached lookup tables

`scripts/quests/quest_graph_engine.gd` keeps `_node_maps` and
`_successor_maps` built at `register_quest()` time. `apply_event` mutates
the runtime state dictionaries concurrently is unsafe. Quest registration
is also not safe to do in parallel with `apply_event`.

### `NavMaster` — binary heap and closed list

`scripts/granular_navigation/navigation_master.gd`

`calculate_path()` uses static heap helpers over a local open list, so the
algorithm itself is reentrant, but the underlying `NavWorld` → `NavNode`
graph is shared. If a worker thread is pathfinding while another system
mutates the graph (`subdivide_edge`, `dissolve_point`, connection load),
the reader will see a corrupted graph.

### `ResourceLoader` — one cache, shared mutable resources

Several systems (`CovenSystem`, `ModLoader`, `QuestSystem`) hold `Coven`,
`QuestDefinition`, and `DialogueDefinition` resources loaded via
`ResourceLoader`. Godot caches these by path: two `load()` calls for the
same path return the same instance. `CovenSystem.change_opinion()` mutates
that instance. If multiple scripts assume they each own their copy, they
are wrong.

---

## Safe-to-thread operations

These are genuinely side-effect-free and safe to call from worker threads:

- `QuestGraphEngine.validate_graph(quest_id)` after registration completes.
- Reading `SKEntity.position` / `rotation` / `world` (copies; pure data).
- Pure math helpers in `scripts/granular_navigation/navigation_master.gd`
  (`_heap_push`, `_heap_pop`).
- `SaveSystem._compute_checksum(text)` on an already-captured string.
- `SaveSystem._serialize(data)` *if* `data` is a copy that no other
  thread is mutating.

If you need background work, do it on an immutable snapshot.

---

## Recommendations

Short term (inside 1.0):

1. ~~Add a `_saving: bool` guard on `SaveSystem.save()` and return early on
   re-entry.~~ ✅ Done — guard added; write path converted to tmp-file + rename.
2. Document the main-thread rule in the public API doc
   (`docs/architecture/api_stability.md`).
3. Use `call_deferred` for cross-frame state mutations in the few places
   we already do parallel work (resource preload, scene streaming).

Longer term (post-1.0):

1. Introduce a `SessionContext` that owns `entities`, `crimes`, quest
   runtime state, and friends, so the autoloads become thin facades.
2. Make `SessionContext` locking explicit — a single read-write lock per
   session is enough for the scale this framework targets.
3. Move GOAP planning and granular pathfinding to `WorkerThreadPool` with
   snapshot inputs and deferred-result callbacks.

None of the longer-term items are required for 1.0. They are the natural
follow-ups if the framework grows into bigger worlds or a server build.
