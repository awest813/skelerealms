# Roadmap

This roadmap is the high-level view of where Skelerealms is headed.

For the detailed status of specific systems, assumptions, and incomplete areas, see [`FRAMEWORK_STATUS.md`](FRAMEWORK_STATUS.md). For the historical Camelot porting work that already landed, see [`CAMELOT_ROADMAP.md`](CAMELOT_ROADMAP.md).

## Current state

- **Version target:** `beta 0.6`
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

## Current priorities

These are the most important remaining framework gaps.

1. **Barter haggling**
   - Add negotiation depth to the existing barter framework.
2. **Item worth and ownership**
   - Finish theft logic, ownership checks, and related item-handling rules.
3. **Furniture animation and multi-use**
   - Support richer NPC use points and multiple simultaneous users where appropriate.
4. **Player damage generalization**
   - Expand the player damage pipeline beyond the currently limited handling.

## Next-tier improvements

After the core gaps above, the next focus is editor polish, performance, and extensibility.

1. **Network edge costs in the editor**
   - Finish authoring support for navigation edge weighting.
2. **Granular navigation memory optimization**
   - Reduce memory overhead in the navigation runtime.
3. **Audio emitter refactor**
   - Replace the current physics-based sound propagation approach.
4. **Mod-friendly data architecture**
   - Make data-driven extension and override workflows easier for downstream projects.

## Path to 1.0

Skelerealms should reach 1.0 only after:

- The major incomplete systems are finished
- Core authoring workflows are reliable
- Key framework APIs settle down
- The addon is comfortable to integrate into a long-running production project

Until then, expect iteration and breaking changes where the framework still needs structural improvement.
