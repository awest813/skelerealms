# Dialogue System

Skelerealms includes a branching dialogue system that supports typed conditions, effects, and save integration. It was ported from [Camelot](https://github.com/awest813/Camelot).

## Overview

Dialogue trees are defined as graphs of `DialogueNode` resources. Each node can present text from a speaker and offer a list of `DialogueChoice` options. Choices can have conditions that gate availability and effects that mutate game state when selected.

The system has three layers:

| Class | Role |
|---|---|
| `DialogueDefinition` | A resource that declares the full tree (nodes, start node). |
| `DialogueEngine` | Pure-logic engine — registers definitions, creates sessions. |
| `DialogueSystem` | The autoload singleton — wraps the engine, integrates with save. |

Runtime dialogue is driven through a `DialogueSession` object created per conversation.

## Defining a Dialogue

Create a `DialogueDefinition` resource (`.tres`):

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique identifier, e.g. `&"blacksmith_greeting"`. |
| `start_node_id` | `StringName` | The node shown first when the conversation starts. |
| `nodes` | `Array[DialogueNode]` | All nodes in the tree. |

### Dialogue Nodes (`DialogueNode`)

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique within the dialogue. |
| `speaker` | `String` | Who is speaking (display name or translation key). |
| `text` | `String` | The dialogue line. |
| `terminal` | `bool` | If `true`, all choices end the conversation. |
| `choices` | `Array[DialogueChoice]` | The player's response options. |

### Choices (`DialogueChoice`)

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique within the node. |
| `text` | `String` | The option text shown to the player. |
| `next_node_id` | `StringName` | Node to advance to when chosen. Empty = end dialogue. |
| `ends_dialogue` | `bool` | If `true`, the dialogue ends regardless of `next_node_id`. |
| `conditions` | `Array[DialogueChoiceCondition]` | All must pass for this choice to be available. |
| `effects` | `Array[DialogueChoiceEffect]` | Applied when this choice is selected. |
| `attempt_skill` | `StringName` | Persuasion skill rolled on selection (empty = no attempt). |
| `attempt_difficulty` | `int` | Subtracted from the roll chance. |
| `fail_next_node_id` | `StringName` | Branch on failed attempts. Empty = stay (fizzle). |
| `fail_effects` | `Array[DialogueChoiceEffect]` | Applied only when the attempt fails. |

### Conditions (`DialogueChoiceCondition`)

All conditions on a choice must pass for it to appear as available (it still shows, but `is_available` will be `false` so your UI can grey it out).

| `type` | Required fields | Description |
|---|---|---|
| `"flag"` | `flag`, `flag_equals` | A continuity flag must equal a boolean value. |
| `"faction_min"` | `faction_id`, `min_value` | Player's reputation with a coven must be ≥ `min_value`. |
| `"quest_status"` | `quest_id`, `quest_status` | A quest must have a specific status (`"inactive"`, `"active"`, `"completed"`). |
| `"has_item"` | `item_id`, `min_quantity` | Player's inventory must contain ≥ `min_quantity` of the item. |
| `"skill_min"` | `skill_id`, `min_value` | A player skill must be ≥ `min_value`. |

### Effects (`DialogueChoiceEffect`)

Effects are applied when a choice is selected.

| `type` | Required fields | Description |
|---|---|---|
| `"set_flag"` | `flag`, `flag_value` | Set a continuity flag. |
| `"faction_delta"` | `faction_id`, `amount` | Adjust the player's coven reputation. |
| `"emit_event"` | `event_id` | Calls `DialogueContext.emit_event()` for custom handling. |
| `"activate_quest"` | `quest_id` | Activate a quest via `QuestSystem`. |
| `"consume_item"` | `item_id`, `quantity` | Remove items from the player's inventory. |
| `"give_item"` | `item_id`, `quantity` | Give items to the player. |

## Starting a Dialogue Session

Register the definition, create a context, then start a session:

```gdscript
# 1 – Register (do this at startup, or via a ModManifest)
var definition: DialogueDefinition = preload("res://dialogues/blacksmith.tres")
DialogueSystem.register_dialogue(definition)

# 2 – Create a context (subclass DialogueContext to override inventory/skill queries)
var ctx := DialogueContext.new()

# 3 – Create a session
var session := DialogueSystem.create_session(&"blacksmith_greeting", ctx)
```

## Driving the Conversation

```gdscript
# Get the current node
var node_view := session.get_current_node()
print(node_view.speaker, ": ", node_view.text)

# Show choices (your UI)
for choice in node_view.choices:
    if choice.is_available:
        show_choice(choice.id, choice.text)
    else:
        show_choice_greyed(choice.id, choice.text, choice.blocked_by)

# When the player selects a choice
var result := session.choose(&"ask_about_sword")
if result.is_complete:
    end_dialogue_ui()
else:
    display_node(result.current_node)
```

## Persuasion Attempts

A choice with `attempt_skill` set rolls a persuasion check on selection
instead of applying blindly. Chance is `50 + skill − difficulty +
disposition/5`, clamped to 5–95, where skill comes from
`DialogueContext.get_skill_level()` and disposition from
`DialogueContext.get_disposition()` (both overridable, defaulting to 0 and a
d100 respectively). Sessions carry their own `rng`, so seed it for
deterministic tests or replays.

- **Success** applies `effects` and follows `next_node_id` as usual.
- **Failure** applies `fail_effects` and follows `fail_next_node_id` — or
  fizzles in place (staying on the node, reporting `success = false`) when
  no fail branch is set.
- Results flag `attempted` / `attempt_succeeded`, and choice views advertise
  `attempt_skill` / `attempt_difficulty` so UI can tag `[Persuade]` options.
- Validation flags `dangling_fail_branch` (bad fail targets) and
  `check_without_fail` (a check on a non-terminal node with nowhere to go).

## Dialogue Scenes

A `DialogueScene` stages a coordinated multi-actor conversation on top of an
ordinary dialogue tree: each tree node may name which participant speaks
that line, so two NPCs (and the player) can hold a scripted exchange with
choices, conditions, effects, and persuasion all working unchanged.

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique scene id. |
| `dialogue_id` | `StringName` | The backing tree this scene performs. |
| `participants` | `Array[StringName]` | Every actor involved (`"player"` allowed). |
| `required_participants` | `Array[StringName]` | Who must be present to start. Empty = all participants. |
| `cast` | `Dictionary` | Node id → speaking actor ref. Unlisted nodes keep their authored speaker. |
| `greet_radius` | `float` | Proximity trigger in metres. `0` disables auto-greet. |

```gdscript
DialogueSystem.register_dialogue(tree)
DialogueSystem.register_scene(scene)

# Manual start, or proximity-greet:
var view := DialogueSystem.try_greet(&"market_argument", player_pos, guard_pos)
var blocked := DialogueSystem.get_blocked_actors() # hold their AI packages
DialogueSystem.choose(&"intervene")
DialogueSystem.stop_scene() # aborts performance and conversation
```

While running, the scene's session **is** the active session, so `choose()`,
save/load, and signals behave identically. `get_current_node()` carries the
cast speaker override. Scenes validate like trees (unknown dialogue, cast
nodes missing from the tree) and round-trip through saves mid-performance.
Games decide presence: override `DialogueSystem.scene_participant_provider`
with entity/proximity queries (it defaults to everyone present).

## Barks

`DialogueBark` resources are conditional one-liners — combat shouts, idle
chatter, greetings. They reuse tree-choice conditions, evaluated through the
same `DialogueConditions` helper, so authoring stays in one language:

| Property | Type | Description |
|---|---|---|
| `id` / `trigger` | `StringName` | Unique id; trigger channel like `&"kill"` or `&"greet"`. |
| `speaker` | `StringName` | Who may say it. Empty means anyone (generic fallback). |
| `text` / `voice_id` / `display_seconds` | `String` / `StringName` / `float` | The line, its dub id, and subtitle hold (`0` = game decides). |
| `priority` | `int` | Higher wins when several match (registration order breaks ties). |
| `chance` | `float` | Per-query roll, `0..1`. |
| `cooldown_seconds` | `float` | Refire lockout. Ephemeral — never saved. |
| `conditions` | `Array[DialogueChoiceCondition]` | All must pass for eligibility. |

```gdscript
BarkSystem.register_bark(preload("res://dialogues/barks/guard_kill.tres"))
var bark := BarkSystem.say(&"kill", &"GuardCaptain")
# {} when nothing is eligible, else {bark_id, speaker, text, voice_id, display_seconds}
```

`BarkSystem.bark_said(speaker, text, voice_id, display_seconds)` feeds your
subtitle/voice playback. Validate with `BarkSystem.validate_bark(bark)`.

## Voice Hooks

`DialogueNode` carries `voice_id` (dubbed-audio id, empty = unvoiced) and
`display_seconds` (subtitle hold, `0` = game decides from line length). Both
flow into `DialogueNodeView`, and bark payloads carry the same pair — one
subtitle/voice contract for trees, scenes, and barks.

## Customising `DialogueContext`

`DialogueContext` is the bridge between the dialogue engine and your game's state. Override the methods you need:

```gdscript
class_name MyDialogueContext
extends DialogueContext

func get_inventory_count(item_id: StringName) -> int:
    return PlayerInventory.count(item_id)

func get_skill_level(skill_id: StringName) -> int:
    return PlayerSkills.get_level(skill_id)

func consume_item(item_id: StringName, quantity: int) -> bool:
    return PlayerInventory.remove(item_id, quantity)

func give_item(item_id: StringName, quantity: int) -> void:
    PlayerInventory.add(item_id, quantity)

func emit_event(event_id: StringName, _payload: Dictionary = {}) -> void:
    match event_id:
        &"give_quest_item":
            PlayerInventory.add(&"ancient_sword", 1)
```

The default implementations handle flags (`GameInfo.continuity_flags`), faction reputation (`CovenSystem`), and quest status (`QuestSystem`) automatically.

## Saving Session State

`DialogueSession` supports snapshot/restore for mid-conversation saves:

```gdscript
# Save
var snapshot := session.get_snapshot()
# snapshot.serialize() returns a Dictionary safe for JSON

# Restore
session.restore_from_snapshot(snapshot)
```

`DialogueSystem` is in the `savegame_gameinfo` group — the system-level state (registered definitions) persists automatically. Individual session snapshots must be saved by your game code if needed.

## Signals

`DialogueSystem` emits no signals of its own; wire signals to your UI by holding the `DialogueSession` reference. The session itself is stateful and can be stored as a member variable on your dialogue UI node.
