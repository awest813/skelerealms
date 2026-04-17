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

Phase 9 — Architecture Hardening is in progress.

### Phase 9 — Architecture Hardening (0.9 target)

Prepare the framework for long-lived production use and broader adoption.

1. **Multiplayer-readiness audit** — identify and document session-unsafe state, singleton assumptions, and client/server boundaries; add `@rpc` annotations or abstractions where viable.
2. **Thread-safety review** — audit autoloads and shared state for potential races when used with Godot's threading APIs.
3. **API stability pass** — lock down public-facing method signatures, signals, and resource schemas; deprecate and remove internal-only surface area.
4. **Plugin packaging** — prepare for Godot AssetLib distribution with proper `plugin.cfg` metadata, versioned releases, and a minimal example project.
5. **Migration tooling** — automated upgrade scripts for breaking changes between minor versions leading up to 1.0.

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
