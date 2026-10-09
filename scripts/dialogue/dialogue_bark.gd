class_name DialogueBark
extends Resource
## One conditional one-liner: combat shouts, idle chatter, greetings, kill
## confirmations. Barks use the same [DialogueChoiceCondition] semantics as
## tree choices, evaluated through [DialogueConditions], so authoring stays
## in one language. The game triggers them (combat start, kill, proximity)
## and displays/voices the winner; the engine only picks.


## Unique ID for this bark.
@export var id: StringName
## Trigger channel, e.g. &"combat_start", &"kill", &"greet", or custom.
@export var trigger: StringName
## Who may say it. Empty means anyone (generic fallback).
@export var speaker: StringName
## The line itself.
@export var text: String
## Voice line id for dubbed audio. Empty means unvoiced.
@export var voice_id: StringName
## Seconds to hold the subtitle. 0 means the game decides.
@export var display_seconds: float = 0.0
## Higher wins when several barks match.
@export var priority: int = 0
## Per-query roll, 0..1. 1.0 always fires (when eligible), 0.0 never does.
@export var chance: float = 1.0
## Seconds before this bark may fire again. Ephemeral (not saved).
@export var cooldown_seconds: float = 30.0
## All must pass for this bark to be eligible.
@export var conditions: Array[DialogueChoiceCondition] = []
