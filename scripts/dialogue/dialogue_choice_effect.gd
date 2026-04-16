class_name DialogueChoiceEffect
extends Resource
## An effect applied when a dialogue choice is selected.
## Extend for custom effect types.


## The effect type. Built-in: "set_flag", "faction_delta", "emit_event", "activate_quest", "consume_item", "give_item".
@export var type: String = "set_flag"

# ── Flag effect ──
## Flag name to set (when type == "set_flag").
@export var flag: String
## Value to set (when type == "set_flag").
@export var flag_value: bool = true

# ── Faction effect ──
## Coven/faction ID (when type == "faction_delta").
@export var faction_id: StringName
## Amount to adjust reputation by (when type == "faction_delta").
@export var amount: int = 0

# ── Event effect ──
## Custom event ID to emit (when type == "emit_event").
@export var event_id: StringName

# ── Quest effect ──
## Quest ID to activate (when type == "activate_quest").
@export var quest_id: StringName

# ── Item effects ──
## Item ref-ID (when type == "consume_item" or "give_item").
@export var item_id: StringName
## Quantity (when type == "consume_item" or "give_item").
@export var quantity: int = 1
