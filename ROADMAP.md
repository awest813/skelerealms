# Roadmap

This roadmap is the high-level view of where Skelerealms is headed.

For the detailed status of specific systems, assumptions, and incomplete areas, see [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md). For the historical Camelot porting work that already landed, see [`CAMELOT_ROADMAP.md`](CAMELOT_ROADMAP.md).

## Current state

- **Version target:** `beta 0.7`
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

## Current priorities

These are the most important remaining framework gaps.

1. ~~**Performance profiling**~~
   - ~~Profile and optimize hot paths in large-world scenarios.~~ ✅

## Next phases

### Phase 7 — Editor Tooling (0.7 target)

Better authoring workflows to reduce friction for content creators.

1. **Visual quest editor** — graph-based node editor for quest definitions inside the Godot editor, with drag-and-drop node creation, prerequisite wiring, and live validation feedback.
2. **Dialogue tree editor** — visual branching editor for dialogue definitions, with inline condition/effect previews, session simulation (dry-run a conversation), and export to `.tres`.
3. **Schedule editor** — timeline-based UI for defining NPC daily schedules, with drag-to-resize time blocks and per-world location assignment.
4. **Coven relationship matrix** — grid view of inter-coven opinions with inline editing and disposition-threshold visualization.

### Phase 8 — Runtime Debugging & Diagnostics (0.8 target)

In-game overlays and tools to accelerate iteration and troubleshooting.

1. **AI state overlay** — real-time visualization of NPC GOAP state, current objective, active action, and awareness level.
2. **Navigation debug draw** — render granular navigation graphs, active NPC paths, and portal connections in the editor and at runtime.
3. **Perception debug draw** — visualize FOV cones, line-of-sight raycasts, and detection events.
4. **Quest state inspector** — runtime panel showing active quests, node states, and event history for debugging quest progression.
5. **Save file inspector** — editor tool to browse and validate save file contents without loading the game.

### Phase 9 — Architecture Hardening (0.9 target)

Prepare the framework for long-lived production use and broader adoption.

1. **Multiplayer-readiness audit** — identify and document session-unsafe state, singleton assumptions, and client/server boundaries; add `@rpc` annotations or abstractions where viable.
2. **Thread-safety review** — audit autoloads and shared state for potential races when used with Godot's threading APIs.
3. **API stability pass** — lock down public-facing method signatures, signals, and resource schemas; deprecate and remove internal-only surface area.
4. **Plugin packaging** — prepare for Godot AssetLib distribution with proper `plugin.cfg` metadata, versioned releases, and a minimal example project.
5. **Migration tooling** — automated upgrade scripts for breaking changes between minor versions leading up to 1.0.

## Recently completed work

These pieces landed in the latest milestone:

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
