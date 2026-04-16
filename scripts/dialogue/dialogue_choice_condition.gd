class_name DialogueChoiceCondition
extends Resource
## A condition that gates whether a dialogue choice is available.
## Extend for custom condition types.


## The condition type. Built-in types: "flag", "faction_min", "quest_status", "has_item", "skill_min".
@export var type: String = "flag"

# ── Flag condition ──
## Flag name to check (when type == "flag").
@export var flag: String
## Expected value of the flag (when type == "flag").
@export var flag_equals: bool = true

# ── Faction condition ──
## Coven/faction ID (when type == "faction_min").
@export var faction_id: StringName
## Minimum reputation required (when type == "faction_min" or "skill_min").
@export var min_value: int = 0

# ── Quest condition ──
## Quest ID (when type == "quest_status").
@export var quest_id: StringName
## Expected status: "inactive", "active", or "completed" (when type == "quest_status").
@export var quest_status: String = "completed"

# ── Item condition ──
## Item ref-ID (when type == "has_item").
@export var item_id: StringName
## Minimum quantity required (when type == "has_item").
@export var min_quantity: int = 1

# ── Skill condition ──
## Skill ID (when type == "skill_min").
@export var skill_id: StringName
