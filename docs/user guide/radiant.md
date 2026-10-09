# Radiant Story Manager

The Radiant Story Manager is Skelerealms' answer to Bethesda's Story Manager:
an event-driven dispenser of repeatable quests. You declare **templates**
("when X happens, offer quest Y"), and the manager issues fresh quest
instances — with their own ids, alias fills, cooldowns, and saves — while
the game runs.

It has three layers, mirroring the quest system:

| Class | Role |
|---|---|
| `RadiantTemplate` | A resource pairing a quest template with a trigger, cooldown, and caps. |
| `RadiantEngine` | Pure logic: matches events, plans issuances, tracks cooldowns/instances. |
| `RadiantSystem` | The autoload singleton. Game clock, execution, signals, save integration. |

## Declaring a Template

Create a `RadiantTemplate` resource (`.tres`):

| Property | Type | Description |
|---|---|---|
| `id` | `StringName` | Stable id, e.g. `&"wolf_bounty"`. Instances become `&"wolf_bounty_001"`, … |
| `quest_template` | `QuestDefinition` | The quest instanced per issuance. Never register this directly. |
| `trigger_type` | `String` | QuestEvent type: `"kill"`, `"pickup"`, `"talk"`, or `"custom"`. |
| `trigger_target` | `StringName` | Required event target, or empty for any target of the type. |
| `cooldown_minutes` | `int` | Game minutes before this template may issue again (default `60`). |
| `max_active` | `int` | Max simultaneously active instances (default `1`). |
| `extra_params` | `Dictionary` | Static template params merged at activation. |

Register templates at game start, next to your quest registration:

```gdscript
func _ready() -> void:
    var bounty: RadiantTemplate = preload("res://quests/wolf_bounty_radiant.tres")
    RadiantSystem.register_template(bounty)
```

## How Issuance Works

Every quest event (`QuestSystem.report_kill(...)` and friends) is forwarded
to `RadiantSystem.notify_event(event)` automatically — disable with
`RadiantSystem.auto_forward = false` for fully manual dispatch. Each
evaluation:

1. Templates whose trigger matches the event are considered.
2. Per-template cooldowns (game minutes) and active-instance caps gate them.
3. The quest template is duplicated, renamed (`<id>_NNN`, never reused),
   registered, and activated — alias slots fill normally, `quest_activated`
   fires, and `radiant_quest_issued(quest_id, template_id)` fires.

If activation fails (e.g. a required alias has no candidate), the instance
is rolled back and nothing is recorded.

## Cooldowns, Saves, and Mod Removal

- Cooldowns tick on `GameInfo.minute_incremented` and persist in saves.
- Issued instances persist through `RadiantSystem`'s own snapshot, which
  stores the instance map plus their quest states — restores work regardless
  of save-system ordering, and numbering never reuses ids.
- If a template is gone at load time (removed mod), its orphaned instances
  are skipped with a warning instead of crashing.
- Issuance suspends while `GameInfo.is_loading`.

## Validating Templates

```gdscript
var issues: Array = RadiantEngine.new().validate_template(t)
# Each issue names its "source": "trigger", "aliases", or "stages".
```

This combines the trigger sanity check with the quest alias and stage
validators. Wire it into editor tooling or content tests.
