# Quest System

Skelerealms includes a graph-based quest system that supports branching objectives, prerequisites, and save integration. It was ported from the [Camelot](https://github.com/awest813/Camelot) TypeScript framework.

## Overview

Quests are modelled as **directed acyclic graphs (DAGs)** of objective nodes. Each node represents one step, and a quest completes when all of its designated completion nodes are done. Nodes can have prerequisites so they only become active after earlier steps finish, which allows branching and sequential paths within a single quest.

The system has three layers:

| Class | Role |
|---|---|
| `QuestDefinition` | A resource that declares the quest graph (nodes, start nodes, completion nodes, XP). |
| `QuestGraphEngine` | The pure-logic engine. Tracks runtime state, advances the graph, validates structure. |
| `QuestSystem` | The autoload singleton. Wraps the engine, emits signals, and integrates with the save system. |

## Defining a Quest

Create a `QuestDefinition` resource (`.tres`) and fill in its properties:

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique identifier, e.g. `&"find_the_sword"`. |
| `quest_name` | `String` | Display name (can be a translation key). |
| `description` | `String` | Optional flavour text. |
| `nodes` | `Array[QuestNodeDefinition]` | The objective nodes that make up the quest. |
| `start_node_ids` | `Array[StringName]` | Which nodes activate when the quest starts. If left empty, nodes with no prerequisites are used automatically. |
| `completion_node_ids` | `Array[StringName]` | Which nodes must all be completed to finish the quest. If left empty, every node must be completed. |
| `xp_reward` | `int` | XP granted to the player when the quest completes. |

### Quest Nodes

Each node is a `QuestNodeDefinition` resource:

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique within the quest, e.g. `&"talk_to_blacksmith"`. |
| `description` | `String` | Human-readable objective text. |
| `trigger_type` | `String` | `"kill"`, `"pickup"`, `"talk"`, or `"custom"`. |
| `target_id` | `StringName` | The entity/item ref-ID the trigger applies to. |
| `required_count` | `int` | How many trigger events are needed (default `1`). |
| `prerequisites` | `Array[StringName]` | Node IDs that must be completed before this node activates. |
| `next_node_ids` | `Array[StringName]` | Explicit successor nodes. If empty, the engine uses implicit prerequisite links. |

### Example: A Two-Step Quest

```
[Node A] Talk to the blacksmith
    └──► [Node B] Bring 3 iron ingots
                └──► Quest complete
```

In `QuestDefinition`:
- `start_node_ids = []` (Node A has no prerequisites, so it starts automatically)
- `completion_node_ids = [&"bring_iron"]`

Node A (`QuestNodeDefinition`):
- `id = &"talk_to_smith"`, `trigger_type = "talk"`, `target_id = &"blacksmith"`, `required_count = 1`
- `next_node_ids = [&"bring_iron"]`

Node B (`QuestNodeDefinition`):
- `id = &"bring_iron"`, `trigger_type = "pickup"`, `target_id = &"iron_ingot"`, `required_count = 3`
- `prerequisites = [&"talk_to_smith"]`

## Registering Quests

Call `QuestSystem.register_quest(definition)` before activating. You can load definitions from resources and register them at startup:

```gdscript
func _ready() -> void:
    var quest: QuestDefinition = preload("res://quests/find_the_sword.tres")
    QuestSystem.register_quest(quest)
```

For mods, use a `ModManifest` — the `ModLoader` will register quests automatically. See [mods.md](mods.md).

## Activating and Advancing Quests

```gdscript
# Start a quest (connect to a dialogue effect or trigger)
QuestSystem.activate_quest(&"find_the_sword")

# Report that the player picked up an item
QuestSystem.report_pickup(&"iron_ingot", 1)

# Report a kill
QuestSystem.report_kill(&"goblin_chief")

# Report that the player talked to an NPC
QuestSystem.report_talk(&"blacksmith")

# Fire a custom event (for any custom trigger_type)
QuestSystem.report_custom(&"lever_pulled")
```

## Checking Quest Status

```gdscript
var status := QuestSystem.get_quest_status(&"find_the_sword")
# Returns "inactive", "active", or "completed"

var state := QuestSystem.get_quest_state(&"find_the_sword")
# Returns a QuestGraphEngine.QuestRuntimeState snapshot
```

## Signals

Connect to `QuestSystem` signals to update your UI:

| Signal | When |
|---|---|
| `quest_activated(quest_id)` | A quest was activated. |
| `quest_updated(quest_id, activated_nodes, completed_nodes)` | One or more objective nodes changed state. |
| `quest_completed(quest_id, xp_reward)` | All completion nodes were finished. |

```gdscript
func _ready() -> void:
    QuestSystem.quest_completed.connect(_on_quest_completed)

func _on_quest_completed(quest_id: StringName, xp: int) -> void:
    print("Quest '%s' done! Earned %d XP" % [quest_id, xp])
```

## Validating a Quest Graph

The engine can check your quest definition for authoring errors before shipping:

```gdscript
var report := QuestSystem.validate_quest(&"find_the_sword")
if not report.valid:
    for issue in report.issues:
        print("[%s] node '%s': %s" % [issue.type, issue.node_id, issue.detail])
```

Issue types: `"unreachable"` (node cannot be reached from start), `"dead_end"` (non-completion node has no successors), `"cycle"` (dependency loop), `"not_found"` (quest not registered).

## Save Integration

`QuestSystem` automatically registers with the `savegame_gameinfo` group. No extra wiring is needed — quest state is saved and loaded alongside all other game-info data.
