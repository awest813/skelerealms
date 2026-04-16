class_name DialogueChoice
extends Resource
## A single choice the player can make during dialogue.


## Unique ID for this choice within its node.
@export var id: StringName
## Display text (can be a translation key).
@export var text: String
## Node to advance to when this choice is selected. Empty means end dialogue.
@export var next_node_id: StringName
## If true, selecting this choice ends the dialogue regardless of next_node_id.
@export var ends_dialogue: bool = false
## Conditions that must be met for this choice to be available.
@export var conditions: Array[DialogueChoiceCondition] = []
## Effects to apply when this choice is selected.
@export var effects: Array[DialogueChoiceEffect] = []
