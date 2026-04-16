# Skelerealms

![Skelerealms logo](skelerealms_logo.png)

Skelerealms is an extensible open-world RPG framework for Godot 4, built for projects that need Creation Engine-style world simulation without inheriting Creation Engine-style limitations.

It focuses on the hard framework problems behind Bethesda-inspired games: persistent worlds, cross-scene navigation, NPC simulation, inventories, factions, saves, quests, dialogue, and reusable entity systems. It does **not** ship your game's combat, UI, story, or content.

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
- Factions/covens with configurable disposition thresholds
- Crime tracking and guard challenge response
- Skills, attributes, vitals, inventory, equipment, loot tables, and status effects
- Bartering and shop item filtering

### Narrative and interaction

- Quest system with DAG validation, triggers, and save integration
- Dialogue system with branching trees, conditions, effects, and session management
- Dungeon puzzle support through device/network systems

### Tooling and composition

- Component-driven entity design
- Item and entity composition helpers
- World-entity and door authoring workflows
- Schedule and NPC tooling

## What Skelerealms does not include

Skelerealms is a framework layer, not a complete game template.

- No built-in combat design
- No UI framework
- No terrain/LOD/chunk pipeline
- No ready-made story, quests, encounters, or game-specific gameplay loop

## Requirements

- **Godot 4.2+**
- A project structure that follows the framework's expected folders and naming conventions

For the current singleton list, required folders, project settings, and framework assumptions, see [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md).

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

- [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md) — current framework capabilities, assumptions, incomplete systems, and dependency-ordered priorities
- [`ROADMAP.md`](ROADMAP.md) — high-level roadmap and current focus areas
- [`CAMELOT_ROADMAP.md`](CAMELOT_ROADMAP.md) — historical Camelot-port roadmap and shipped integration work

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
- [`docs/user guide/stealth_provider.md`](docs/user%20guide/stealth_provider.md)
- [`docs/user guide/tools.md`](docs/user%20guide/tools.md)
- [`docs/user guide/migrating.md`](docs/user%20guide/migrating.md)

## Project status

- **Current plugin version:** `beta 0.6`
- **Status:** active development
- **Stability:** expect breaking changes before 1.0

Skelerealms is being actively developed in support of a real game project, with framework improvements flowing back upstream as systems are hardened.

## Roadmap snapshot

Near-term work is focused on finishing the remaining framework gaps rather than adding surface-level features:

- Barter haggling
- Item worth and ownership rules
- Furniture animation and multi-use support
- Player damage generalization
- Network edge cost editing
- Granular navigation memory optimization
- Mod-friendly data architecture

See [`ROADMAP.md`](ROADMAP.md) for the fuller roadmap.

## Star history

[![Star History Chart](https://api.star-history.com/svg?repos=awest813/skelerealms&type=Timeline&theme=dark)](https://star-history.com/#awest813/skelerealms&Timeline)
