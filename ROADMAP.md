# Roadmap

This roadmap is the high-level view of where Skelerealms is headed.

For the detailed status of specific systems, assumptions, and incomplete areas, see [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md). For the historical Camelot porting work that already landed, see [`CAMELOT_ROADMAP.md`](CAMELOT_ROADMAP.md).

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

## Current priorities

Phase 9 — Architecture Hardening initial pass complete. Documentation deliverables landed; multiplayer and thread-safety remain documentation-only surveys for now.

### Phase 9 — Architecture Hardening (0.8 → 0.9 target) — partial ✅

Prepare the framework for long-lived production use and broader adoption.

1. ✅ **Multiplayer-readiness audit** — session-unsafe state, singleton assumptions, and player-identity coupling catalogued in `docs/architecture/multiplayer_audit.md`. No code changes yet; documented as a survey so any future co-op fork has a starting map.
2. ✅ **Thread-safety review** — autoload and shared-state hazards documented in `docs/architecture/thread_safety.md`. Ground rule codified: Skelerealms remains a single-threaded main-thread framework; worker-thread work requires immutable snapshots.
3. ✅ **API stability pass** — Stable / Beta / Internal tiers defined in `docs/architecture/api_stability.md`. Post-1.0 deprecation policy spelled out.
4. ✅ **Plugin packaging** — plugin version bumped to `beta 0.8`. Plugin.cfg metadata retained; AssetLib polish (minimal example project, versioned release artifacts) remains for 0.9.
5. ✅ **Migration tooling** — `PluginMigrationRegistry` (`scripts/system/plugin_migration_registry.gd`) runs one-shot project-level migrations on editor start. Save-file migrations continue to live in `SaveSystem`. Contract documented in `docs/architecture/migration_tooling.md`. Unit tests in `tests/test_plugin_migration_registry.gd`.

| File | Purpose |
|---|---|
| `docs/architecture/multiplayer_audit.md` | Survey of session-scoped state, player-singleton assumptions, RPC gaps |
| `docs/architecture/thread_safety.md` | Main-thread rule, per-autoload hazards, safe-to-thread operations |
| `docs/architecture/api_stability.md` | Stable / Beta / Internal tier classification and deprecation policy |
| `docs/architecture/migration_tooling.md` | Save-file vs plugin-level migration split and contract |
| `scripts/system/plugin_migration_registry.gd` | Plugin-version migration runner (project-level state) |
| `tests/test_plugin_migration_registry.gd` | GUT tests for the registry's run loop |

Remaining Phase 9 work (pushed into 0.9):

- AssetLib-ready minimal example project.
- `@rpc` annotation pass for the subset of APIs that could serve a server-authoritative build.
- Introduce a `_saving` guard on `SaveSystem.save()` and convert to tmp-file + rename for crash safety.

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

- **Phase 9 — Architecture Hardening (initial pass)**: four architecture docs (`multiplayer_audit.md`, `thread_safety.md`, `api_stability.md`, `migration_tooling.md`), plus the `PluginMigrationRegistry` class and tests for it. Plugin version bumped to `beta 0.8`.
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
