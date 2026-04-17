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
- Barter haggling with skill-factor negotiation
- Item worth, ownership, and coven-aware theft detection
- Furniture animation hooks and multi-user sub-point support
- Player damage generalization across all damage types with buff/debuff modifiers
- Network edge cost computation on dissolve, merge, and subdivide
- Granular navigation memory optimization (RefCounted KD-tree nodes)
- Audio emitter refactor to non-physics distance checks

## Current priorities

These are the most important remaining framework gaps.

1. **Mod-friendly data architecture**
   - Make data-driven extension and override workflows easier for downstream projects.
2. **Crime — non-player tracking completeness**
   - Finish any remaining edge cases in crime tracking for non-player entities.

## Next-tier improvements

After the core gaps above, the next focus is documentation, testing, and extensibility.

1. **Documentation & tutorials**
   - Expand wiki and in-code documentation for downstream consumers.
2. **Integration test coverage**
   - Add automated tests for critical systems (save/load, quests, dialogue, barter).
3. **Performance profiling**
   - Profile and optimize hot paths in large-world scenarios.

## Path to 1.0

Skelerealms should reach 1.0 only after:

- The major incomplete systems are finished
- Core authoring workflows are reliable
- Key framework APIs settle down
- The addon is comfortable to integrate into a long-running production project

Until then, expect iteration and breaking changes where the framework still needs structural improvement.
