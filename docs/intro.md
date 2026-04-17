# The Skelerealms Grimoire
#### For Skelerealms Beta 0.7

## Introduction

Welcome! There are the high-level docs for Skelerealms, showing you how to use this addon. If you want methods and variables documentation, documentation comments are provided in-engine, like any other class.

### What is Skelerealms?

Skelerealms is an addon for Godot 4.2+ that aims to provide the foundation for creating a Bethesda-style Open World RPG (The Elder Scrolls, Fallout, Starfield). No gameplay is provided, but a lot of the challenging systems are in place to allow you to focus on telling your story.  

Skelerealms is inpsired by Creation Engine, but aims to tackle many of its shortcomings with the benefit of 20+ years of hindsight. It's also been designed not to lock you in to any specific way of designing your game - most components are purely optional. You don't even need to have a player to run the game (but I'm not sure what the point of that would be...) 

### What problems does it solve?

- Cross-scene persistence: If the player drops a book in one room, goes outside, and then comes back inside, that book should still be lying on the floor. This problem is much trickier to solve than it seems; but you don't need to worry about it. Skelerealms has got you covered!
- Cross-scene navigation: If you're running away from an enemy and duck into a building, it only makes sense that the enemy should follow you through the door. This, again, is a tricky problem to solve. Again, though, Skelerealms has solved this problem already, by introducing a supplementary navigation system that exists, no matter what scene is loaded.
- NPC AI: Skelerealms comes with a robust AI system that hopes to smooth out some of the awkwardness of Bethesda's infamous NPCs by using a GOAP (Goal-Orientated Action Planning) system that's also integrated (but not coupled to) a built-in faction and schedule system.
- And much more!

### Main Features

- Cross-scene persistence
- Inter-scene navigation
- GOAP
- Inventory
- Status effects and spells
- Loot tables
- Equipment
- Composable item behaviors
- Bartering system
- Factions
- Schedules
- Sight/stealth mechanics

## Table of Contents

### Concepts

- [Entities and Components](concepts/entities.md)
- [Worlds](concepts/worlds.md)

### User guide

- [Quick Start](user%20guide/quick_start.md)
- [Components](user%20guide/components.md)
- [Entities](user%20guide/entities.md)
- [Worlds](user%20guide/worlds.md) *(see Concepts section)*
- [NPCs](user%20guide/npcs.md)
- [AI Modules](user%20guide/ai_modules.md)
- [GOAP Actions](user%20guide/goap_actions.md)
- [Schedules](user%20guide/schedules.md)
- [Navigation](user%20guide/navigation.md)
- [Covens (Factions)](user%20guide/covens.md)
- [Quests](user%20guide/quests.md)
- [Dialogue](user%20guide/dialogue.md)
- [Save System](user%20guide/save_system.md)
- [Mods](user%20guide/mods.md)
- [Loot Tables](user%20guide/loot_tables.md)
- [Tools](user%20guide/tools.md)
- [Stealth Provider](user%20guide/stealth_provider.md)
- [Migrating from 0.5 to 0.6](user%20guide/migrating.md)


## Project Status

### Development

Despite what it may look like on the main repo's commit history, development is ongoing (in the submodule repository.) Skelerelams was originally developed for a game I am making myself, and so I am dog-fooding Skelerealms during the development of this game. As I encounter problems during the development process, I make changes and fixes, and push them upstream.

### Places to improve

- Lots of more processing-heavy parts of code should probably be written in a compiled language.
