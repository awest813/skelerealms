# Skelerealms

![Skelerealms logo](skelerealms_logo.png)

Skelerealms is an extensible open-world RPG framework for Godot 4.4+, built for projects that need Creation Engine-style world simulation without inheriting Creation Engine-style limitations.

It focuses on the hard framework problems behind Bethesda-inspired games: persistent worlds, cross-scene navigation, NPC simulation, inventories, factions, saves, quests, dialogue, combat, UI, and reusable entity systems. It does **not** ship your game's story, content, or gameplay loop.

## Why Skelerealms?

- **Persistent worlds** so important objects and actors survive scene transitions.
- **Cross-scene navigation** so NPCs can reason beyond the currently loaded scene.
- **Composable entity architecture** built around reusable components and modules.
- **Simulation-first NPC framework** with GOAP, schedules, perception, factions, and crime response.
- **Framework-level RPG systems** like inventory, equipment, loot, vitals, dialogue, quests, and saves.
- **Authoring tools** for working with entities, schedules, navigation data, and doors inside Godot.

## Included systems

### World simulation

- Inter-scene persistence for important objects and entities
- Inter-scene navigation and granular world traversal
- Spawn zones and spawn-state persistence
- Doors and world-to-world transitions
- Save/load with named slots, schema versioning, migration hooks, and integrity checks

### Characters, AI, and progression

- NPC AI with GOAP, schedules, patrols, perception, and investigation behavior
- Behaviour tree system complementing GOAP for detailed action execution
- Shared AI blackboard (`SKBlackboard`) for runtime state
- Factions/covens with configurable disposition thresholds
- Crime tracking and guard challenge response
- Skills, attributes, vitals, inventory, equipment, loot tables, and status effects
- Bartering and shop item filtering

### Combat

- `DamagePacket` extending `DamageInfo` with crits, hit reactions, damage categories, and tags
- `CombatantComponent` unifying poise, resistances, block/parry/i-frames for player and NPC entities
- `CombatAction` resource defining attacks, abilities, and spells with timing, cost, and combos
- `CombatStateMachine` with Idle → Attack → Cast → Stagger → Knockdown → Death flow
- `SKHitbox`/`SKHurtbox` Area3D wrappers with deduplication and locational damage
- `HitPipeline` stateless resolver for melee and hitscan hits
- AI combat action module for NPC action selection

### UI framework

- `SKUIManager` autoload managing layer stack, menu stack, and input mode routing
- `SKTheme` resource with RPG color palette, font slots, and animation timing
- HUD shell with widget slots for vitals, compass, crosshair, prompts, and status effects
- Menu shell with tab/page and popup management
- Menu contracts: inventory, dialogue, barter, journal, pause, character
- Widget contracts: list item, stat row, tab panel, tooltip, radial selector, prompt bar

### Narrative and interaction

- Quest system with DAG validation, triggers, and save integration
- Dialogue system with branching trees, conditions, effects, and session management
- Dungeon puzzle support through device/network systems

### Tooling and composition

- Component-driven entity design
- Item and entity composition helpers
- World-entity and door authoring workflows
- Schedule and NPC tooling

### First-person player

- `FPSPlayerPuppet` — first-person `CharacterBody3D` puppet with sprint, crouch, jump, headbob, and interaction raycasting
- Wires automatically to `VitalsComponent` (stamina drain on sprint), `DamageableComponent`, and `InventoryComponent` via the player entity
- Interaction raycast detects both `InteractiveObject` world objects and `InteractiveComponent` entities; shows prompts through `SKHUDShell`
- `player_entity_template.tscn` — ready-made entity template with all required components

### Interactive world objects

- `SwingDoorObject` — tween-based rotating or sliding door with lock/key support and auto-close
- `AnimatedInteractiveObject` — base class for `AnimationPlayer`-driven objects (drawers, hatches, etc.)
- `ButtonObject` — pressable button with cooldown, single-use mode, and chaining to other objects
- `KeypadObject` — code-entry logic with auto-submit, attempt limiting, and masked display

### Surface-aware footstep audio

- `SKFootstepPlayer` — fires a downward raycast, matches the floor's physics-body group to a named `AudioStreamPlayer3D` child, and plays the corresponding sound; falls back to a `"default"` child

### Chunk loading

- Generic, engine-agnostic chunk manager (`SKChunkManager`) with configurable active/preload radii
- Async loading with worker-pool concurrency limiting and cooperative cancellation
- LRU cache eviction for memory management
- Abstract `SKChunkSource`/`SKChunkAdapter` interfaces for game-specific implementations
- Full lifecycle observability via `chunk_event` signal

## What Skelerealms does not include

Skelerealms is a framework layer, not a complete game template.

- No terrain/LOD pipeline (a generic chunk-loading system is provided — see `scripts/chunks/`)
- No ready-made story, quests, encounters, or game-specific gameplay loop

## Requirements

- **Godot 4.4+**
- A project structure that follows the framework's expected folders and naming conventions

For the current singleton list, required folders, project settings, assumptions, and roadmap status, see [`ROADMAP.md`](ROADMAP.md).

## Getting started

### New project

Start from the template project referenced in the quick start guide:

- [`docs/user guide/quick_start.md`](docs/user%20guide/quick_start.md)

