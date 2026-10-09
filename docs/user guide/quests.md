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

## Quest Aliases

Aliases are named reference slots filled with live entity ref-IDs when a quest
activates — the Creation-Kit-style way to target "the nearest thief" instead
of hardcoding `&"snitch_a"`. Nodes reference an alias with a `{AliasId}`
placeholder in `target_id`; the engine resolves it against the fills stored
in quest runtime state when matching events.

Each alias is a `QuestAlias` resource on `QuestDefinition.aliases`:

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Alias name, e.g. `&"Mark"` (referenced as `{Mark}`). |
| `optional` | `bool` | When true, the quest still activates if nothing matches. Unresolved placeholders simply match no events. |
| `must_be_npc` | `bool` | Only entities with an `NPCComponent` are candidates (default `true`). |
| `required_coven` | `StringName` | Only members of this coven match. Empty means any. |
| `required_form` | `StringName` | Only entities with this `form_id` match. Empty means any. |
| `exclude_ids` | `Array[StringName]` | Ref-IDs that must never fill this alias (e.g. the quest giver). |
| `nearest_to` | `StringName` | Nearest-pick anchor: `&"player"`, another (earlier) alias id, or empty for first-registry-match. |

Filling is deterministic: candidates arrive in entity-registry order and
nearest picks break ties by distance, so the same world state always fills
the same refs. Required aliases with no candidate block activation (the quest
stays inactive); explicit template params take precedence over generated
fills. Fills live in runtime state, so they survive save/load automatically.

```gdscript
# Journal text and map markers read fills like this:
var mark := QuestSystem.resolve_alias(&"the_snitch", &"Mark")
var all_fills := QuestSystem.get_alias_refs(&"the_snitch")
```

`QuestGraphEngine.validate_aliases(definition)` checks declarations without
registering anything: duplicate ids, anchors to unknown ids, and anchors to
aliases that fill later (anchors must target earlier aliases). See
`example/quests/alias_demo_quest.tres` for a complete worked quest.

## Quest Stages and the Journal

Nodes are a quest's mechanics; **stages** are its narrative. Each `QuestStage`
resource is one journaled beat: an index (`10`, `20`, `30` …), a log entry,
and a short objective line. A stage becomes current explicitly via
`QuestSystem.set_stage(id, index)` or automatically when every node in its
`trigger_nodes` completes (stages with empty triggers only fire as the
opening stage or explicitly). Each new current stage appends its log entry —
with `{AliasId}` placeholders resolved against quest fills — to the quest
journal. Stages can also end the quest: `completes_quest` pays XP as usual,
`fails_quest` closes it terminally with no XP (watch `quest_failed`).

| Property | Type | Description |
|---|---|---|
| `index` | `int` | Stage number, unique within the quest. |
| `log_entry` | `String` | Journal line written on arrival. Supports `{AliasId}`. |
| `objective` | `String` | Short objective shown while current. |
| `trigger_nodes` | `Array[StringName]` | Joint completion auto-advances here. Empty = explicit-only. |
| `completes_quest` | `bool` | Reaching this stage completes the quest. |
| `fails_quest` | `bool` | Reaching this stage fails the quest. |

```gdscript
QuestSystem.set_stage(&"the_snitch", 20)
# Returns "advanced", "completed", "failed", or "" when nothing happened.

var journal := QuestSystem.get_journal(&"the_snitch")
# {name, status, current_stage, objectives: [{text, done, stage}], log: [{stage, text}]}

var line := QuestSystem.get_current_objective(&"the_snitch")
# One-line objective for HUD use.
```

Quests without stages keep working exactly as before: their journal falls
back to raw node progress. Stage fills persist in save snapshots alongside
everything else. Validate declarations (duplicate indices, triggers naming
unknown nodes) with `QuestGraphEngine.validate_stages(definition)`.

## Repeatable Quests

For bounty boards, rumor-driven errands, and other repeatable content, don't
hand-place quest instances — declare a template and let the [Radiant Story
Manager](radiant.md) issue them from game events.

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
