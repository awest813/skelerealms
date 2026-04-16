class_name DialogueContext
extends RefCounted
## Provides game-state queries and mutation methods for the dialogue engine.
## Implement this interface by subclassing and overriding the methods.
## The dialogue engine calls these to evaluate conditions and apply effects.


## Get the value of a continuity flag.
func get_flag(flag: String) -> bool:
	return GameInfo.continuity_flags.get(flag, false)


## Set a continuity flag.
func set_flag(flag: String, value: bool) -> void:
	GameInfo.continuity_flags[flag] = value


## Get the player's reputation with a coven/faction.
func get_faction_reputation(faction_id: StringName) -> int:
	var coven: Coven = CovenSystem.get_coven(faction_id)
	if not coven:
		return 0
	# Default implementation: return the coven's opinion of the player coven.
	# Override this if your game tracks per-entity reputation differently.
	var opinions := coven.get_coven_opinions([&"Player"])
	return opinions[0] if opinions.size() > 0 else 0


## Adjust the player's reputation with a coven/faction.
func adjust_faction_reputation(faction_id: StringName, amount: int) -> void:
	CovenSystem.change_opinion(faction_id, &"Player", amount)


## Get the status of a quest.
func get_quest_status(quest_id: StringName) -> String:
	return QuestSystem.get_quest_status(quest_id)


## Get the count of an item in the player's inventory.
## Override this to hook into your inventory system.
func get_inventory_count(item_id: StringName) -> int:
	return 0


## Get a skill level by ID. Override to hook into your skills system.
func get_skill_level(skill_id: StringName) -> int:
	return 0


## Emit a custom event. Override to handle game-specific events.
func emit_event(event_id: StringName, _payload: Dictionary = {}) -> void:
	push_warning("DialogueContext: Unhandled event '%s'. Override emit_event() to handle." % event_id)


## Activate a quest.
func activate_quest(quest_id: StringName) -> void:
	QuestSystem.activate_quest(quest_id)


## Remove items from the player's inventory. Override to hook into your inventory.
## Returns true if the items were successfully consumed.
func consume_item(_item_id: StringName, _quantity: int) -> bool:
	push_warning("DialogueContext: consume_item not implemented. Override to handle.")
	return false


## Give items to the player. Override to hook into your inventory.
func give_item(_item_id: StringName, _quantity: int) -> void:
	push_warning("DialogueContext: give_item not implemented. Override to handle.")
