# Skelerelams 

Welcome to Skelerealms, the framework for Bethesda-style Open World RPGs (Like Skyrim, Fallout New Vegas, etc.).  
This addon aims to offer a solution to the most challenging technical challenges faced while engineering games like this. Gameplay is, however, not included.  
For those familiar with Creation Engine's inner workings, Skelerealms seeks to primarily cover Actors, Cells, AI Packages, and Factions.  
Skelerealms is designed in such a way where you can ignore or replace most of the working components, and allow easy integration into your own gameplay systems.

## What does it have?

- Inter-scene persistence of important objects
- Inter-scene navigation
- A basic framework for skills and attributes
- Loot tables
- Inventory system
- Equipment system
- NPC AI
	- Behaviours
	- GOAP AI System
	- Basic perception
	- Schedules
	- Patrol paths
	- Investigate state
	- Crime response & guard challenge
- Tools to assist development
- Composable design
	- Components for entities
	- Components for items
- Dungeon puzzle elements
- Factions
	- Configurable disposition thresholds
- Spells/Status Effects
- Crime
- Bartering
- Spawn zones
- Doors
- Quest system (DAG-based with validation, triggers, and save integration)
- Dialogue system (branching trees with conditions, effects, and session management)
- Save system (named slots, schema versioning, migration hooks, integrity checks)

## What does it *not* have? 

- Gameplay
- Terrain
- LOD system, chunks
- UI
- Combat

## How do I get started? 


Visit the [documentation](docs/user%20guide/quick_start.md) for a quick start guide.


## What's the project status?

The project is active. I am using this to develop my own game, and will occasionally push changes I make upstream.  
Please note that the project is in an Alpha state, which means breaking changes can and will happen often. Plan around this. I plan to have feature and API stability once 1.0 is reached.

## What's in store?

- 0.6 (Current)
	- ~~Redesigning the way entities are stored.~~ ✅
	- ~~Adding more tools.~~ ✅
	- ~~Writing more thorough documentation.~~ ✅
	- ~~Integrating NetworkGD.~~ ✅
	- ~~Quest system (DAG-based, ported from Camelot).~~ ✅
	- ~~Dialogue system (branching trees with conditions/effects, ported from Camelot).~~ ✅
	- ~~GOAP BFS fix for cost-optimal action plans.~~ ✅
	- ~~Save system overhaul: named slots, schema versioning, FNV-1a checksums.~~ ✅
	- ~~Faction disposition thresholds.~~ ✅
	- ~~AI investigate state and crime response.~~ ✅
- 0.7
	- Polish cross-scene navigation.
	- Fix GOAP objective assignment tracking.
	- Implement granular navigation connection persistence.
	- Generalize VitalsComponent for NPCs.
	- Complete perception FOV (vertical + AABB coverage).
	- Fix item drop direction.
	- Fix barter shop_will_accept_item.
- 0.8
	- Spawn tracker persistence.
	- World loader abort handling.
	- NPC door interaction.
	- Barter filtering & haggling.
	- Item worth & ownership.
- 1.0
	- Feature & API stability.
	- Furniture animation & multi-use.
	- Player damage generalization.
	- Network edge costs in editor.
	- Granular navigation memory optimization.
	- Mod-friendly data architecture.


## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=SlashScreen/skelerealms&type=Timeline&theme=dark)](https://star-history.com/#SlashScreen/skelerealms&Timeline)