### Existing project

Add Skelerealms to your project, enable the plugin, and follow the folder/setup guidance in the docs.

Recommended reading order:

1. [`docs/intro.md`](docs/intro.md)
2. [`docs/user guide/quick_start.md`](docs/user%20guide/quick_start.md)
3. [`docs/user guide/components.md`](docs/user%20guide/components.md)
4. [`docs/user guide/entities.md`](docs/user%20guide/entities.md)
5. [`docs/user guide/npcs.md`](docs/user%20guide/npcs.md)
6. [`docs/user guide/navigation.md`](docs/user%20guide/navigation.md)
7. [`docs/user guide/tools.md`](docs/user%20guide/tools.md)

## Documentation map

### Core references

- [`ROADMAP.md`](ROADMAP.md) — canonical combined roadmap and framework status
- [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md) — legacy compatibility alias

### Concepts

- [`docs/concepts/worlds.md`](docs/concepts/worlds.md)
- [`docs/concepts/entities.md`](docs/concepts/entities.md)

### User guide

- [`docs/user guide/quick_start.md`](docs/user%20guide/quick_start.md)
- [`docs/user guide/components.md`](docs/user%20guide/components.md)
- [`docs/user guide/entities.md`](docs/user%20guide/entities.md)
- [`docs/user guide/npcs.md`](docs/user%20guide/npcs.md)
- [`docs/user guide/navigation.md`](docs/user%20guide/navigation.md)
- [`docs/user guide/goap_actions.md`](docs/user%20guide/goap_actions.md)
- [`docs/user guide/ai_modules.md`](docs/user%20guide/ai_modules.md)
- [`docs/user guide/schedules.md`](docs/user%20guide/schedules.md)
- [`docs/user guide/loot_tables.md`](docs/user%20guide/loot_tables.md)
- [`docs/user guide/covens.md`](docs/user%20guide/covens.md)
- [`docs/user guide/quests.md`](docs/user%20guide/quests.md)
- [`docs/user guide/dialogue.md`](docs/user%20guide/dialogue.md)
- [`docs/user guide/save_system.md`](docs/user%20guide/save_system.md)
- [`docs/user guide/mods.md`](docs/user%20guide/mods.md)
- [`docs/user guide/fps_controller.md`](docs/user%20guide/fps_controller.md)
- [`docs/user guide/interactive_objects.md`](docs/user%20guide/interactive_objects.md)
- [`docs/user guide/stealth_provider.md`](docs/user%20guide/stealth_provider.md)
- [`docs/user guide/tools.md`](docs/user%20guide/tools.md)
- [`docs/user guide/migrating.md`](docs/user%20guide/migrating.md)

## Project status

- **Current plugin version:** `1.0`
- **Minimum Godot version:** `4.4`
- **Status:** active development
- **Stability:** API and save-schema are now in the 1.0 stability window

For the API-stability commitments and the Stable / Beta / Internal tier split that will take effect at 1.0, see [`docs/architecture/api_stability.md`](docs/architecture/api_stability.md).

Skelerealms is being actively developed in support of a real game project, with framework improvements flowing back upstream as systems are hardened.

## Godot 4.4 features

This release takes advantage of several Godot 4.4 improvements:

- **Typed Dictionaries** — core data structures now use `Dictionary[KeyType, ValueType]` for stronger type safety and better Inspector integration.
- **3D Physics Interpolation** — Godot 4.4 adds opt-in 3D physics interpolation (`physics/3d/physics_interpolation`). Enable it in your project settings for smoother NPC movement when puppets update position in `_physics_process`.
- **Jolt Physics support** — Godot 4.4 bundles the Jolt physics engine as an optional backend. Skelerealms' raycasting (editor point placement, NPC perception) and Area3D hitbox/hurtbox detection have been audited and are compatible with both Godot Physics and Jolt.
- **FileAccess return values** — `store_string()` and `flush()` now return error codes; the save system checks these for write failures.

## Migration from Godot 4.2/4.3

If you are upgrading an existing project:

1. Update Godot to **4.4** or later.
2. Update the Skelerealms plugin to `1.0`. The plugin migration system will handle any project-level changes automatically.
3. Review the [official Godot 4.4 migration guide](https://docs.godotengine.org/en/stable/tutorials/migrating/) for any breaking changes in your own project code.
4. Note that `@export_file` annotations in Godot 4.4 now store `uid://` paths instead of `res://` paths. If you have custom resources using `@export_file`, re-save them after upgrading.

See [`docs/user guide/migrating.md`](docs/user%20guide/migrating.md) for full details.

## Roadmap and status

The combined roadmap and framework status now lives in [`ROADMAP.md`](ROADMAP.md).
Current priority: post-1.0 stabilization and additive improvements.

## Attribution

Skelerealms is a fork of the original [Skelerealms](https://github.com/SlashScreen/skelerealms) project by [SlashScreen](https://github.com/SlashScreen). The original project established the core open-world RPG framework architecture for Godot 4 — including persistent entities, inter-scene navigation, GOAP-based NPC AI, factions, inventory, equipment, and the component-driven entity model that this fork continues to build on.

This fork extends the original with new systems (quests, dialogue, saves overhaul, combat, UI framework, mod support), bug fixes, performance improvements, and expanded documentation.
