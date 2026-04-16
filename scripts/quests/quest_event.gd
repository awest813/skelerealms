class_name QuestEvent
extends RefCounted
## An event that may advance one or more quest nodes.
## Fire these via [method QuestGraphEngine.apply_event].


## The trigger type (must match [member QuestNodeDefinition.trigger_type]).
var type: String
## The target ref-ID (must match [member QuestNodeDefinition.target_id]).
var target_id: StringName
## How much progress to add (defaults to 1).
var amount: int


func _init(p_type: String = "custom", p_target_id: StringName = &"", p_amount: int = 1) -> void:
	type = p_type
	target_id = p_target_id
	amount = max(1, p_amount)
